const express = require('express');
const controller = require('../controllers/product_controller');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();

router.get('/', requireAuth, controller.getProducts);
router.get('/master/:barcode', requireAuth, controller.getProductByBarcode);
router.get('/:productId', requireAuth, controller.getProduct);
router.post('/', requireAuth, requireAdmin, controller.createProduct);
router.patch('/:productId', requireAuth, requireAdmin, controller.updateProduct);
router.delete('/:productId', requireAuth, requireAdmin, controller.deleteProduct);

module.exports = router;
