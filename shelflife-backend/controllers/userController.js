const argon2 = require('argon2');
const { query, handleDatabaseError, isPositiveId } = require('../utils/db');

const safeUserFields = 'user_id, username, role, created_at, updated_at';
const validRoles = ['user', 'admin'];

function validateUser(body, partial = false) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return 'A JSON object is required.';
  if (!partial && (typeof body.username !== 'string' || !body.username.trim())) return 'username is required.';
  if (!partial && (typeof body.password !== 'string' || body.password.length < 8)) return 'password must be at least 8 characters.';
  if (body.username !== undefined && (typeof body.username !== 'string' || !body.username.trim())) return 'username must not be empty.';
  if (body.password !== undefined && (typeof body.password !== 'string' || body.password.length < 8)) return 'password must be at least 8 characters.';
  if (body.role !== undefined && !validRoles.includes(body.role)) return 'role must be user or admin.';
  return null;
}

async function listUsers(req, res) {
  try {
    return res.json(await query(`SELECT ${safeUserFields} FROM users ORDER BY created_at DESC`));
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
  // const validationError = validateUser(req.body);
  // if (validationError) return res.status(400).json({ message: validationError });
  try {
    const passwordHash = await argon2.hash(req.body.password);
    const result = await query(
      'INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)',
      [req.body.username.trim(), passwordHash, req.body.role || 'user'],
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
  if (Number(req.params.userId) === req.auth.userId && req.body.role && req.body.role !== 'admin') {
    return res.status(400).json({ message: 'You cannot remove your own administrator role.' });
  }

  const updates = [];
  const values = [];
  if (req.body.username !== undefined) {
    updates.push('username = ?');
    values.push(req.body.username.trim());
  }
  if (req.body.role !== undefined) {
    updates.push('role = ?');
    values.push(req.body.role);
  }
  if (req.body.password !== undefined) updates.push('password_hash = ?');
  if (!updates.length) return res.status(400).json({ message: 'At least one user field is required.' });
  try {
    if (req.body.password !== undefined) values.push(await argon2.hash(req.body.password));
    const result = await query(
      `UPDATE users SET ${updates.join(', ')} WHERE user_id = ?`,
      [...values, req.params.userId],
    );
    if (!result.affectedRows) return res.status(404).json({ message: 'User not found.' });
    const rows = await query(`SELECT ${safeUserFields} FROM users WHERE user_id = ?`, [req.params.userId]);
    return res.json(rows[0]);
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

async function deleteUser(req, res) {
  if (!isPositiveId(req.params.userId)) return res.status(400).json({ message: 'userId must be a positive integer.' });
  if (Number(req.params.userId) === req.auth.userId) return res.status(400).json({ message: 'You cannot delete your own account.' });
  try {
    const result = await query('DELETE FROM users WHERE user_id = ?', [req.params.userId]);
    if (!result.affectedRows) return res.status(404).json({ message: 'User not found.' });
    return res.status(204).end();
  } catch (error) {
    return handleDatabaseError(res, error);
  }
}

module.exports = { listUsers, getUser, createUser, updateUser, deleteUser, safeUserFields };
