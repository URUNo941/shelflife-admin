const express = require('express');
const controller = require('../controllers/inventoryController');

const router = express.Router();

router.get('/:userId', controller.getInventoryItems);
router.get('/item/:itemId', controller.getInventoryItem);
router.post('/', controller.createInventoryItem);
router.put('/item/:itemId', controller.updateInventoryItem);
router.delete('/item/:itemId', controller.deleteInventoryItem);

module.exports = router;
