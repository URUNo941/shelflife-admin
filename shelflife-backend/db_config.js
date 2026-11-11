const mysql = require('mysql2/promise');
require('dotenv').config();

// ฐานข้อมูล V2 (4 ตาราง) ชื่อ shelflife_v2_db
// สร้างได้โดย import ไฟล์ database/shelflife_v2_db.sql ใน phpMyAdmin
// (ฐานข้อมูลเก่า shelflife_db ไม่ถูกแก้ ถ้าต้องการใช้ชื่ออื่นให้ตั้ง DB_NAME ใน .env)
const databaseName = process.env.DB_NAME || 'shelflife_v2_db';

// สร้าง Connection Pool แบบ Promise เพื่อรองรับ async/await
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: databaseName,
  port: process.env.DB_PORT || 3306,
  // ส่งคอลัมน์ DATE (เช่น expiration_date) เป็นข้อความ '2026-11-20' ตรง ๆ
  // ไม่แปลงเป็นเวลา UTC ซึ่งทำให้ Flutter แสดงวันหมดอายุเร็วไป 1 วันในไทย
  dateStrings: ['DATE'],
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

console.log(`Using MySQL database: ${databaseName}`);

module.exports = pool;
