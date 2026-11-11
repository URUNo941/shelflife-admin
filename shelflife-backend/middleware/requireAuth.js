const jwt = require("jsonwebtoken");
const { query } = require("../utils/db");
module.exports = async function requireAuth(req, res, next) {
  if (!process.env.JWT_SECRET)
    return res
      .status(503)
      .json({ message: "Authentication is not configured." });
  const match = /^Bearer ([^ ]+)$/i.exec(req.get("authorization") || "");
  if (!match)
    return res.status(401).json({ message: "Authentication required." });
  let payload;
  try {
    payload = jwt.verify(match[1], process.env.JWT_SECRET, {
      algorithms: ["HS256"],
    });
  } catch {
    return res.status(401).json({ message: "Invalid or expired token." });
  }
  if (!Number.isSafeInteger(payload.userId) || payload.userId < 1)
    return res.status(401).json({ message: "Invalid token." });
  try {
    const rows = await query(
      "SELECT user_id, username, email, role, is_active, created_at FROM users WHERE user_id = ?",
      [payload.userId],
    );
    if (!rows.length || !rows[0].is_active)
      return res.status(401).json({ message: "Account unavailable." });
    req.user = rows[0];
    req.auth = { userId: rows[0].user_id, role: rows[0].role };
    return next();
  } catch (e) {
    return next(e);
  }
};
