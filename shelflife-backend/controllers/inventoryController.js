const { query, transaction, isPositiveId } = require("../utils/db");
const fields = [
  "barcode",
  "product_name",
  "category",
  "quantity",
  "expiration_date",
  "status",
];
function validate(body, partial = false) {
  if (!body || typeof body !== "object" || Array.isArray(body))
    return "A JSON object is required.";
  if ("user_id" in body || "product_id" in body)
    return "Ownership and product links are assigned by the server.";
  if (!partial && (!body.product_name || !body.expiration_date))
    return "Name and expiration date are required.";
  for (const [key, max] of [
    ["product_name", 100],
    ["category", 50],
    ["barcode", 50],
  ]) {
    if (
      body[key] !== undefined &&
      !(key === "barcode" && body[key] === null) &&
      (typeof body[key] !== "string" ||
        !body[key].trim() ||
        body[key].length > max)
    )
      return "Invalid " + key;
  }
  if (
    body.quantity !== undefined &&
    (!Number.isInteger(body.quantity) ||
      body.quantity < 1 ||
      body.quantity > 2147483647)
  )
    return "Invalid quantity.";
  if (
    body.status !== undefined &&
    !["active", "consumed", "discarded"].includes(body.status)
  )
    return "Invalid status.";
  if (body.expiration_date !== undefined) {
    const d = body.expiration_date;
    if (
      typeof d !== "string" ||
      !/^\d{4}-\d{2}-\d{2}$/.test(d) ||
      d < "1000-01-01" ||
      Number.isNaN(Date.parse(d)) ||
      new Date(d).toISOString().slice(0, 10) !== d
    )
      return "Invalid expiration date.";
  }
  return null;
}
async function getInventoryItems(req, res) {
  if (req.params.userId && String(req.auth.userId) !== req.params.userId)
    return res.status(403).json({ message: "Access denied." });
  const status = req.query.status || "active";
  if (!["active", "consumed", "discarded", "all"].includes(status))
    return res.status(400).json({ message: "Invalid status." });
  return res.json(
    await query(
      "SELECT * FROM inventory_items WHERE user_id = ? AND deleted_at IS NULL" +
        (status === "all" ? "" : " AND status = ?") +
        " ORDER BY expiration_date, item_id",
      status === "all" ? [req.auth.userId] : [req.auth.userId, status],
    ),
  );
}
async function getInventoryItem(req, res) {
  if (!isPositiveId(req.params.itemId))
    return res.status(400).json({ message: "Invalid item ID." });
  const rows = await query(
    "SELECT * FROM inventory_items WHERE item_id = ? AND user_id = ? AND deleted_at IS NULL",
    [req.params.itemId, req.auth.userId],
  );
  return rows.length
    ? res.json(rows[0])
    : res.status(404).json({ message: "Item not found." });
}
async function mutate(req, res, mode) {
  if (mode !== "create" && !isPositiveId(req.params.itemId))
    return res.status(400).json({ message: "Invalid item ID." });
  const error =
    mode === "delete" ? null : validate(req.body, mode === "update");
  if (error) return res.status(400).json({ message: error });
  if (mode === "update" && !fields.some((f) => Object.hasOwn(req.body, f)))
    return res.status(400).json({ message: "No fields to update." });
  const result = await transaction(async (q) => {
    let old;
    if (mode !== "create") {
      old = (
        await q(
          "SELECT * FROM inventory_items WHERE item_id = ? AND user_id = ? AND deleted_at IS NULL FOR UPDATE",
          [req.params.itemId, req.auth.userId],
        )
      )[0];
      if (!old) return null;
    }
    let id = req.params.itemId;
    if (mode === "delete")
      await q(
        "UPDATE inventory_items SET deleted_at=CURRENT_TIMESTAMP WHERE item_id=? AND user_id=?",
        [id, req.auth.userId],
      );
    else {
      const item = {
        barcode: null,
        category: "General",
        quantity: 1,
        status: "active",
        ...old,
        ...Object.fromEntries(
          fields
            .filter((f) => Object.hasOwn(req.body, f))
            .map((f) => [
              f,
              typeof req.body[f] === "string"
                ? req.body[f].trim()
                : req.body[f],
            ]),
        ),
      };
      const product = item.barcode
        ? (
            await q(
              "SELECT p.product_id FROM global_products p JOIN product_barcodes b ON b.product_id=p.product_id WHERE b.barcode=? AND p.is_active=1",
              [item.barcode],
            )
          )[0]
        : null;
      const values = fields.map((f) => item[f]);
      if (mode === "create")
        id = (
          await q(
            "INSERT INTO inventory_items (barcode,product_name,category,quantity,expiration_date,status,user_id,product_id,product_name_snapshot) VALUES (?,?,?,?,?,?,?,?,?)",
            [
              ...values,
              req.auth.userId,
              product?.product_id || null,
              item.product_name,
            ],
          )
        ).insertId;
      else
        await q(
          "UPDATE inventory_items SET " +
            fields.map((f) => f + "=?").join(",") +
            ",product_id=?,product_name_snapshot=?,status_updated_at=IF(status<>?,CURRENT_TIMESTAMP,status_updated_at) WHERE item_id=? AND user_id=?",
          [
            ...values,
            product?.product_id || null,
            item.product_name,
            old.status,
            id,
            req.auth.userId,
          ],
        );
    }
    const current = (
      await q("SELECT * FROM inventory_items WHERE item_id=? AND user_id=?", [
        id,
        req.auth.userId,
      ])
    )[0];
    const before = old?.status === "active" ? old.quantity : 0,
      after =
        mode !== "delete" && current.status === "active" ? current.quantity : 0;
    const type =
      mode === "delete"
        ? "deleted"
        : mode === "create"
          ? "added"
          : old.status !== current.status
            ? current.status
            : "adjusted";
    await q(
      "INSERT INTO inventory_events (item_id,user_id,event_type,quantity_change) VALUES (?,?,?,?)",
      [id, req.auth.userId, type, after - before],
    );
    return current;
  });
  if (!result) return res.status(404).json({ message: "Item not found." });
  return mode === "delete"
    ? res.status(204).end()
    : res.status(mode === "create" ? 201 : 200).json(result);
}
module.exports = {
  validate,
  getInventoryItems,
  getInventoryItem,
  createInventoryItem: (a, b) => mutate(a, b, "create"),
  updateInventoryItem: (a, b) => mutate(a, b, "update"),
  deleteInventoryItem: (a, b) => mutate(a, b, "delete"),
};
