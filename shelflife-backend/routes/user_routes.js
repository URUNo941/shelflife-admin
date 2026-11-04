const express = require('express');
const controller = require('../controllers/user_controller');
const { requireAuth, requireAdmin } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth, requireAdmin);
router.get('/', controller.getUsers);
router.get('/:userId', controller.getUser);
router.post('/', controller.createUser);
router.patch('/:userId', controller.updateUser);
router.delete('/:userId', controller.deleteUser);

module.exports = router;
