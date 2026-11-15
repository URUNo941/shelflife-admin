const { query, withTransaction, handleDatabaseError, isPositiveId } = require('../utils/db');
const { ITEM_SELECT, productIdFor } = require('../utils/catalog');

// ทุก endpoint ต้องผ่าน requireAuth: req.auth = { userId, role }
// ผู้ใช้เห็น/แก้ได้เฉพาะล็อตของตัวเอง (admin เข้าถึงได้ทุกล็อต)

// คอลัมน์ที่อยู่ในแถว inventory_items เอง
const itemFields = ['quantity', 'expiration_date', 'status'];
// ข้อมูลสินค้า อยู่ที่ products/categories (เปลี่ยนแล้วจะชี้ไปสินค้าที่ตรงกัน)
const productFields = ['barcode', 'product_name', 'category'];
const validStatuses = ['active', 'consumed', 'discarded'];

function validDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.valueOf()) && date.toISOString().slice(0, 10) === value;
}

function validateItem(body, partial = false) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'A JSON object is required.';
  const required = partial ? [] : ['product_name', 'expiration_date'];
  for (const field of required) {
    if (body[field] === undefined || body[field] === null || body[field] === '') return `${field} is required.`;
  }
  if (body.product_name !== undefined && (typeof body.product_name !== 'string' || !body.product_name.trim())) return 'product_name must not be empty.';
  if (body.product_name !== undefined && body.product_name.trim().length > 100) return 'product_name is too long.';
  if (body.category !== undefined && body.category !== null && (typeof body.category !== 'string' || body.category.length > 50)) return 'category must be a short string.';
  if (body.barcode !== undefined && body.barcode !== null && (typeof body.barcode !== 'string' || body.barcode.length > 50)) return 'barcode must be a string or null.';
  if (body.quantity !== undefined && (!Number.isInteger(body.quantity) || body.quantity < 1)) return 'quantity must be a positive integer.';
  if (body.expiration_date !== undefined && !validDate(body.expiration_date)) return 'expiration_date must use YYYY-MM-DD format.';
  if (body.status !== undefined && !validStatuses.includes(body.status)) return 'status must be active, consumed or discarded.';
  return null;
}

const has = (body, field) => Object.prototype.hasOwnProperty.call(body, field);

// คืนล็อตถ้าผู้ใช้มีสิทธิ์ ไม่งั้นคืน null (ตอบ 404 เหมือนไม่มี เพื่อไม่บอกว่าล็อตของคนอื่นมีอยู่)
async function findOwnedItem(q, itemId, auth, lock = false) {
  const rows = await q(`${ITEM_SELECT} WHERE i.item_id = ?${lock ? ' FOR UPDATE' : ''}`, [itemId]);
  const item = rows[0];
  if (!item) return null;
  if (auth.role !== 'admin' && item.user_id !== auth.userId) return null;
  return item;
}

// GET /api/items?status=active|consumed|discarded|all  (ค่าเริ่มต้น active)
async function listMyItems(req, res) {
  const status = req.query.status || 'active';
  if (status !== 'all' && !validStatuses.includes(status)) {
    return res.status(400).json({ message: 'status must be active, consumed, discarded or all.' });
  }
  try {
    const where = status === 'all' ? 'i.user_id = ?' : 'i.user_id = ? AND i.status = ?';
    const values = status === 'all' ? [req.auth.userId] : [req.auth.userId, status];
    const rows = await query(`${ITEM_SELECT} WHERE ${where} ORDER BY i.expiration_date ASC, i.item_id ASC`, values);
    return res.json(rows);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function getInventoryItem(req, res) {
  if (!isPositiveId(req.params.itemId)) return res.status(400).json({ message: 'itemId must be a positive integer.' });
  try {
    const item = await findOwnedItem(query, req.params.itemId, req.auth);
    if (!item) return res.status(404).json({ message: 'Inventory item not found.' });
    return res.json(item);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

// POST /api/items -> 201 แถวที่สร้าง (ชื่อ/หมวด/บาร์โค้ดอ่านผ่าน JOIN)
async function createInventoryItem(req, res) {
  const validationError = validateItem(req.body);
  if (validationError) return res.status(400).json({ message: validationError });
  const body = req.body;
  const status = body.status || 'active';
  try {
    const itemId = await withTransaction(async (q) => {
      const productId = await productIdFor(q, { ...body, created_by: req.auth.userId });
      const result = await q(
        `INSERT INTO inventory_items
         (user_id, product_id, quantity, expiration_date, status, status_updated_at)
         VALUES (?, ?, ?, ?, ?, IF(? = 'active', NULL, CURRENT_TIMESTAMP))`,
        [req.auth.userId, productId, body.quantity ?? 1, body.expiration_date, status, status],
      );
      return result.insertId;
    });
    const rows = await query(`${ITEM_SELECT} WHERE i.item_id = ?`, [itemId]);
    return res.status(201).json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

// PUT /api/items/:itemId  แก้จำนวน/วันหมดอายุ/สถานะ/ข้อมูลสินค้า
async function updateInventoryItem(req, res) {
  if (!isPositiveId(req.params.itemId)) return res.status(400).json({ message: 'itemId must be a positive integer.' });
  const validationError = validateItem(req.body, true);
  if (validationError) return res.status(400).json({ message: validationError });
  const body = req.body;
  if (![...itemFields, ...productFields].some((field) => has(body, field))) {
    return res.status(400).json({ message: 'At least one item field is required.' });
  }

  try {
    const found = await withTransaction(async (q) => {
      const current = await findOwnedItem(q, req.params.itemId, req.auth, true);
      if (!current) return false;

      const updates = [];
      const values = [];
      for (const field of itemFields) {
        if (has(body, field)) {
          updates.push(`${field} = ?`);
          values.push(body[field]);
          if (field === 'status') updates.push('status_updated_at = CURRENT_TIMESTAMP');
        }
      }
      if (productFields.some((field) => has(body, field))) {
        const productId = await productIdFor(q, {
          barcode: has(body, 'barcode') ? body.barcode : current.barcode,
          product_name: has(body, 'product_name') ? body.product_name : current.product_name,
          category: has(body, 'category') ? body.category : current.category,
          created_by: current.user_id,
        });
        updates.push('product_id = ?');
        values.push(productId);
      }
      await q(`UPDATE inventory_items SET ${updates.join(', ')} WHERE item_id = ?`, [...values, req.params.itemId]);
      return true;
    });
    if (!found) return res.status(404).json({ message: 'Inventory item not found.' });
    const rows = await query(`${ITEM_SELECT} WHERE i.item_id = ?`, [req.params.itemId]);
    return res.json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function deleteInventoryItem(req, res) {
  if (!isPositiveId(req.params.itemId)) return res.status(400).json({ message: 'itemId must be a positive integer.' });
  try {
    const item = await findOwnedItem(query, req.params.itemId, req.auth);
    if (!item) return res.status(404).json({ message: 'Inventory item not found.' });
    await query('DELETE FROM inventory_items WHERE item_id = ?', [req.params.itemId]);
    return res.status(204).end();
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

module.exports = { listMyItems, getInventoryItem, createInventoryItem, updateInventoryItem, deleteInventoryItem };
