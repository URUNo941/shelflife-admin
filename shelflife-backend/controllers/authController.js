const argon2 = require("argon2");
const jwt = require("jsonwebtoken");
const { query, handleDatabaseError } = require("../utils/db");
async function login(req, res) {
  const { username, password } = req.body || {};
  if (
    typeof username !== "string" ||
    !username.trim() ||
    username.length > 50 ||
    typeof password !== "string" ||
    !password ||
    password.length > 256
  )
    return res.status(400).json({ message: "Invalid credentials format." });
  if (!process.env.JWT_SECRET)
    return res
      .status(503)
      .json({ message: "Authentication is not configured." });
  try {
    const rows = await query("SELECT * FROM users WHERE username = ?", [
      username.trim(),
    ]);
    const user = rows[0];
    let valid = false;
    if (user && user.is_active) {
      try {
        valid = await argon2.verify(user.password_hash, password);
      } catch {
        /* Legacy placeholder hashes cannot authenticate. */
      }
    }
    if (!valid)
      return res.status(401).json({ message: "Invalid username or password." });
    const token = jwt.sign({ userId: user.user_id }, process.env.JWT_SECRET, {
      algorithm: "HS256",
      expiresIn: "8h",
    });
    const { password_hash, ...safe } = user;
    return res.json({ token, user: safe });
  } catch (e) {
    return handleDatabaseError(res, e);
  }
}
async function register(req, res) {
  const { username, email, password } = req.body || {};
  if (
    typeof username !== "string" ||
    username.trim().length < 3 ||
    username.trim().length > 50 ||
    typeof email !== "string" ||
    email.length > 254 ||
    !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ||
    typeof password !== "string" ||
    password.length < 8 ||
    password.length > 256
  )
    return res
      .status(400)
      .json({
        message:
          "Use a 3–50 character username, valid email and 8–256 character password.",
      });
  try {
    const hash = await argon2.hash(password);
    const result = await query(
      "INSERT INTO users (username,email,password_hash,role) VALUES (?,?,?,'user')",
      [username.trim(), email.trim().toLowerCase(), hash],
    );
    return res
      .status(201)
      .json({
        user_id: result.insertId,
        username: username.trim(),
        email: email.trim().toLowerCase(),
        role: "user",
      });
  } catch (e) {
    return handleDatabaseError(res, e);
  }
}
module.exports = { login, register };
