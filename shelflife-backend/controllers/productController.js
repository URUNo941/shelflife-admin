const { query, withTransaction, handleDatabaseError, isPositiveId } = require('../utils/db');
const { PRODUCT_SELECT, categoryId } = require('../utils/catalog');

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
    const rows = await query(`${PRODUCT_SELECT} ORDER BY p.product_name ASC`);
    return res.json(rows);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function findProduct(req, res, field, key) {
  if (field === 'product_id' && !isPositiveId(key)) return res.status(400).json({ message: 'productId must be a positive integer.' });
  try {
    const rows = await query(`${PRODUCT_SELECT} WHERE p.${field} = ?`, [key]);
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
    const productId = await withTransaction(async (q) => {
      const catId = await categoryId(q, req.body.category);
      const result = await q(
        'INSERT INTO products (barcode, product_name, category_id, created_by) VALUES (?, ?, ?, ?)',
        [req.body.barcode.trim(), req.body.product_name.trim(), catId, req.auth.userId],
      );
      return result.insertId;
    });
    const rows = await query(`${PRODUCT_SELECT} WHERE p.product_id = ?`, [productId]);
    return res.status(201).json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function updateProduct(req, res) {
  if (!isPositiveId(req.params.productId)) return res.status(400).json({ message: 'productId must be a positive integer.' });
  const validationError = validateProduct(req.body, true);
  if (validationError) return res.status(400).json({ message: validationError });
  const has = (field) => Object.prototype.hasOwnProperty.call(req.body, field);
  if (!['barcode', 'product_name', 'category'].some(has)) {
    return res.status(400).json({ message: 'At least one product field is required.' });
  }
  try {
    const found = await withTransaction(async (q) => {
      const updates = [];
      const values = [];
      if (has('barcode')) {
        updates.push('barcode = ?');
        values.push(req.body.barcode.trim());
      }
      if (has('product_name')) {
        updates.push('product_name = ?');
        values.push(req.body.product_name.trim());
      }
      if (has('category')) {
        updates.push('category_id = ?');
        values.push(await categoryId(q, req.body.category));
      }
      const result = await q(
        `UPDATE products SET ${updates.join(', ')} WHERE product_id = ?`,
        [...values, req.params.productId],
      );
      return result.affectedRows > 0;
    });
    if (!found) return res.status(404).json({ message: 'Product not found.' });
    const rows = await query(`${PRODUCT_SELECT} WHERE p.product_id = ?`, [req.params.productId]);
    return res.json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

// A product still used by someone's inventory cannot be deleted (409).
async function deleteProduct(req, res) {
  if (!isPositiveId(req.params.productId)) return res.status(400).json({ message: 'productId must be a positive integer.' });
  try {
    const result = await query('DELETE FROM products WHERE product_id = ?', [req.params.productId]);
    if (!result.affectedRows) return res.status(404).json({ message: 'Product not found.' });
    return res.status(204).end();
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

module.exports = { listProducts, getProductByBarcode, getProductById, createProduct, updateProduct, deleteProduct };
