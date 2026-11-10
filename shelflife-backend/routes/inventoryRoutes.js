const express = require('express');
const router = express.Router();
const db = require('../db_config'); // ดึงค่าการเชื่อมต่อจากไฟล์ db_config.js

// 1. [GET] ดึงรายการสินค้าทั้งหมดของ User ตาม ID
router.get('/:userId', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT * FROM inventory_items WHERE user_id = ?', 
      [req.params.userId]
    );
    res.status(200).json(rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error fetching inventory items' });
  }
});

// 2. [POST] เพิ่มสินค้าใหม่เข้าคลัง
router.post('/', async (req, res) => {
  const { user_id, barcode, product_name, category, quantity, expiration_date } = req.body;
  
  try {
    const [result] = await db.query(
      'INSERT INTO inventory_items (user_id, barcode, product_name, category, quantity, expiration_date) VALUES (?, ?, ?, ?, ?, ?)',
      [user_id, barcode, product_name, category || 'General', quantity || 1, expiration_date]
    );
    
    res.status(201).json({ 
      message: 'Item added successfully', 
      item_id: result.insertId 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error saving the item' });
  }
});

// 3. [PUT] อัปเดตสถานะสินค้า (เช่น 'active', 'consumed', 'discarded')
router.put('/:itemId', async (req, res) => {
  const { status } = req.body;
  
  try {
    await db.query(
      'UPDATE inventory_items SET status = ? WHERE item_id = ?',
      [status, req.params.itemId]
    );
    res.status(200).json({ message: 'Item status updated successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error updating item status' });
  }
});

// 4. [DELETE] ลบสินค้าออกจากคลัง
router.delete('/:itemId', async (req, res) => {
  try {
    await db.query(
      'DELETE FROM inventory_items WHERE item_id = ?', 
      [req.params.itemId]
    );
    res.status(200).json({ message: 'Item deleted successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error deleting the item' });
  }
});

module.exports = router;