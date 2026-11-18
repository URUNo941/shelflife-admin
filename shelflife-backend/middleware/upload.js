const multer = require('multer');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const uploadDirectory = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(uploadDirectory, { recursive: true });

const extensionsByMimeType = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
};
const allowedExtensions = new Set(Object.values(extensionsByMimeType));

const storage = multer.diskStorage({
  destination(req, file, cb) {
    cb(null, uploadDirectory);
  },
  filename(req, file, cb) {
    cb(null, `${crypto.randomBytes(16).toString('hex')}${file.safeExtension}`);
  }
});

const fileFilter = (req, file, cb) => {
  const extension = path.extname(file.originalname).toLowerCase();
  const mimeExtension = extensionsByMimeType[file.mimetype];
  const extensionIsAllowed = allowedExtensions.has(extension);
  if ((!mimeExtension && file.mimetype !== 'application/octet-stream') ||
      (!mimeExtension && !extensionIsAllowed)) {
    return cb(new Error('Choose a JPEG, PNG, WebP or GIF image.'));
  }

  file.safeExtension = mimeExtension || extension;
  return cb(null, true);
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }
});

module.exports = { upload, uploadDirectory };