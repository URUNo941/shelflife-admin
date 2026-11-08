const jwt = require('jsonwebtoken');

function requireAdmin(req, res, next) {
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
    if (payload.role !== 'admin' || !Number.isInteger(payload.userId)) {
      return res.status(403).json({ message: 'Administrator access required.' });
    }
    req.auth = payload;
    return next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid or expired token.' });
  }
}

module.exports = requireAdmin;
