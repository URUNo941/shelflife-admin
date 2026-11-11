// Shared SQL for the V2 database (users, categories, products, inventory_items).
// The API still returns the same JSON fields as V1 (barcode, product_name,
// category), but they are read through JOINs instead of being stored twice.

const ITEM_SELECT = `
  SELECT i.item_id, i.user_id, i.product_id,
         p.barcode, p.product_name, c.category_name AS category,
         i.quantity, i.expiration_date, i.status, i.status_updated_at,
         i.created_at, i.updated_at
  FROM inventory_items AS i
  JOIN products AS p ON p.product_id = i.product_id
  JOIN categories AS c ON c.category_id = p.category_id`;

const PRODUCT_SELECT = `
  SELECT p.product_id, p.barcode, p.product_name,
         c.category_name AS category, p.category_id,
         p.created_by, p.created_at
  FROM products AS p
  JOIN categories AS c ON c.category_id = p.category_id`;

function cleanCategory(name) {
  const value = typeof name === 'string' ? name.trim() : '';
  return value || 'General';
}

function cleanBarcode(barcode) {
  if (typeof barcode !== 'string') return null;
  return barcode.trim() || null;
}

// Look something up; if missing, insert it. If another request inserted the
// same row at the same moment, the UNIQUE key rejects ours and we read theirs.
async function findOrInsert(q, find, insert) {
  const found = await find();
  if (found) return found;
  try {
    return await insert();
  } catch (error) {
    if (error.code !== 'ER_DUP_ENTRY') throw error;
    const again = await find();
    if (again) return again;
    throw error;
  }
}

async function categoryId(q, name) {
  const categoryName = cleanCategory(name);
  return findOrInsert(
    q,
    async () => (await q('SELECT category_id FROM categories WHERE category_name = ?', [categoryName]))[0]?.category_id,
    async () => (await q('INSERT INTO categories (category_name) VALUES (?)', [categoryName])).insertId,
  );
}

// Returns the product_id for an item. A known barcode always reuses the
// catalog product (its name is the single source of truth). Without a
// barcode, the same name in the same category reuses one product.
async function productIdFor(q, { barcode, product_name, category, created_by }) {
  const code = cleanBarcode(barcode);
  const name = product_name.trim();
  if (code) {
    const existing = (await q('SELECT product_id FROM products WHERE barcode = ?', [code]))[0];
    if (existing) return existing.product_id;
  }
  const catId = await categoryId(q, category);
  return findOrInsert(
    q,
    async () => code
      ? (await q('SELECT product_id FROM products WHERE barcode = ?', [code]))[0]?.product_id
      : (await q(
        'SELECT product_id FROM products WHERE barcode IS NULL AND product_name = ? AND category_id = ?',
        [name, catId],
      ))[0]?.product_id,
    async () => (await q(
      'INSERT INTO products (barcode, product_name, category_id, created_by) VALUES (?, ?, ?, ?)',
      [code, name, catId, created_by ?? null],
    )).insertId,
  );
}

module.exports = { ITEM_SELECT, PRODUCT_SELECT, categoryId, productIdFor, cleanBarcode, cleanCategory };
