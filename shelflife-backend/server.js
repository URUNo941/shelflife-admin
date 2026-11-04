const express = require('express');
const cors = require('cors');
require('dotenv').config();
const authRoutes = require('./routes/auth_routes');
const inventoryRoutes = require('./routes/inventory_routes');
const productRoutes = require('./routes/product_routes');
const userRoutes = require('./routes/user_routes');

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET must be set in the backend environment.');
}

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/items', inventoryRoutes);
app.use('/api/products', productRoutes);
app.use('/api/users', userRoutes);

app.use((req, res) => {
  res.status(404).json({ message: 'Route not found.' });
});

app.use((error, _req, res, _next) => {
  if (error.status) {
    return res.status(error.status).json({ message: error.message });
  }
  if (error.code === 'ER_DUP_ENTRY') {
    return res.status(409).json({ message: 'A record with the same unique value already exists.' });
  }
  if (error.code === 'ER_ROW_IS_REFERENCED_2' || error.code === 'ER_NO_REFERENCED_ROW_2') {
    return res.status(409).json({ message: 'The record is referenced by another record.' });
  }
  if (error instanceof SyntaxError && 'body' in error) {
    return res.status(400).json({ message: 'Request body must contain valid JSON.' });
  }
  console.error(error);
  return res.status(500).json({ message: 'Internal server error.' });
});

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || '127.0.0.1';
if (require.main === module) {
  app.listen(PORT, HOST, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
  });
}

module.exports = app;
