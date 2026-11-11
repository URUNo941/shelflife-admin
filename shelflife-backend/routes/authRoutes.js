const router = require("express").Router();
const c = require("../controllers/authController");
const { rateLimit } = require("express-rate-limit");
router.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 30,
    standardHeaders: "draft-8",
    legacyHeaders: false,
  }),
);
router.post("/login", c.login);
router.post("/register", c.register);
router.get("/me", require("../middleware/requireAuth"), (req, res) =>
  res.json(req.user),
);
module.exports = router;
