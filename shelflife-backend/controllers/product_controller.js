const db = require('../db_config');
const createHttpError = require('../utils/http_error');

const query = (sql, values) => db.promise().query(sql, values);

function validateProduct(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw createHttpError(400, 'A JSON object is required.');
  }
  if (body.barcode !== undefined &&
      (typeof body.barcode !== 'string' || body.barcode.trim().length === 0 || body.barcode.length > 50)) {
    throw createHttpError(400, 'barcode must be a non-empty string of at most 50 characters.');
  }
  if (body.product_name !== undefined &&
      (typeof body.product_name !== 'string' || body.product_name.trim().length === 0 || body.product_name.length > 100)) {
    throw createHttpError(400, 'product_name must be a non-empty string of at most 100 characters.');
  }
  if (body.category !== undefined &&
      (typeof body.category !== 'string' || body.category.trim().length === 0 || body.category.length > 50)) {
    throw createHttpError(400, 'category must be a non-empty string of at most 50 characters.');
  }
  if (body.created_by !== undefined &&
      body.created_by !== null &&
      (!Number.isInteger(Number(body.created_by)) || Number(body.created_by) < 1)) {
    throw createHttpError(400, 'created_by must be a positive integer or null.');
  }
}

async function getProducts(_req, res) {
  const [rows] = await query('SELECT * FROM global_products ORDER BY product_name ASC');
  res.json(rows);
}

async function getProduct(req, res) {
  const productId = Number(req.params.productId);
  if (!Number.isInteger(productId) || productId < 1) {
    throw createHttpError(400, 'productId must be a positive integer.');
  }
  const [rows] = await query('SELECT * FROM global_products WHERE product_id = ?', [productId]);
  if (rows.length === 0) throw createHttpError(404, 'Product not found.');
  res.json(rows[0]);
}

async function getProductByBarcode(req, res) {
  const [rows] = await query('SELECT * FROM global_products WHERE barcode = ?', [req.params.barcode]);
  if (rows.length === 0) throw createHttpError(404, 'Barcode not found in master data.');
  res.json(rows[0]);
}

async function createProduct(req, res) {
  const body = req.body;
  validateProduct(body);
  if (!body.barcode || !body.product_name) {
    throw createHttpError(400, 'barcode and product_name are required.');
  }

  const [result] = await query(
    'INSERT INTO global_products (barcode, product_name, category, created_by) VALUES (?, ?, ?, ?)',
    [
      body.barcode.trim(),
      body.product_name.trim(),
      body.category?.trim() || 'General',
      body.created_by == null ? null : Number(body.created_by),
    ],
  );
  const [rows] = await query('SELECT * FROM global_products WHERE product_id = ?', [result.insertId]);
  res.status(201).json(rows[0]);
}

async function updateProduct(req, res) {
  const productId = Number(req.params.productId);
  if (!Number.isInteger(productId) || productId < 1) {
    throw createHttpError(400, 'productId must be a positive integer.');
  }
  validateProduct(req.body);

  const columns = ['barcode', 'product_name', 'category'];
  const updates = columns.filter((field) => req.body[field] !== undefined);
  if (updates.length === 0) throw createHttpError(400, 'At least one product field is required.');

  await query(
    `UPDATE global_products SET ${updates.map((field) => `${field} = ?`).join(', ')} WHERE product_id = ?`,
    [...updates.map((field) => req.body[field].trim()), productId],
  );
  const [rows] = await query('SELECT * FROM global_products WHERE product_id = ?', [productId]);
  if (rows.length === 0) throw createHttpError(404, 'Product not found.');
  res.json(rows[0]);
}

async function deleteProduct(req, res) {
  const productId = Number(req.params.productId);
  if (!Number.isInteger(productId) || productId < 1) {
    throw createHttpError(400, 'productId must be a positive integer.');
  }
  const [result] = await query('DELETE FROM global_products WHERE product_id = ?', [productId]);
  if (result.affectedRows === 0) throw createHttpError(404, 'Product not found.');
  res.status(204).end();
}

module.exports = {
  getProducts,
  getProduct,
  getProductByBarcode,
  createProduct,
  updateProduct,
  deleteProduct,
};
