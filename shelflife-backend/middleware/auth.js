const jwt = require('jsonwebtoken');

function requireAuth(req, res, next) {
  const authorization = req.get('authorization') || '';
  const [scheme, token] = authorization.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ message: 'A bearer token is required.' });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    if (!Number.isInteger(payload.userId) || !['user', 'admin'].includes(payload.role)) {
      return res.status(401).json({ message: 'Invalid authentication token.' });
    }
    req.auth = { userId: payload.userId, role: payload.role };
    return next();
  } catch {
    return res.status(401).json({ message: 'Invalid or expired authentication token.' });
  }
}

function requireAdmin(req, res, next) {
  if (req.auth.role !== 'admin') {
    return res.status(403).json({ message: 'Administrator access is required.' });
  }
  return next();
}

function requireSelfOrAdmin(req, res, next) {
  const userId = Number(req.params.userId);
  if (req.auth.role !== 'admin' && req.auth.userId !== userId) {
    return res.status(403).json({ message: 'You may only access your own inventory.' });
  }
  return next();
}

module.exports = { requireAuth, requireAdmin, requireSelfOrAdmin };
