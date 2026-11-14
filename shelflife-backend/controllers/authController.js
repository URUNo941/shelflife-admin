const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const { query, handleDatabaseError } = require('../utils/db');
const { safeUserFields, validateUser, hashPassword, cleanEmail } = require('./userController');

function signToken(user) {
  return jwt.sign(
    { userId: user.user_id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: '8h' },
  );
}

// POST /api/auth/login  { username, password } -> { token, user }
async function login(req, res) {
  const { username, password } = req.body || {};
  if (typeof username !== 'string' || !username.trim() || typeof password !== 'string' || !password) {
    return res.status(400).json({ message: 'username and password are required.' });
  }
  if (!process.env.JWT_SECRET) {
    return res.status(503).json({ message: 'Authentication is not configured.' });
  }
  try {
    const users = await query('SELECT * FROM users WHERE username = ?', [username.trim()]);
    let valid = false;
    if (users.length) {
      try {
        valid = await argon2.verify(users[0].password_hash, password);
      } catch {
        valid = false; // hash เสีย/ไม่ใช่ argon2 (เช่นข้อมูลตัวอย่าง) = รหัสผ่านไม่ถูก
      }
    }
    if (!valid) return res.status(401).json({ message: 'Invalid username or password.' });
    const safeUsers = await query(`SELECT ${safeUserFields} FROM users WHERE user_id = ?`, [users[0].user_id]);
    return res.json({ token: signToken(users[0]), user: safeUsers[0] });
  } catch (error) {
    console.error(error.message);
    return res.status(500).json({ message: 'Could not sign in.' });
  }
}

// POST /api/auth/register  { username, email, password } -> 201 { token, user }
// สมัครได้เฉพาะ role = user (admin สร้างได้จากหน้า User Management หรือ scripts/create-admin.js)
async function register(req, res) {
  const body = req.body || {};
  const validationError = validateUser({ username: body.username, email: body.email, password: body.password });
  if (validationError) return res.status(400).json({ message: validationError });
  if (!process.env.JWT_SECRET) {
    return res.status(503).json({ message: 'Authentication is not configured.' });
  }
  try {
    const passwordHash = await hashPassword(body.password);
    const result = await query(
      "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, 'user')",
      [body.username.trim(), cleanEmail(body.email), passwordHash],
    );
    const rows = await query(`SELECT ${safeUserFields} FROM users WHERE user_id = ?`, [result.insertId]);
    return res.status(201).json({ token: signToken(rows[0]), user: rows[0] });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ message: 'Username or email is already taken.' });
    }
    return handleDatabaseError(res, error);
  }
}

// GET /api/auth/me -> ข้อมูลผู้ใช้จาก token
async function me(req, res) {
  try {
    const rows = await query(`SELECT ${safeUserFields} FROM users WHERE user_id = ?`, [req.auth.userId]);
    if (!rows.length) return res.status(404).json({ message: 'User not found.' });
    return res.json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

module.exports = { login, register, me };
