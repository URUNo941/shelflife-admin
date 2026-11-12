import 'product_model.dart';
import 'user_model.dart';

// =============================================================================
// MockData = ข้อมูลจำลอง (ข้อมูลปลอม) ใช้แทนฐานข้อมูลใน Sprint 3
// -----------------------------------------------------------------------------
// - Sprint 3 ยังไม่ต่อ frontend กับ backend แอปจึงใช้ข้อมูลชุดนี้แทนการดึงจาก API
// - Controller (UserController, ProductController) โหลดข้อมูลจากที่นี่ตอนเริ่มต้น
// - ข้อมูลตรงกับโครงสร้างตารางจริง (ใช้ ProductModel / UserModel) พอ Sprint 4
//   ต่อ API จริง ก็แค่ให้ Controller ดึงจาก API แทน ไม่ต้องแก้หน้าจอ
//
// คำถามที่อาจโดนถาม: "ทำไมเป็นฟังก์ชัน ไม่ใช่ตัวแปร list ธรรมดา?"
//   ตอบ: เรียกแต่ละครั้งได้ list "ใหม่" เสมอ
//   - ถ้าใช้ list ตัวเดียวร่วมกัน เวลา controller ลบ/แก้ข้อมูล ข้อมูลต้นฉบับจะเสียไปด้วย
//   - ทำให้ controller.reset() คืนค่าเริ่มต้นได้จริง
//   - unit test แต่ละตัวได้ข้อมูลสะอาด ไม่ปนกับ test อื่น
// =============================================================================
class MockData {
  // private constructor (ขึ้นต้นด้วย _) = ห้ามสร้าง object ของ class นี้
  // เพราะ class นี้มีไว้เก็บข้อมูลแบบ static อย่างเดียว เรียกใช้ตรงๆ: MockData.users()
  MockData._();

  // ---------------------------------------------------------------------------
  // สินค้าใน Master Barcode Catalog (หน้า Catalog ของ Admin)
  // - barcode ห้ามซ้ำกัน (มี unit test ตรวจสอบ)
  // - barcode ชุดนี้ตรงกับสินค้าในตู้ตัวอย่างของผู้ใช้ (UserInventory)
  //   จึงลองสแกน/พิมพ์ barcode แล้วระบบเติมชื่อสินค้าให้อัตโนมัติได้
  // - createdBy: 1 = เพิ่มโดย admin (user_id 1)
  // ---------------------------------------------------------------------------
  static List<ProductModel> globalProducts() => [
        ProductModel(
          productId: 1,
          barcode: '8850123456789',
          productName: 'Fresh Milk',
          category: 'Food',
          createdBy: 1,
          createdAt: DateTime(2026, 10, 1),
        ),
        ProductModel(
          productId: 2,
          barcode: '8850987654321',
          productName: 'Sliced Bread',
          category: 'Food',
          createdBy: 1,
          createdAt: DateTime(2026, 10, 1),
        ),
        ProductModel(
          productId: 3,
          barcode: '8850111222333',
          productName: 'Paracetamol 500mg',
          category: 'Medicine',
          createdBy: 1,
          createdAt: DateTime(2026, 10, 2),
        ),
        ProductModel(
          productId: 4,
          barcode: '8850444555666',
          productName: 'Instant Noodles',
          category: 'Food',
          createdBy: 1,
          createdAt: DateTime(2026, 10, 3),
        ),
        ProductModel(
          productId: 5,
          barcode: '8850777888999',
          productName: 'Eggs',
          category: 'Food',
          createdBy: 1,
          createdAt: DateTime(2026, 10, 3),
        ),
      ];

  // ---------------------------------------------------------------------------
  // รายชื่อผู้ใช้ (ใช้ทั้งหน้า Login และหน้า User Management ของ Admin)
  // - บัญชีสำหรับเดโม:  admin / 1234  -> เข้าหน้า Admin
  //                    user  / 1234  -> เข้าหน้า User
  //   (ผู้ใช้ตัวอย่างคนอื่นก็ล็อกอินด้วยรหัส 1234 ได้ ดู AuthController.demoPassword)
  // - ไม่มีรหัสผ่านเก็บในนี้ เพราะ UserModel ไม่มี field password (เหตุผลด้าน security)
  // - มี admin แค่ 1 คน เพื่อสาธิตกฎ "ห้ามลด role / ห้ามลบ admin คนสุดท้าย"
  // - userId ห้ามซ้ำกัน (มี unit test ตรวจสอบ)
  // ---------------------------------------------------------------------------
  static List<UserModel> users() => [
        UserModel(
          userId: 1,
          username: 'admin',
          email: 'admin@shelflife.app',
          role: UserModel.roleAdmin,
          createdAt: DateTime(2026, 10, 1),
        ),
        UserModel(
          userId: 2,
          username: 'user',
          email: 'user@shelflife.app',
          role: UserModel.roleUser,
          createdAt: DateTime(2026, 10, 3),
        ),
        UserModel(
          userId: 3,
          username: 'sarah',
          email: 'sarah@example.com',
          role: UserModel.roleUser,
          createdAt: DateTime(2026, 10, 5),
        ),
        UserModel(
          userId: 4,
          username: 'john',
          email: 'john@example.com',
          role: UserModel.roleUser,
          createdAt: DateTime(2026, 10, 10),
        ),
        UserModel(
          userId: 5,
          username: 'patlee',
          email: 'patlee@example.com',
          role: UserModel.roleUser,
          createdAt: DateTime(2026, 10, 12),
        ),
        UserModel(
          userId: 6,
          username: 'natsirin',
          email: 'natsirin@example.com',
          role: UserModel.roleUser,
          createdAt: DateTime(2026, 10, 15),
        ),
        UserModel(
          userId: 7,
          username: 'ployk',
          email: 'ployk@example.com',
          role: UserModel.roleUser,
          createdAt: DateTime(2026, 10, 18),
        ),
        UserModel(
          userId: 8,
          username: 'winm',
          email: 'winm@example.com',
          role: UserModel.roleUser,
          createdAt: DateTime(2026, 10, 20),
        ),
      ];
}
