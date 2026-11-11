const requireAuth = require("./requireAuth");
module.exports = (req, res, next) =>
  requireAuth(req, res, () =>
    req.auth.role === "admin"
      ? next()
      : res.status(403).json({ message: "Administrator access required." }),
  );
