const { query, withTransaction, handleDatabaseError, isPositiveId } = require('../utils/db');
const { ITEM_SELECT, productIdFor } = require('../utils/catalog');

// Fields stored on the inventory row itself.
const itemFields = ['user_id', 'quantity', 'expiration_date', 'status'];
// Fields that describe the product; they live in products/categories.
const productFields = ['barcode', 'product_name', 'category'];
const validStatuses = ['active', 'consumed', 'discarded'];

function validDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.valueOf()) && date.toISOString().slice(0, 10) === value;
}

function validateItem(body, partial = false) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return 'A JSON object is required.';
  }
  const required = partial ? [] : ['user_id', 'product_name', 'expiration_date'];
  for (const field of required) {
    if (body[field] === undefined || body[field] === null || body[field] === '') {
      return `${field} is required.`;
    }
  }
  if (body.user_id !== undefined && !isPositiveId(body.user_id)) return 'user_id must be a positive integer.';
  if (body.product_name !== undefined && (typeof body.product_name !== 'string' || !body.product_name.trim())) return 'product_name must not be empty.';
  if (body.category !== undefined && typeof body.category !== 'string') return 'category must be a string.';
  if (body.barcode !== undefined && body.barcode !== null && typeof body.barcode !== 'string') return 'barcode must be a string or null.';
  if (body.quantity !== undefined && (!Number.isInteger(body.quantity) || body.quantity < 1)) return 'quantity must be a positive integer.';
  if (body.expiration_date !== undefined && !validDate(body.expiration_date)) return 'expiration_date must use YYYY-MM-DD format.';
  if (body.status !== undefined && !validStatuses.includes(body.status)) return 'status is invalid.';
  return null;
}

const has = (body, field) => Object.prototype.hasOwnProperty.call(body, field);

async function getInventoryItems(req, res) {
  if (!isPositiveId(req.params.userId)) return res.status(400).json({ message: 'userId must be a positive integer.' });
  const status = req.query.status || 'active';
  if (!validStatuses.includes(status)) return res.status(400).json({ message: 'status is invalid.' });
  try {
    const result = await query(
      `${ITEM_SELECT} WHERE i.user_id = ? AND i.status = ? ORDER BY i.expiration_date ASC`,
      [req.params.userId, status],
    );
    return res.json(result);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function getInventoryItem(req, res) {
  if (!isPositiveId(req.params.itemId)) return res.status(400).json({ message: 'itemId must be a positive integer.' });
  try {
    const rows = await query(`${ITEM_SELECT} WHERE i.item_id = ?`, [req.params.itemId]);
    if (!rows.length) return res.status(404).json({ message: 'Inventory item not found.' });
    return res.json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function createInventoryItem(req, res) {
  const validationError = validateItem(req.body);
  if (validationError) return res.status(400).json({ message: validationError });
  const body = req.body;
  const status = body.status || 'active';
  try {
    const itemId = await withTransaction(async (q) => {
      const productId = await productIdFor(q, { ...body, created_by: body.user_id });
      const result = await q(
        `INSERT INTO inventory_items
         (user_id, product_id, quantity, expiration_date, status, status_updated_at)
         VALUES (?, ?, ?, ?, ?, IF(? = 'active', NULL, CURRENT_TIMESTAMP))`,
        [body.user_id, productId, body.quantity ?? 1, body.expiration_date, status, status],
      );
      return result.insertId;
    });
    const rows = await query(`${ITEM_SELECT} WHERE i.item_id = ?`, [itemId]);
    return res.status(201).json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

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
      const current = (await q(`${ITEM_SELECT} WHERE i.item_id = ? FOR UPDATE`, [req.params.itemId]))[0];
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
      // Changing name/barcode/category points the batch at the matching product.
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
    const result = await query('DELETE FROM inventory_items WHERE item_id = ?', [req.params.itemId]);
    if (!result.affectedRows) return res.status(404).json({ message: 'Inventory item not found.' });
    return res.status(204).end();
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

module.exports = { getInventoryItems, getInventoryItem, createInventoryItem, updateInventoryItem, deleteInventoryItem };
