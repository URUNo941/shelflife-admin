require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { upload, uploadDirectory } = require('./middleware/upload');
const { requireAuth } = require('./middleware/requireAuth');
const inventoryRoutes = require('./routes/inventoryRoutes');
const productRoutes = require('./routes/productRoutes');
const userRoutes = require('./routes/userRoutes');
const authRoutes = require('./routes/authRoutes');
const statsRoutes = require('./routes/statsRoutes');

const app = express();
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(uploadDirectory, {
  fallthrough: false,
  index: false,
}));

app.use('/api/auth', authRoutes); // login / register / me
app.post('/api/upload', requireAuth, (req, res) => {
  upload.single('image')(req, res, (error) => {
    if (error) {
      const status = error.code === 'LIMIT_FILE_SIZE' ? 413 : 400;
      return res.status(status).json({ message: error.message });
    }
    if (!req.file) {
      return res.status(400).json({ message: 'Select an image to upload.' });
    }
    return res.json({
      imageUrl: `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`,
    });
  });
});
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
