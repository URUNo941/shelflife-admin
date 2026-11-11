const mysql = require('mysql2/promise');
require('dotenv').config();

// สร้าง Connection Pool แบบ Promise เพื่อรองรับ async/await
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'shelflife_db',
  port: process.env.DB_PORT || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

console.log('Connected to MySQL Database: shelflife_db');

module.exports = pool;