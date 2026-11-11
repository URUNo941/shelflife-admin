-- Run only in the new V2 test database. These are read-only examples.

-- A user's batches: product labels are read once from products/categories.
-- Bind ? to the authenticated user ID when the API is adapted in a later task.
SELECT i.item_id, i.user_id, p.product_id, p.barcode, p.product_name,
       c.category_name AS category, i.quantity, i.expiration_date, i.status
FROM inventory_items AS i
JOIN products AS p ON p.product_id = i.product_id
JOIN categories AS c ON c.category_id = p.category_id
WHERE i.user_id = ? AND i.status = 'active'
ORDER BY i.expiration_date, i.item_id;

-- Barcode lookup returns product information, not somebody's private stock.
SELECT p.product_id, p.barcode, p.product_name, c.category_name
FROM products AS p
JOIN categories AS c ON c.category_id = p.category_id
WHERE p.barcode = ?;

-- Counts by category without duplicated category strings in inventory.
SELECT c.category_name, COUNT(*) AS batch_count, SUM(i.quantity) AS total_quantity
FROM inventory_items AS i
JOIN products AS p ON p.product_id = i.product_id
JOIN categories AS c ON c.category_id = p.category_id
WHERE i.user_id = ? AND i.status = 'active'
GROUP BY c.category_id, c.category_name;
