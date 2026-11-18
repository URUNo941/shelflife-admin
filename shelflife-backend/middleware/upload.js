const multer = require('multer');
const path = require('path');

// ตั้งค่าที่เก็บไฟล์และการตั้งชื่อไฟล์
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, path.join(__dirname, '..', 'uploads'));
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

// ปรับปรุงตัวกรองให้ยืดหยุ่นขึ้น (ยอมรับไฟล์ที่มีนามสกุลรูปภาพทั่วไป)
const fileFilter = (req, file, cb) => {
  // เช็คจากนามสกุลไฟล์โดยตรง (.jpg, .jpeg, .png, .webp, .gif) หรือเช็คจาก mimetype
  const allowedExtensions = /jpeg|jpg|png|webp|gif/;
  const extname = allowedExtensions.test(path.extname(file.originalname).toLowerCase());
  const mimetype = file.mimetype.startsWith('image/');

  if (extname || mimetype) {
    return cb(null, true);
  } else {
    return cb(new Error('รองรับเฉพาะไฟล์รูปภาพ (jpg, png, webp) เท่านั้น!'), false);
  }
};

const upload = multer({ 
  storage: storage,
  fileFilter: fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 } // จำกัดขนาดไม่เกิน 5MB
});

module.exports = upload;