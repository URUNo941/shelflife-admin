const { requireAuth, requireRole } = require('./requireAuth');

// Admin เท่านั้น = ต้องมี JWT ที่ถูกต้อง และ role = admin
const onlyAdmin = requireRole('admin');

function requireAdmin(req, res, next) {
  return requireAuth(req, res, () => onlyAdmin(req, res, next));
}

module.exports = requireAdmin;
