require('dotenv').config();

const express = require('express');
const cors = require('cors');
const inventoryRoutes = require('./routes/inventoryRoutes');
const productRoutes = require('./routes/productRoutes');
const userRoutes = require('./routes/userRoutes');
const authRoutes = require('./routes/authRoutes');
const statsRoutes = require('./routes/statsRoutes');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes); // login / register / me
app.use('/api/items', inventoryRoutes); // ของในตู้ของผู้ใช้ (ต้อง login)
app.use('/api/products', productRoutes); // Master catalog (อ่านได้ทุกคน, แก้ได้เฉพาะ admin)
app.use('/api/users', userRoutes); // จัดการผู้ใช้ (admin)
app.use('/api/stats', statsRoutes); // สถิติ consumed vs discarded

// JSON ที่ส่งมาผิดรูปแบบ -> 400 แทน 500
app.use((error, req, res, next) => {
  if (error.type === 'entity.parse.failed') {
    return res.status(400).json({ message: 'Request body must be valid JSON.' });
  }
  return next(error);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
