const express = require("express");
const cors = require("cors");
const { query, handleDatabaseError } = require("./utils/db");
const auth = require("./middleware/requireAuth");
const admin = require("./middleware/requireAdmin");
const app = express();
app.disable("x-powered-by");
const origins = (process.env.CORS_ORIGINS || "").split(",").filter(Boolean);
app.use(
  cors({
    origin: (origin, cb) => cb(null, !origin || origins.includes(origin)),
  }),
);
app.use(express.json({ limit: "32kb" }));
app.use("/api/auth", require("./routes/authRoutes"));
app.use("/api/items", require("./routes/inventoryRoutes"));
app.use("/api/me/inventory", require("./routes/inventoryRoutes"));
app.get("/api/me", auth, (req, res) => res.json(req.user));
app.use("/api/products", auth, require("./routes/productRoutes"));
app.use("/api/admin/products", admin, require("./routes/productRoutes"));
app.use("/api/users", require("./routes/userRoutes"));
app.use("/api/admin/users", require("./routes/userRoutes"));
app.get("/api/categories", auth, async (req, res) =>
  res.json(
    await query(
      "SELECT * FROM categories WHERE is_active=1 ORDER BY category_name",
    ),
  ),
);
app.get("/api/admin/analytics/summary", admin, async (req, res) => {
  const from = req.query.from || "1000-01-01",
    to = req.query.to || "9999-12-31";
  const valid = (d) =>
    typeof d === "string" &&
    /^\d{4}-\d{2}-\d{2}$/.test(d) &&
    !Number.isNaN(Date.parse(d)) &&
    new Date(d).toISOString().slice(0, 10) === d;
  if (!valid(from) || !valid(to) || from > to)
    return res.status(400).json({ message: "Invalid date range." });
  const [counts] = await query(
    `SELECT (SELECT COUNT(*) FROM users WHERE is_active=1) total_users,(SELECT COUNT(*) FROM global_products WHERE is_active=1) total_products,(SELECT COUNT(*) FROM inventory_items WHERE status='active' AND deleted_at IS NULL) active_items,(SELECT COUNT(*) FROM inventory_items WHERE status='active' AND deleted_at IS NULL AND expiration_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(),INTERVAL 7 DAY)) expiring_soon`,
  );
  const events = await query(
    "SELECT event_type, COUNT(*) event_count, SUM(quantity_change) quantity_change FROM inventory_events WHERE DATE(occurred_at) BETWEEN ? AND ? GROUP BY event_type",
    [from, to],
  );
  res.json({ ...counts, events });
});
app.get("/health", async (req, res) => {
  await query("SELECT 1");
  res.json({ status: "ok" });
});
app.use((req, res) => res.status(404).json({ message: "Endpoint not found." }));
app.use((err, req, res, next) =>
  err.type === "entity.parse.failed"
    ? res.status(400).json({ message: "Invalid JSON." })
    : handleDatabaseError(res, err),
);
module.exports = app;
