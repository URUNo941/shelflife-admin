const jwt = require('jsonwebtoken');

// ตรวจ JWT จาก header "Authorization: Bearer <token>"
// ผ่านแล้วจะได้ req.auth = { userId, role } ไว้ใช้เช็กสิทธิ์ต่อ
function requireAuth(req, res, next) {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    return res.status(503).json({ message: 'Authentication is not configured.' });
  }

  const authorization = req.get('authorization') || '';
  const [scheme, token] = authorization.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ message: 'Authentication required.' });
  }

  try {
    const payload = jwt.verify(token, secret);
    if (!Number.isInteger(payload.userId) || !['user', 'admin'].includes(payload.role)) {
      return res.status(401).json({ message: 'Invalid or expired token.' });
    }
    req.auth = { userId: payload.userId, role: payload.role };
    return next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid or expired token.' });
  }
}

// ใช้หลัง requireAuth: อนุญาตเฉพาะ role ที่กำหนด
function requireRole(role) {
  return (req, res, next) => {
    if (!req.auth || req.auth.role !== role) {
      return res.status(403).json({ message: 'Administrator access required.' });
    }
    return next();
  };
}

module.exports = { requireAuth, requireRole };
