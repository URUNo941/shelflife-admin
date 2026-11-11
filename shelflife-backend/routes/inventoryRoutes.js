const express = require('express');
const router = express.Router();
const { query, withTransaction } = require('../utils/db');
const { ITEM_SELECT, productIdFor } = require('../utils/catalog');

const validStatuses = ['active', 'consumed', 'discarded'];

// 1. [GET] ดึงรายการสินค้าทั้งหมดของ User ตาม ID
// ชื่อสินค้า/บาร์โค้ด/หมวดหมู่ อ่านจากตาราง products และ categories ผ่าน JOIN
router.get('/:userId', async (req, res) => {
  try {
    const rows = await query(
      `${ITEM_SELECT} WHERE i.user_id = ? ORDER BY i.expiration_date, i.item_id`,
      [req.params.userId]
    );
    res.status(200).json(rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error fetching inventory items' });
  }
});

// 2. [POST] เพิ่มสินค้าใหม่เข้าคลัง
// รับข้อมูลรูปแบบเดิม (barcode, product_name, category) แล้วหา/สร้างสินค้าใน products
// คลังเก็บแค่ product_id จึงไม่มีชื่อสินค้าซ้ำซ้อน
router.post('/', async (req, res) => {
  const { user_id, barcode, product_name, category, quantity, expiration_date } = req.body || {};
  if (typeof product_name !== 'string' || !product_name.trim()) {
    return res.status(400).json({ message: 'product_name is required' });
  }

  try {
    const itemId = await withTransaction(async (q) => {
      const productId = await productIdFor(q, {
        barcode,
        product_name,
        category,
        created_by: user_id,
      });
      const result = await q(
        'INSERT INTO inventory_items (user_id, product_id, quantity, expiration_date) VALUES (?, ?, ?, ?)',
        [user_id, productId, quantity || 1, expiration_date]
      );
      return result.insertId;
    });

    res.status(201).json({
      message: 'Item added successfully',
      item_id: itemId
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error saving the item' });
  }
});

// 3. [PUT] อัปเดตสถานะสินค้า (เช่น 'active', 'consumed', 'discarded')
// บันทึกเวลาที่เปลี่ยนสถานะด้วย (ฐานข้อมูลบังคับให้ consumed/discarded ต้องมีเวลา)
router.put('/:itemId', async (req, res) => {
  const { status } = req.body || {};
  if (!validStatuses.includes(status)) {
    return res.status(400).json({ message: 'status must be active, consumed or discarded' });
  }

  try {
    await query(
      'UPDATE inventory_items SET status = ?, status_updated_at = CURRENT_TIMESTAMP WHERE item_id = ?',
      [status, req.params.itemId]
    );
    res.status(200).json({ message: 'Item status updated successfully' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Error updating item status' });
  }
});

// 4. [DELETE] ลบสินค้าออกจากคลัง (ลบเฉพาะล็อตนี้ ข้อมูลสินค้าใน products ยังอยู่)
router.delete('/:itemId', async (req, res) => {
  try {
    await query(
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
