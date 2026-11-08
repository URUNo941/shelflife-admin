const { query, handleDatabaseError, isPositiveId } = require('../utils/db');

function validateProduct(body, partial = false) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'A JSON object is required.';
  const required = partial ? [] : ['barcode', 'product_name'];
  for (const field of required) {
    if (typeof body[field] !== 'string' || !body[field].trim()) return `${field} is required.`;
  }
  if (body.barcode !== undefined && (typeof body.barcode !== 'string' || !body.barcode.trim())) return 'barcode must not be empty.';
  if (body.product_name !== undefined && (typeof body.product_name !== 'string' || !body.product_name.trim())) return 'product_name must not be empty.';
  if (body.category !== undefined && typeof body.category !== 'string') return 'category must be a string.';
  if (body.created_by !== undefined && body.created_by !== null && !isPositiveId(body.created_by)) return 'created_by must be a positive integer or null.';
  return null;
}

async function listProducts(req, res) {
  try {
    const rows = await query('SELECT * FROM global_products ORDER BY product_name ASC');
    return res.json(rows);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function findProduct(req, res, field, key) {
  if (field === 'product_id' && !isPositiveId(key)) return res.status(400).json({ message: 'productId must be a positive integer.' });
  try {
    const rows = await query(`SELECT * FROM global_products WHERE ${field} = ?`, [key]);
    if (!rows.length) return res.status(404).json({ message: 'Product not found.' });
    return res.json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

function getProductByBarcode(req, res) {
  return findProduct(req, res, 'barcode', req.params.barcode);
}

function getProductById(req, res) {
  return findProduct(req, res, 'product_id', req.params.productId);
}

async function createProduct(req, res) {
  const validationError = validateProduct(req.body);
  if (validationError) return res.status(400).json({ message: validationError });
  try {
    const result = await query(
      'INSERT INTO global_products (barcode, product_name, category, created_by) VALUES (?, ?, ?, ?)',
      [req.body.barcode.trim(), req.body.product_name.trim(), req.body.category || 'General', req.auth.userId],
    );
    const rows = await query('SELECT * FROM global_products WHERE product_id = ?', [result.insertId]);
    return res.status(201).json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function updateProduct(req, res) {
  if (!isPositiveId(req.params.productId)) return res.status(400).json({ message: 'productId must be a positive integer.' });
  const validationError = validateProduct(req.body, true);
  if (validationError) return res.status(400).json({ message: validationError });
  const fields = ['barcode', 'product_name', 'category'];
  const updates = [];
  const values = [];
  for (const field of fields) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      updates.push(`${field} = ?`);
      values.push(typeof req.body[field] === 'string' ? req.body[field].trim() : req.body[field]);
    }
  }
  if (!updates.length) return res.status(400).json({ message: 'At least one product field is required.' });
  try {
    const result = await query(
      `UPDATE global_products SET ${updates.join(', ')} WHERE product_id = ?`,
      [...values, req.params.productId],
    );
    if (!result.affectedRows) return res.status(404).json({ message: 'Product not found.' });
    const rows = await query('SELECT * FROM global_products WHERE product_id = ?', [req.params.productId]);
    return res.json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function deleteProduct(req, res) {
  if (!isPositiveId(req.params.productId)) return res.status(400).json({ message: 'productId must be a positive integer.' });
  try {
    const result = await query('DELETE FROM global_products WHERE product_id = ?', [req.params.productId]);
    if (!result.affectedRows) return res.status(404).json({ message: 'Product not found.' });
    return res.status(204).end();
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

module.exports = { listProducts, getProductByBarcode, getProductById, createProduct, updateProduct, deleteProduct };
