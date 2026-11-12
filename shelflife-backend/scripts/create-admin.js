// Create an admin user, or reset an existing user's password and make them admin.
// Usage: node scripts/create-admin.js <username> <password>
require('dotenv').config();
const argon2 = require('argon2');
const pool = require('../db_config');

async function main() {
  const [username, password] = process.argv.slice(2);
  if (!username || !password) {
    console.error('Usage: node scripts/create-admin.js <username> <password>');
    process.exit(1);
  }
  const hash = await argon2.hash(password);
  const [rows] = await pool.query('SELECT user_id FROM users WHERE username = ?', [username]);
  if (rows.length) {
    await pool.query("UPDATE users SET password_hash = ?, role = 'admin' WHERE user_id = ?", [hash, rows[0].user_id]);
    console.log(`Updated password for "${username}" and set role to admin.`);
  } else {
    await pool.query("INSERT INTO users (username, password_hash, role) VALUES (?, ?, 'admin')", [username, hash]);
    console.log(`Created admin "${username}".`);
  }
  await pool.end();
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
