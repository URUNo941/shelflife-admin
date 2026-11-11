const argon2 = require("argon2");
const { query, transaction, isPositiveId } = require("../utils/db");
const safeUserFields =
  "user_id,username,email,role,is_active,created_at,updated_at";
function validate(b, partial) {
  if (!b || typeof b !== "object" || Array.isArray(b))
    return "JSON object required.";
  if (!partial || b.username !== undefined)
    if (
      typeof b.username !== "string" ||
      b.username.trim().length < 3 ||
      b.username.length > 50
    )
      return "Username must have 3–50 characters.";
  if (!partial || b.password !== undefined)
    if (
      typeof b.password !== "string" ||
      b.password.length < 8 ||
      b.password.length > 256
    )
      return "Password must have 8–256 characters.";
  if (b.role !== undefined && !["user", "admin"].includes(b.role))
    return "Invalid role.";
  if (
    b.email !== undefined &&
    (typeof b.email !== "string" ||
      b.email.length > 254 ||
      !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(b.email))
  )
    return "Invalid email.";
  return null;
}
async function listUsers(req, res) {
  res.json(
    await query(`SELECT ${safeUserFields} FROM users ORDER BY created_at DESC`),
  );
}
async function getUser(req, res) {
  if (!isPositiveId(req.params.userId))
    return res.status(400).json({ message: "Invalid ID." });
  const rows = await query(
    `SELECT ${safeUserFields} FROM users WHERE user_id=?`,
    [req.params.userId],
  );
  return rows.length
    ? res.json(rows[0])
    : res.status(404).json({ message: "User not found." });
}
async function mutate(req, res, mode) {
  if (mode !== "create" && !isPositiveId(req.params.userId))
    return res.status(400).json({ message: "Invalid ID." });
  const error =
    mode === "delete" ? null : validate(req.body, mode === "update");
  if (error) return res.status(400).json({ message: error });
  if (
    Number(req.params.userId) === req.auth.userId &&
    (mode === "delete" || (req.body.role && req.body.role !== "admin"))
  )
    return res
      .status(400)
      .json({ message: "You cannot deactivate or demote yourself." });
  if (
    mode === "update" &&
    !["username", "email", "password", "role"].some(
      (k) => req.body[k] !== undefined,
    )
  )
    return res.status(400).json({ message: "No fields to update." });
  const hash =
    mode !== "delete" && req.body.password
      ? await argon2.hash(req.body.password)
      : null;
  const row = await transaction(async (q) => {
    let id = req.params.userId;
    if (mode === "create")
      id = (
        await q(
          "INSERT INTO users(username,email,password_hash,role) VALUES (?,?,?,?)",
          [
            req.body.username.trim(),
            req.body.email?.trim().toLowerCase() || null,
            hash,
            req.body.role || "user",
          ],
        )
      ).insertId;
    else {
      const old = (
        await q("SELECT user_id FROM users WHERE user_id=? FOR UPDATE", [id])
      )[0];
      if (!old) return null;
      if (mode === "delete")
        await q("UPDATE users SET is_active=0 WHERE user_id=?", [id]);
      else {
        const fields = [],
          values = [];
        for (const k of ["username", "email", "role"])
          if (req.body[k] !== undefined) {
            fields.push(k + "=?");
            values.push(
              k === "email"
                ? req.body[k].trim().toLowerCase()
                : req.body[k].trim(),
            );
          }
        if (hash) {
          fields.push("password_hash=?");
          values.push(hash);
        }
        await q("UPDATE users SET " + fields.join(",") + " WHERE user_id=?", [
          ...values,
          id,
        ]);
      }
    }
    await q(
      "INSERT INTO audit_logs(actor_user_id,action,entity_type,entity_id) VALUES (?,?,?,?)",
      [req.auth.userId, mode, "user", id],
    );
    return (
      await q(`SELECT ${safeUserFields} FROM users WHERE user_id=?`, [id])
    )[0];
  });
  if (!row) return res.status(404).json({ message: "User not found." });
  return mode === "delete"
    ? res.status(204).end()
    : res.status(mode === "create" ? 201 : 200).json(row);
}
module.exports = {
  safeUserFields,
  listUsers,
  getUser,
  createUser: (a, b) => mutate(a, b, "create"),
  updateUser: (a, b) => mutate(a, b, "update"),
  deleteUser: (a, b) => mutate(a, b, "delete"),
};
