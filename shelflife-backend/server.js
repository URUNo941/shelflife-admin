require('dotenv').config();

const express = require('express');
const cors = require('cors');
const path = require('path'); // เพิ่มเข้ามาเพื่อจัดการพาธไฟล์

const inventoryRoutes = require('./routes/inventoryRoutes');
const productRoutes = require('./routes/productRoutes');
const userRoutes = require('./routes/userRoutes');
const authRoutes = require('./routes/authRoutes');
const statsRoutes = require('./routes/statsRoutes');
const upload = require('./middleware/upload'); // นำเข้าตัวจัดการอัปโหลดที่เราเพิ่งสร้าง

const app = express();
app.use(cors());
app.use(express.json());

// --- เพิ่มส่วนนี้: อนุญาตให้ภายนอกเข้าถึงไฟล์ในโฟลเดอร์ uploads ได้ ---
// ถ้าเปิดเว็บหรือแอปมาเรียก http://localhost:3000/uploads/ชื่อไฟล์.png ก็จะเห็นรูปเลย
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// --- เพิ่มส่วนนี้: API สำหรับรับไฟล์รูปภาพ ---
// เรียกใช้เมื่อแอปส่งรูปมา จะตอบกลับเป็น URL ของรูปเพื่อเอาไปบันทึกใน Database
app.post('/api/upload', upload.single('image'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ message: 'No image file provided.' });
  }
  
  // สร้าง URL ของรูปที่เพิ่งอัปโหลดไป
  // (ถ้าเอาขึ้นเซิร์ฟเวอร์จริง ต้องเปลี่ยน http://localhost:3000 เป็นโดเมนจริง)
  const imageUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
  
  return res.status(200).json({ 
    message: 'Image uploaded successfully.',
    imageUrl: imageUrl 
  });
});

// Route ปกติของคุณ
app.use('/api/auth', authRoutes); // login / register / me
app.use('/api/items', inventoryRoutes); // ของในตู้ของผู้ใช้ (ต้อง login)
app.use('/api/products', productRoutes); // Master catalog (อ่านได้ทุกคน, แก้ได้เฉพาะ admin)
app.use('/api/users', userRoutes); // จัดการผู้ใช้ (admin)
app.use('/api/stats', statsRoutes); // สถิติ consumed vs discarded

// JSON ที่ส่งมาผิดรูปแบบ -> 400 แทน 500
app.use((error, req, res, next) => {
  // จัดการ Error กรณี Multer (ไฟล์รูปใหญ่เกิน หรือ ไม่ใช่รูป)
  if (error.name === 'MulterError') {
    return res.status(400).json({ message: error.message });
  }
  
  if (error.type === 'entity.parse.failed') {
    return res.status(400).json({ message: 'Request body must be valid JSON.' });
  }
  return next(error);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});