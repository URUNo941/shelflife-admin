const mysql = require('mysql2');

// เชื่อมต่อ MySQL บน XAMPP
const con = mysql.createConnection({
  host: 'localhost',
  user: 'root',      // Default user ของ XAMPP
  password: '',      // Default password ของ XAMPP มักเป็นค่าว่าง
  database: 'shelflife_db'
});

con.connect((err) => {
  if (err) {
    console.error('Database connection error:', err.message);
    return;
  }
  console.log('Connected to MySQL Database: shelflife_db');
});

module.exports = con;