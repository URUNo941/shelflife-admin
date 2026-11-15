const express = require('express');
const controller = require('../controllers/inventoryController');
const { requireAuth } = require('../middleware/requireAuth');

const router = express.Router();

// ทุก endpoint ต้อง login (JWT) และใช้ได้กับของในตู้ของตัวเองเท่านั้น
router.use(requireAuth);
router.get('/', controller.listMyItems); // ?status=active|consumed|discarded|all
router.get('/:itemId', controller.getInventoryItem);
router.post('/', controller.createInventoryItem);
router.put('/:itemId', controller.updateInventoryItem); // แก้ไข, Use one, Consumed, Discarded
router.delete('/:itemId', controller.deleteInventoryItem);

module.exports = router;
