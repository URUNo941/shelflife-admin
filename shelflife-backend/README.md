# ShelfLife API

## ติดตั้งฐานข้อมูล (V2, 4 ตาราง)

1. เปิด XAMPP → Start **MySQL** → เปิด phpMyAdmin
2. แท็บ **Import** → เลือกไฟล์ `database/shelflife_v2_db.sql` → กด **Go**
   จะได้ฐานข้อมูลใหม่ `shelflife_v2_db` พร้อมข้อมูลตัวอย่าง (ฐานข้อมูลเก่า `shelflife_db` ไม่ถูกแก้)
3. รัน `node server.js` ตามปกติ API จะต่อกับ `shelflife_v2_db` ให้เอง
   (ถ้าต้องการใช้ชื่ออื่น ตั้ง `DB_NAME=...` ใน `.env`)

ถ้าอยากย้ายข้อมูลของตัวเองจาก `shelflife_db` เดิม ให้ใช้ `database/simple-v2/copy-to-test.js`
แทนข้อ 2 (ดู `database/simple-v2/README.md`) โดยตั้งชื่อปลายทางเป็น `shelflife_v2_db`

| ตาราง | เก็บอะไร |
|---|---|
| `users` | บัญชีผู้ใช้ |
| `categories` | ชื่อหมวดหมู่ (เก็บครั้งเดียว) |
| `products` | สินค้า: บาร์โค้ด ชื่อ หมวด (`category_id`) |
| `inventory_items` | ของในคลังแต่ละล็อต: ใคร (`user_id`) สินค้าอะไร (`product_id`) กี่ชิ้น หมดอายุเมื่อไร |

API ยังส่ง `barcode`, `product_name`, `category` เหมือนเดิม (อ่านผ่าน JOIN) Flutter จึงไม่ต้องแก้

เอกสารประกอบ (โฟลเดอร์ `database/`):

| ไฟล์ | คืออะไร |
|---|---|
| `ShelfLife_ER_Diagram_V2.pdf` / `.png` | ER diagram V2 (ไฟล์ต้นฉบับ `.svg` แก้ได้) |
| `ShelfLife_Data_Dictionary_V2.pdf` | พจนานุกรมข้อมูล export จาก phpMyAdmin: ชนิด, NULL, ค่า default, FK ทุกคอลัมน์ |
| `ShelfLife_ER_Diagram.pdf` | ER diagram แบบเก่า (V1) เก็บไว้เทียบก่อน/หลัง |

## ทดสอบ

```
npm test
```

ถ้าตั้ง `TEST_DB_HOST` (เช่น `127.0.0.1`), `TEST_DB_USER`, `TEST_DB_PASSWORD` จะทดสอบกับ MySQL จริงด้วย
โดยสร้างฐานข้อมูลชั่วคราวชื่อสุ่มแล้วลบทิ้งเอง ไม่แตะ `shelflife_db` หรือ `shelflife_v2_db`

## รันแอปทั้งระบบ

1. **ฐานข้อมูล:** ทำ "ติดตั้งฐานข้อมูล" ด้านบน
2. **บัญชี admin (ครั้งแรก):** ในโฟลเดอร์ `shelflife-backend`
   ```
   npm run create-admin -- admin <รหัสผ่านอย่างน้อย 6 ตัว>
   ```
   บัญชี user ทั่วไปสมัครเองได้จากหน้า Register ในแอป
   (บัญชีตัวอย่าง `tom123` / `sarah` ในไฟล์ SQL ใช้รหัสผ่านปลอม จึง login ไม่ได้)
3. **Backend:** `node server.js` (ต้องมี `JWT_SECRET` ใน `.env` หรือ environment) → `http://localhost:3000`
4. **แอป Flutter:** ที่โฟลเดอร์หลักของโปรเจกต์ `flutter run -d chrome` (หรือ `-d windows`)
   - Android emulator ต่อ `10.0.2.2:3000` ให้เอง
   - มือถือจริง: `flutter run --dart-define=API_BASE_URL=http://<IP เครื่องคอม>:3000/api`

## ตรงตามโจทย์ตรงไหน

| โจทย์ | ทำที่ไหน |
|---|---|
| MVC | Flutter: `lib/models`, `lib/views`, `lib/controllers` · Backend: `routes` → `controllers` → MySQL |
| Login / Logout / Register | `POST /api/auth/login`, `/register`, logout = ลบ JWT ในแอป (`AuthController.logout`) |
| 2 roles | `users.role` = `user` / `admin` → แอปพาไปหน้า User หรือ Admin |
| DB connection | `db_config.js` (mysql2 pool) → `shelflife_v2_db` |
| ≥ 3 หน้า + navigation | User: Home / Inventory / Account · Admin: Dashboard / Catalog / Users / Analytics |
| CRUD | ของในตู้ (user), แคตตาล็อกบาร์โค้ด (admin), ผู้ใช้ (admin) |
| Smart Barcode Auto-Fill | สแกน/พิมพ์บาร์โค้ด → `GET /api/products/master/:barcode` เติมชื่อ+หมวด |
| Expiry Color Coding & Smart Alerts | `lib/utils/expiry_status.dart` (เขียว/เหลือง/แดง) + แถบเตือนบนหน้า Home |
| Consumed vs Discarded Statistics | ปุ่ม Use one / Mark as consumed / discarded → `GET /api/stats/me`, `/api/stats/system` |
| argon2id | `hashPassword()` ใน `controllers/userController.js` (`type: argon2id`) |
| JWT role-based | `middleware/requireAuth.js` (ทุก endpoint ของ user) + `requireAdmin.js` |

## API routes

| Method | Route | Access |
|---|---|---|
| POST | `/api/auth/register` | Public (สมัครได้เฉพาะ role user) |
| POST | `/api/auth/login` | Public → `{ token, user }` |
| GET | `/api/auth/me` | Logged in |
| GET | `/api/items?status=active\|consumed\|discarded\|all` | Logged in (เฉพาะของตัวเอง) |
| GET, PUT, DELETE | `/api/items/:itemId` | เจ้าของล็อต (หรือ admin) |
| POST | `/api/items` | Logged in (เจ้าของ = ผู้ที่ login) |
| GET | `/api/stats/me?period=today\|week\|month\|year\|all` | Logged in |
| GET | `/api/stats/system?period=...` | Admin |
| GET | `/api/products`, `/api/products/:productId`, `/api/products/master/:barcode` | Public |
| POST, PUT, DELETE | `/api/products` and `/api/products/:productId` | Admin |
| GET, POST, PUT, DELETE | `/api/users` and `/api/users/:userId` | Admin (ลบ/ลดสิทธิ์ admin คนสุดท้ายไม่ได้) |

ส่ง token เป็น `Authorization: Bearer <token>` ทุก request ที่ต้อง login ข้อมูลผู้ใช้ที่ตอบกลับไม่มี password hash
ตัวอย่างคำขอทุกแบบอยู่ใน `api-demo.http` (ใช้กับ VS Code extension REST Client)
