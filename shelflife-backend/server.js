const express = require('express');
const cors = require('cors');
const con = require('./db_config'); // นำเข้าตัวเชื่อมต่อ DB[cite: 15]

const app = express();
app.use(cors()); // รองรับ CORS ให้ Flutter ยิงเข้าถึงได้[cite: 11, 16]
app.use(express.json()); // อ่าน JSON Request Body[cite: 16]

// ----------------------------------------------------
// 1. GET /api/items/:userId - ดึงรายการสินค้าทั้งหมดของผู้ใช้
// ----------------------------------------------------
app.get('/api/items/:userId', (req, res) => {
  const userId = req.params.userId;
  const sql = "SELECT * FROM inventory_items WHERE user_id = ? AND status = 'active' ORDER BY expiration_date ASC";
  
  con.query(sql, [userId], (err, result) => {
    if (err) {
      console.error(err.message);
      return res.status(500).send("Database server error");
    }
    res.json(result);
  });
});

// ----------------------------------------------------
// 2. POST /api/items - เพิ่มสินค้าใหม่เข้าตู้
// ----------------------------------------------------
app.post('/api/items', (req, res) => {
  const { user_id, barcode, product_name, category, quantity, expiration_date } = req.body;
  
  const sql = `INSERT INTO inventory_items 
               (user_id, barcode, product_name, category, quantity, expiration_date) 
               VALUES (?, ?, ?, ?, ?, ?)`;
               
  con.query(sql, [user_id, barcode, product_name, category || 'General', quantity || 1, expiration_date], (err, result) => {
    if (err) {
      console.error(err.message);
      return res.status(500).send("Error: Database server error");
    }
    if (result.affectedRows !== 1) {
      return res.status(500).send("Error: Incorrect insert");
    }
    res.status(201).send('Added successfully');
  });
});

// ----------------------------------------------------
// 3. GET /api/products/master/:barcode - ค้นหาบาร์โค้ดกลาง (Master Catalog)
// ----------------------------------------------------
app.get('/api/products/master/:barcode', (req, res) => {
  const barcode = req.params.barcode;
  const sql = "SELECT * FROM global_products WHERE barcode = ?";
  
  con.query(sql, [barcode], (err, result) => {
    if (err) {
      console.error(err.message);
      return res.status(500).send("Database server error");
    }
    if (result.length === 0) {
      return res.status(404).json({ message: "Barcode not found in master data" });
    }
    res.json(result[0]);
  });
});

// เริ่มทำงานเซิร์ฟเวอร์ที่ Port 3000
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});