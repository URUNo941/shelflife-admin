const express = require('express');
const controller = require('../controllers/inventoryController');

const router = express.Router();

// เอาอันที่มีคำว่า /item/ ขึ้นมาก่อน
router.get('/item/:itemId', controller.getInventoryItem);
router.put('/item/:itemId', controller.updateInventoryItem);
router.delete('/item/:itemId', controller.deleteInventoryItem);

// เอาอันที่เป็นพารามิเตอร์เดี่ยวไว้ข้างล่าง
router.get('/:userId', controller.getInventoryItems);
router.post('/', controller.createInventoryItem);

module.exports = router;