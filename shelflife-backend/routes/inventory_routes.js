const express = require('express');
const controller = require('../controllers/inventory_controller');
const { requireAuth, requireSelfOrAdmin } = require('../middleware/auth');

const router = express.Router();

router.get('/:userId/:itemId', requireAuth, requireSelfOrAdmin, controller.getItem);
router.get('/:userId', requireAuth, requireSelfOrAdmin, controller.getItems);
router.post('/', requireAuth, controller.createItem);
router.patch('/:itemId', requireAuth, controller.updateItem);
router.delete('/:itemId', requireAuth, controller.deleteItem);

module.exports = router;
