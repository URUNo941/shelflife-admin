const mysql = require('mysql2');
require('dotenv').config();

const con = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'shelflife_db',
});

con.connect((err) => {
  if (err) {
    console.error('Database connection error:', err.message);
    return;
  }
  console.log('Connected to MySQL Database: shelflife_db');
});

module.exports = con;