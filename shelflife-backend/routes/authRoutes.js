const express = require('express');
const controller = require('../controllers/authController');
const { requireAuth } = require('../middleware/requireAuth');

const router = express.Router();

router.post('/login', controller.login);
router.post('/register', controller.register);
router.get('/me', requireAuth, controller.me);
// Logout: JWT เป็น stateless แอปลบ token ทิ้งฝั่ง client ก็ออกจากระบบแล้ว

module.exports = router;
