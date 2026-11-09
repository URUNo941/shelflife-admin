const express = require('express');
const controller = require('../controllers/userController');
const requireAdmin = require('../middleware/requireAdmin');

const router = express.Router();

router.use(requireAdmin); // ถ้าไม่มี Admin ให้ Comment ที่บรรทัดนี้ก่อน แล้วRegister Userเสร็จค่อยมาเปิด
router.get('/', controller.listUsers);
router.get('/:userId', controller.getUser);
router.post('/', controller.createUser);
router.put('/:userId', controller.updateUser);
router.delete('/:userId', controller.deleteUser);

module.exports = router;
