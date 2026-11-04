require('dotenv').config();
const argon2 = require('argon2');
const db = require('../db_config');

async function createAdmin() {
  const { ADMIN_USERNAME: username, ADMIN_PASSWORD: password } = process.env;
  if (!username || !password || password.length < 8) {
    throw new Error('Set ADMIN_USERNAME and an ADMIN_PASSWORD of at least 8 characters.');
  }

  const connection = db.promise();
  const [admins] = await connection.query(
    "SELECT COUNT(*) AS count FROM users WHERE role = 'admin'",
  );
  if (admins[0].count > 0) {
    throw new Error('An administrator already exists; refusing to create another bootstrap account.');
  }

  const passwordHash = await argon2.hash(password);
  await connection.query(
    'INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)',
    [username, passwordHash, 'admin'],
  );
  console.log(`Administrator "${username}" created.`);
}

createAdmin()
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(() => db.end());
