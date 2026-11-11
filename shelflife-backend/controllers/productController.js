const { query, transaction, isPositiveId } = require("../utils/db");
function validate(b, partial = false) {
  if (!b || typeof b !== "object" || Array.isArray(b))
    return "JSON object required.";
  for (const [k, max] of [
    ["barcode", 50],
    ["product_name", 100],
    ["category", 50],
  ]) {
    if ((!partial && k !== "category") || b[k] !== undefined)
      if (typeof b[k] !== "string" || !b[k].trim() || b[k].length > max)
        return "Invalid " + k;
  }
  return null;
}
async function listProducts(req, res) {
  res.json(
    await query(
      "SELECT * FROM global_products WHERE is_active=1 ORDER BY product_name",
    ),
  );
}
async function getProductById(req, res) {
  if (!isPositiveId(req.params.productId))
    return res.status(400).json({ message: "Invalid ID." });
  const rows = await query(
    "SELECT * FROM global_products WHERE product_id=? AND is_active=1",
    [req.params.productId],
  );
  return rows.length
    ? res.json(rows[0])
    : res.status(404).json({ message: "Product not found." });
}
async function getProductByBarcode(req, res) {
  const rows = await query(
    "SELECT p.* FROM global_products p JOIN product_barcodes b ON b.product_id=p.product_id WHERE b.barcode=? AND p.is_active=1",
    [req.params.barcode],
  );
  return rows.length
    ? res.json(rows[0])
    : res
        .status(404)
        .json({
          message: "Product not found. Enter the item details manually.",
        });
}
async function mutate(req, res, mode) {
  if (mode !== "create" && !isPositiveId(req.params.productId))
    return res.status(400).json({ message: "Invalid ID." });
  const err = mode === "delete" ? null : validate(req.body, mode === "update");
  if (err) return res.status(400).json({ message: err });
  const row = await transaction(async (q) => {
    let id = req.params.productId,
      old;
    if (mode !== "create") {
      old = (
        await q(
          "SELECT * FROM global_products WHERE product_id=? AND is_active=1 FOR UPDATE",
          [id],
        )
      )[0];
      if (!old) return null;
    }
    if (mode === "delete")
      await q("UPDATE global_products SET is_active=0 WHERE product_id=?", [
        id,
      ]);
    else {
      const p = {
        category: "General",
        ...old,
        ...Object.fromEntries(
          ["barcode", "product_name", "category"]
            .filter((k) => req.body[k] !== undefined)
            .map((k) => [k, req.body[k].trim()]),
        ),
      };
      await q(
        "INSERT INTO categories(category_name) VALUES (?) ON DUPLICATE KEY UPDATE category_name=VALUES(category_name)",
        [p.category],
      );
      const [cat] = await q(
        "SELECT category_id FROM categories WHERE category_name=?",
        [p.category],
      );
      if (mode === "create")
        id = (
          await q(
            "INSERT INTO global_products (barcode,product_name,category,category_id,created_by) VALUES (?,?,?,?,?)",
            [
              p.barcode,
              p.product_name,
              p.category,
              cat.category_id,
              req.auth.userId,
            ],
          )
        ).insertId;
      else
        await q(
          "UPDATE global_products SET barcode=?,product_name=?,category=?,category_id=? WHERE product_id=?",
          [p.barcode, p.product_name, p.category, cat.category_id, id],
        );
      const existing = (
        await q("SELECT product_id FROM product_barcodes WHERE barcode=?", [
          p.barcode,
        ])
      )[0];
      if (existing && Number(existing.product_id) !== Number(id)) {
        const e = new Error("Duplicate barcode");
        e.code = "ER_DUP_ENTRY";
        throw e;
      }
      await q("UPDATE product_barcodes SET is_primary=0 WHERE product_id=?", [
        id,
      ]);
      if (existing)
        await q("UPDATE product_barcodes SET is_primary=1 WHERE barcode=?", [
          p.barcode,
        ]);
      else
        await q(
          "INSERT INTO product_barcodes (product_id,barcode,is_primary) VALUES (?,?,1)",
          [id, p.barcode],
        );
    }
    await q(
      "INSERT INTO audit_logs(actor_user_id,action,entity_type,entity_id) VALUES (?,?,?,?)",
      [req.auth.userId, mode, "product", id],
    );
    return (
      await q("SELECT * FROM global_products WHERE product_id=?", [id])
    )[0];
  });
  if (!row) return res.status(404).json({ message: "Product not found." });
  return mode === "delete"
    ? res.status(204).end()
    : res.status(mode === "create" ? 201 : 200).json(row);
}
module.exports = {
  listProducts,
  getProductById,
  getProductByBarcode,
  createProduct: (a, b) => mutate(a, b, "create"),
  updateProduct: (a, b) => mutate(a, b, "update"),
  deleteProduct: (a, b) => mutate(a, b, "delete"),
};
