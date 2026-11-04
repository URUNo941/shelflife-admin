const argon2 = require('argon2');
const db = require('../db_config');
const createHttpError = require('../utils/http_error');

const query = (sql, values) => db.promise().query(sql, values);
const validRoles = new Set(['user', 'admin']);
const publicUserFields = 'user_id, username, role, created_at, updated_at';

function validateUser(body, partial = false) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    throw createHttpError(400, 'A JSON object is required.');
  }
  if (!partial && (typeof body.username !== 'string' || typeof body.password !== 'string')) {
    throw createHttpError(400, 'username and password are required.');
  }
  if (body.username !== undefined &&
      (typeof body.username !== 'string' || body.username.trim().length === 0 || body.username.length > 50)) {
    throw createHttpError(400, 'username must be a non-empty string of at most 50 characters.');
  }
  if (body.password !== undefined &&
      (typeof body.password !== 'string' || body.password.length < 8)) {
    throw createHttpError(400, 'password must contain at least 8 characters.');
  }
  if (body.role !== undefined &&
      (typeof body.role !== 'string' || !validRoles.has(body.role.toLowerCase()))) {
    throw createHttpError(400, 'role must be user or admin.');
  }
}

async function getUsers(_req, res) {
  const [rows] = await query(`SELECT ${publicUserFields} FROM users ORDER BY user_id ASC`);
  res.json(rows);
}

async function getUser(req, res) {
  const userId = Number(req.params.userId);
  if (!Number.isInteger(userId) || userId < 1) {
    throw createHttpError(400, 'userId must be a positive integer.');
  }
  const [rows] = await query(`SELECT ${publicUserFields} FROM users WHERE user_id = ?`, [userId]);
  if (rows.length === 0) throw createHttpError(404, 'User not found.');
  res.json(rows[0]);
}

async function createUser(req, res) {
  const body = req.body;
  validateUser(body);
  const passwordHash = await argon2.hash(body.password);
  const [result] = await query(
    'INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)',
    [body.username.trim(), passwordHash, body.role?.toLowerCase() || 'user'],
  );
  const [rows] = await query(
    `SELECT ${publicUserFields} FROM users WHERE user_id = ?`,
    [result.insertId],
  );
  res.status(201).json(rows[0]);
}

async function updateUser(req, res) {
  const userId = Number(req.params.userId);
  if (!Number.isInteger(userId) || userId < 1) {
    throw createHttpError(400, 'userId must be a positive integer.');
  }
  validateUser(req.body, true);

  const updates = [];
  const values = [];
  if (req.body.username !== undefined) {
    updates.push('username = ?');
    values.push(req.body.username.trim());
  }
  if (req.body.role !== undefined) {
    updates.push('role = ?');
    values.push(req.body.role.toLowerCase());
  }
  if (req.body.password !== undefined) {
    updates.push('password_hash = ?');
    values.push(await argon2.hash(req.body.password));
  }
  if (updates.length === 0) throw createHttpError(400, 'At least one user field is required.');

  await query(`UPDATE users SET ${updates.join(', ')} WHERE user_id = ?`, [...values, userId]);
  const [rows] = await query(
    `SELECT ${publicUserFields} FROM users WHERE user_id = ?`,
    [userId],
  );
  if (rows.length === 0) throw createHttpError(404, 'User not found.');
  res.json(rows[0]);
}

async function deleteUser(req, res) {
  const userId = Number(req.params.userId);
  if (!Number.isInteger(userId) || userId < 1) {
    throw createHttpError(400, 'userId must be a positive integer.');
  }
  const [result] = await query('DELETE FROM users WHERE user_id = ?', [userId]);
  if (result.affectedRows === 0) throw createHttpError(404, 'User not found.');
  res.status(204).end();
}

module.exports = { getUsers, getUser, createUser, updateUser, deleteUser };
