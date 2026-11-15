const express = require('express');
const controller = require('../controllers/statsController');
const { requireAuth, requireRole } = require('../middleware/requireAuth');

const router = express.Router();

router.use(requireAuth);
router.get('/me', controller.myStats);
router.get('/system', requireRole('admin'), controller.systemStats);

module.exports = router;
