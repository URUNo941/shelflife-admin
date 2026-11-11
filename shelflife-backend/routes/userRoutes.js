const express = require("express");
const controller = require("../controllers/userController");
const requireAdmin = require("../middleware/requireAdmin");

const router = express.Router();

router.use(requireAdmin);
router.get("/", controller.listUsers);
router.get("/:userId", controller.getUser);
router.post("/", controller.createUser);
router.patch("/:userId", require("../controllers/userController").updateUser);
router.put("/:userId", controller.updateUser);
router.delete("/:userId", controller.deleteUser);

module.exports = router;
