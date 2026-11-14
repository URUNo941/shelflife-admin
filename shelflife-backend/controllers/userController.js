const argon2 = require('argon2');
const { query, handleDatabaseError, isPositiveId } = require('../utils/db');

// ไม่ส่ง password_hash ออกไปเด็ดขาด
const safeUserFields = 'user_id, username, email, role, created_at, updated_at';
const validRoles = ['user', 'admin'];
const MIN_PASSWORD = 6;
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

// argon2id ตามโจทย์ (ระบุชัดเจน ไม่พึ่งค่า default ของไลบรารี)
function hashPassword(password) {
  return argon2.hash(password, { type: argon2.argon2id });
}

function validateUser(body, partial = false) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'A JSON object is required.';
  if (!partial && (typeof body.username !== 'string' || !body.username.trim())) return 'username is required.';
  if (!partial && (typeof body.password !== 'string' || body.password.length < MIN_PASSWORD)) {
    return `password must be at least ${MIN_PASSWORD} characters.`;
  }
  if (body.username !== undefined && (typeof body.username !== 'string' || body.username.trim().length < 3)) {
    return 'username must be at least 3 characters.';
  }
  if (body.username !== undefined && body.username.trim().length > 50) return 'username is too long.';
  if (body.password !== undefined && (typeof body.password !== 'string' || body.password.length < MIN_PASSWORD)) {
    return `password must be at least ${MIN_PASSWORD} characters.`;
  }
  if (body.email !== undefined && body.email !== null && body.email !== '') {
    if (typeof body.email !== 'string' || !EMAIL_RE.test(body.email.trim()) || body.email.length > 254) {
      return 'email is invalid.';
    }
  }
  if (body.role !== undefined && !validRoles.includes(body.role)) return 'role must be user or admin.';
  return null;
}

function cleanEmail(email) {
  return typeof email === 'string' && email.trim() ? email.trim().toLowerCase() : null;
}

async function adminCount() {
  const [row] = await query("SELECT COUNT(*) AS n FROM users WHERE role = 'admin'");
  return Number(row.n);
}

async function listUsers(req, res) {
  try {
    return res.json(await query(`SELECT ${safeUserFields} FROM users ORDER BY created_at DESC, user_id DESC`));
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function getUser(req, res) {
  if (!isPositiveId(req.params.userId)) return res.status(400).json({ message: 'userId must be a positive integer.' });
  try {
    const rows = await query(`SELECT ${safeUserFields} FROM users WHERE user_id = ?`, [req.params.userId]);
    if (!rows.length) return res.status(404).json({ message: 'User not found.' });
    return res.json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function createUser(req, res) {
  const validationError = validateUser(req.body);
  if (validationError) return res.status(400).json({ message: validationError });
  try {
    const passwordHash = await hashPassword(req.body.password);
    const result = await query(
      'INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, ?)',
      [req.body.username.trim(), cleanEmail(req.body.email), passwordHash, req.body.role || 'user'],
    );
    const rows = await query(`SELECT ${safeUserFields} FROM users WHERE user_id = ?`, [result.insertId]);
    return res.status(201).json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function updateUser(req, res) {
  if (!isPositiveId(req.params.userId)) return res.status(400).json({ message: 'userId must be a positive integer.' });
  const validationError = validateUser(req.body, true);
  if (validationError) return res.status(400).json({ message: validationError });
  const userId = Number(req.params.userId);
  if (userId === req.auth.userId && req.body.role && req.body.role !== 'admin') {
    return res.status(400).json({ message: 'You cannot remove your own administrator role.' });
  }

  const updates = [];
  const values = [];
  if (req.body.username !== undefined) {
    updates.push('username = ?');
    values.push(req.body.username.trim());
  }
  if (req.body.email !== undefined) {
    updates.push('email = ?');
    values.push(cleanEmail(req.body.email));
  }
  if (req.body.role !== undefined) {
    updates.push('role = ?');
    values.push(req.body.role);
  }
  if (req.body.password !== undefined) updates.push('password_hash = ?');
  if (!updates.length) return res.status(400).json({ message: 'At least one user field is required.' });
  try {
    const existing = await query('SELECT role FROM users WHERE user_id = ?', [userId]);
    if (!existing.length) return res.status(404).json({ message: 'User not found.' });
    if (existing[0].role === 'admin' && req.body.role === 'user' && (await adminCount()) <= 1) {
      return res.status(400).json({ message: 'The last administrator cannot be demoted.' });
    }
    if (req.body.password !== undefined) values.push(await hashPassword(req.body.password));
    await query(`UPDATE users SET ${updates.join(', ')} WHERE user_id = ?`, [...values, userId]);
    const rows = await query(`SELECT ${safeUserFields} FROM users WHERE user_id = ?`, [userId]);
    return res.json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function deleteUser(req, res) {
  if (!isPositiveId(req.params.userId)) return res.status(400).json({ message: 'userId must be a positive integer.' });
  const userId = Number(req.params.userId);
  if (userId === req.auth.userId) return res.status(400).json({ message: 'You cannot delete your own account.' });
  try {
    const existing = await query('SELECT role FROM users WHERE user_id = ?', [userId]);
    if (!existing.length) return res.status(404).json({ message: 'User not found.' });
    if (existing[0].role === 'admin' && (await adminCount()) <= 1) {
      return res.status(400).json({ message: 'The last administrator cannot be deleted.' });
    }
    // inventory_items ของผู้ใช้คนนี้ถูกลบตาม (ON DELETE CASCADE)
    await query('DELETE FROM users WHERE user_id = ?', [userId]);
    return res.status(204).end();
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

module.exports = {
  listUsers, getUser, createUser, updateUser, deleteUser,
  safeUserFields, validateUser, hashPassword, cleanEmail,
};
