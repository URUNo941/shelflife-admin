const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const db = require('../db_config');
const createHttpError = require('../utils/http_error');

async function login(req, res) {
  const { username, password } = req.body ?? {};
  if (typeof username !== 'string' || typeof password !== 'string') {
    throw createHttpError(400, 'username and password are required.');
  }

  const [rows] = await db.promise().query(
    'SELECT user_id, username, password_hash, role FROM users WHERE username = ?',
    [username.trim()],
  );
  if (rows.length === 0 || !(await argon2.verify(rows[0].password_hash, password))) {
    throw createHttpError(401, 'Invalid username or password.');
  }

  const user = rows[0];
  const token = jwt.sign(
    { userId: user.user_id, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: '8h' },
  );
  res.json({
    token,
    user: { user_id: user.user_id, username: user.username, role: user.role },
  });
}

module.exports = { login };
