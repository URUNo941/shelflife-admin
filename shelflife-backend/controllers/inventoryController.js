const { query, handleDatabaseError, isPositiveId } = require('../utils/db');

const itemFields = ['user_id', 'barcode', 'product_name', 'category', 'quantity', 'expiration_date', 'status'];
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

function itemValues(body) {
  return [
    body.user_id,
    body.barcode || null,
    body.product_name.trim(),
    body.category || 'General',
    body.quantity ?? 1,
    body.expiration_date,
    body.status || 'active',
  ];
}

async function getInventoryItems(req, res) {
  if (!isPositiveId(req.params.userId)) return res.status(400).json({ message: 'userId must be a positive integer.' });
  const status = req.query.status || 'active';
  if (!validStatuses.includes(status)) return res.status(400).json({ message: 'status is invalid.' });
  try {
    const result = await query(
      'SELECT * FROM inventory_items WHERE user_id = ? AND status = ? ORDER BY expiration_date ASC',
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
    const rows = await query('SELECT * FROM inventory_items WHERE item_id = ?', [req.params.itemId]);
    if (!rows.length) return res.status(404).json({ message: 'Inventory item not found.' });
    return res.json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function createInventoryItem(req, res) {
  const validationError = validateItem(req.body);
  if (validationError) return res.status(400).json({ message: validationError });
  try {
    const result = await query(
      `INSERT INTO inventory_items
       (user_id, barcode, product_name, category, quantity, expiration_date, status)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      itemValues(req.body),
    );
    const rows = await query('SELECT * FROM inventory_items WHERE item_id = ?', [result.insertId]);
    return res.status(201).json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function updateInventoryItem(req, res) {
  if (!isPositiveId(req.params.itemId)) return res.status(400).json({ message: 'itemId must be a positive integer.' });
  const validationError = validateItem(req.body, true);
  if (validationError) return res.status(400).json({ message: validationError });

  const updates = [];
  const values = [];
  for (const field of itemFields) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      updates.push(`${field} = ?`);
      values.push(field === 'product_name' ? req.body[field].trim() : req.body[field]);
      if (field === 'status') updates.push('status_updated_at = CURRENT_TIMESTAMP');
    }
  }
  if (!updates.length) return res.status(400).json({ message: 'At least one item field is required.' });

  try {
    const result = await query(
      `UPDATE inventory_items SET ${updates.join(', ')} WHERE item_id = ?`,
      [...values, req.params.itemId],
    );
    if (!result.affectedRows) return res.status(404).json({ message: 'Inventory item not found.' });
    const rows = await query('SELECT * FROM inventory_items WHERE item_id = ?', [req.params.itemId]);
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
