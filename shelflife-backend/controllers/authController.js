const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const { query } = require('../utils/db');
const { safeUserFields } = require('./userController');

async function login(req, res) {
  const { username, password } = req.body || {};
  if (typeof username !== 'string' || !username.trim() || typeof password !== 'string' || !password) {
    return res.status(400).json({ message: 'username and password are required.' });
  }
if (!process.env.JWT_SECRET) {
  return res.status(503).json({ message: 'Authentication is not configured.' });
}

console.log('Login attempt for username:', username);  
try {
    const users = await query('SELECT * FROM users WHERE username = ?', [username.trim()]);
    if (!users.length || !(await argon2.verify(users[0].password_hash, password))) {
      return res.status(401).json({ message: 'Invalid username or password.' });
    }
    const user = users[0];
    const token = jwt.sign(
      { userId: user.user_id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '8h' },
    );
    const safeUsers = await query(`SELECT ${safeUserFields} FROM users WHERE user_id = ?`, [user.user_id]);
    return res.json({ token, user: safeUsers[0] });
  } catch (error) {
    console.error(error.message);
    return res.status(500).json({ message: 'Could not sign in.' });
  }
}

module.exports = { login };
