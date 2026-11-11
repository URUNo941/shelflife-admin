const express = require("express");
const controller = require("../controllers/productController");
const requireAdmin = require("../middleware/requireAdmin");

const router = express.Router();

router.get("/", controller.listProducts);
router.get("/barcodes/:barcode", controller.getProductByBarcode);
router.get("/master/:barcode", controller.getProductByBarcode);
router.get("/:productId", controller.getProductById);
router.post("/", requireAdmin, controller.createProduct);
router.patch("/:productId", requireAdmin, controller.updateProduct);
router.put("/:productId", requireAdmin, controller.updateProduct);
router.delete("/:productId", requireAdmin, controller.deleteProduct);

module.exports = router;
