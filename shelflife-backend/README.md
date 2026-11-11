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

## Run

Set `JWT_SECRET` to a long, random secret in the backend process environment, then run `node server.js`. The database connection is configured in `db_config.js`; do not expose this development configuration in production. The API listens on port `3000` unless `PORT` is set.

## API routes

| Method | Route | Access |
|---|---|---|
| POST | `/api/auth/login` | Public |
| GET | `/api/items/:userId` | Existing inventory API |
| GET | `/api/items/item/:itemId` | Inventory API |
| POST | `/api/items` | Existing inventory API |
| PUT | `/api/items/item/:itemId` | Inventory API |
| DELETE | `/api/items/item/:itemId` | Inventory API |
| GET | `/api/products` | Public |
| GET | `/api/products/:productId` | Public |
| GET | `/api/products/master/:barcode` | Public |
| POST, PUT, DELETE | `/api/products` and `/api/products/:productId` | Admin bearer token |
| GET, POST, PUT, DELETE | `/api/users` and `/api/users/:userId` | Admin bearer token |

Send the login token as `Authorization: Bearer <token>` to protected routes. User responses omit password hashes; new and changed passwords are stored as Argon2 hashes.

The existing inventory endpoints remain unauthenticated for compatibility with the current Flutter client. Add authenticated user ownership checks and pass bearer tokens from the client before deploying this API beyond a trusted development environment.
