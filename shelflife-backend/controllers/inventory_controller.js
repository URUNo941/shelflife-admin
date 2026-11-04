const db = require('../db_config');
const createHttpError = require('../utils/http_error');

const query = (sql, values) => db.promise().query(sql, values);
const validStatuses = new Set(['active', 'consumed', 'discarded']);

function validateItem(body, partial = false) {
  const fields = [
    'user_id',
    'barcode',
    'product_name',
    'category',
    'quantity',
    'expiration_date',
    'status',
  ];
  const required = ['user_id', 'product_name', 'quantity', 'expiration_date'];

  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw createHttpError(400, 'A JSON object is required.');
  }

  if (!partial && required.some((field) => body[field] === undefined || body[field] === null)) {
    throw createHttpError(400, 'user_id, product_name, quantity, and expiration_date are required.');
  }

  for (const field of fields) {
    if (body[field] === undefined) continue;

    if (field === 'user_id' || field === 'quantity') {
      if (!Number.isInteger(Number(body[field])) || Number(body[field]) < 1) {
        throw createHttpError(400, `${field} must be a positive integer.`);
      }
    } else if (field === 'barcode') {
      if (body[field] !== null &&
          (typeof body[field] !== 'string' || body[field].length > 50)) {
        throw createHttpError(400, 'barcode must be a string of at most 50 characters.');
      }
    } else if (field === 'product_name' || field === 'category') {
      if (typeof body[field] !== 'string' || body[field].trim().length === 0) {
        throw createHttpError(400, `${field} must be a non-empty string.`);
      }
    } else if (field === 'expiration_date') {
      const match = typeof body[field] === 'string'
        ? /^(\d{4})-(\d{2})-(\d{2})$/.exec(body[field])
        : null;
      if (!match) {
        throw createHttpError(400, 'expiration_date must use YYYY-MM-DD format.');
      }
      const [, year, month, day] = match;
      const date = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day)));
      if (date.toISOString().slice(0, 10) !== body[field]) {
        throw createHttpError(400, 'expiration_date must be a valid calendar date.');
      }
    } else if (field === 'status' && !validStatuses.has(body[field])) {
      throw createHttpError(400, 'status must be active, consumed, or discarded.');
    }
  }
}

async function getItems(req, res) {
  const userId = Number(req.params.userId);
  if (!Number.isInteger(userId) || userId < 1) {
    throw createHttpError(400, 'userId must be a positive integer.');
  }

  const includeInactive = req.query.include_inactive === 'true';
  const statusFilter = includeInactive ? '' : " AND status = 'active'";
  const [rows] = await query(
    `SELECT * FROM inventory_items WHERE user_id = ?${statusFilter} ORDER BY expiration_date ASC`,
    [userId],
  );
  res.json(rows);
}

async function getItem(req, res) {
  const userId = Number(req.params.userId);
  const itemId = Number(req.params.itemId);
  if (![userId, itemId].every((id) => Number.isInteger(id) && id > 0)) {
    throw createHttpError(400, 'userId and itemId must be positive integers.');
  }

  const [rows] = await query(
    'SELECT * FROM inventory_items WHERE user_id = ? AND item_id = ?',
    [userId, itemId],
  );
  if (rows.length === 0) throw createHttpError(404, 'Inventory item not found.');
  res.json(rows[0]);
}

async function createItem(req, res) {
  const body = req.body;
  validateItem(body);
  if (req.auth.role !== 'admin' && req.auth.userId !== Number(body.user_id)) {
    throw createHttpError(403, 'You may only create items for your own inventory.');
  }
  const [result] = await query(
    `INSERT INTO inventory_items
      (user_id, barcode, product_name, category, quantity, expiration_date, status)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      Number(body.user_id),
      body.barcode || null,
      body.product_name.trim(),
      body.category?.trim() || 'General',
      Number(body.quantity),
      body.expiration_date,
      body.status || 'active',
    ],
  );
  const [rows] = await query('SELECT * FROM inventory_items WHERE item_id = ?', [result.insertId]);
  res.status(201).json(rows[0]);
}

async function updateItem(req, res) {
  const itemId = Number(req.params.itemId);
  if (!Number.isInteger(itemId) || itemId < 1) {
    throw createHttpError(400, 'itemId must be a positive integer.');
  }
  validateItem(req.body, true);
  const [existingRows] = await query(
    'SELECT user_id FROM inventory_items WHERE item_id = ?',
    [itemId],
  );
  if (existingRows.length === 0) throw createHttpError(404, 'Inventory item not found.');
  if (req.auth.role !== 'admin' && req.auth.userId !== existingRows[0].user_id) {
    throw createHttpError(403, 'You may only update your own inventory.');
  }
  if (req.auth.role !== 'admin' &&
      req.body.user_id !== undefined &&
      Number(req.body.user_id) !== req.auth.userId) {
    throw createHttpError(403, 'Only administrators may reassign inventory items.');
  }

  const columns = {
    user_id: 'user_id',
    barcode: 'barcode',
    product_name: 'product_name',
    category: 'category',
    quantity: 'quantity',
    expiration_date: 'expiration_date',
    status: 'status',
  };
  const updates = Object.keys(columns).filter((field) => req.body[field] !== undefined);
  if (updates.length === 0) throw createHttpError(400, 'At least one item field is required.');

  const values = updates.map((field) => {
    const value = req.body[field];
    if (field === 'user_id' || field === 'quantity') return Number(value);
    if (field === 'product_name' || field === 'category') return value.trim();
    return value;
  });
  await query(
    `UPDATE inventory_items SET ${updates.map((field) => `${columns[field]} = ?`).join(', ')} WHERE item_id = ?`,
    [...values, itemId],
  );

  const [rows] = await query('SELECT * FROM inventory_items WHERE item_id = ?', [itemId]);
  if (rows.length === 0) throw createHttpError(404, 'Inventory item not found.');
  res.json(rows[0]);
}

async function deleteItem(req, res) {
  const itemId = Number(req.params.itemId);
  if (!Number.isInteger(itemId) || itemId < 1) {
    throw createHttpError(400, 'itemId must be a positive integer.');
  }
  const [existingRows] = await query(
    'SELECT user_id FROM inventory_items WHERE item_id = ?',
    [itemId],
  );
  if (existingRows.length === 0) throw createHttpError(404, 'Inventory item not found.');
  if (req.auth.role !== 'admin' && req.auth.userId !== existingRows[0].user_id) {
    throw createHttpError(403, 'You may only delete items from your own inventory.');
  }
  const [result] = await query('DELETE FROM inventory_items WHERE item_id = ?', [itemId]);
  if (result.affectedRows === 0) throw createHttpError(404, 'Inventory item not found.');
  res.status(204).end();
}

module.exports = { getItems, getItem, createItem, updateItem, deleteItem };
