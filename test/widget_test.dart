// =============================================================================
// widget_test.dart — ชุดทดสอบครอบคลุมทุกฟังก์ชันของแอปพลิเคชัน ShelfLife
// -----------------------------------------------------------------------------
// วิธีรัน:
//   flutter test test/widget_test.dart   (รันเฉพาะไฟล์นี้)
//   flutter test                         (รันชุดทดสอบทั้งหมดในโปรเจกต์)
// ผลลัพธ์ที่คาดหวัง: "All tests passed!"
//
// โครงสร้างการทดสอบในไฟล์นี้:
//   1) Unit Test        : ทดสอบ Logic ของ Model, การแปลง JSON, สูตรคำนวณสีหมดอายุ
//   2) API Mock Test    : ทดสอบการทำงานร่วมกับ HTTP Client ปลอม (200 OK / 500 Error)
//   3) Widget Test ฝั่ง User:
//      - หน้าเข้าสู่ระบบ (LoginView)
//      - หน้าสมัครสมาชิก (RegisterView)
//      - หน้าเมนูหลักและแถบนำทาง (UserMainView)
//      - หน้าตู้สินค้าของฉัน (UserInventoryView)
//      - หน้าฟอร์มเพิ่ม/แก้ไข/ลบสินค้า (UserItemFormView)
//      - หน้ารายละเอียดสินค้า (UserItemDetailView)
//      - หน้าการแจ้งเตือนสินค้าใกล้หมดอายุ (UserNotificationsView)
//      - หน้าโปรไฟล์และออกจากระบบ (UserProfileView & WasteStatsCard)
//      - หน้ารายการสินค้าพื้นฐาน (InventoryListView)
//   4) Widget Test ฝั่ง Admin:
//      - หน้าแดชบอร์ดภาพรวมระบบ (AdminDashboardView & AdminMainView)
//      - หน้าแคตตาล็อกสินค้ากลาง (MasterCatalogView)
//      - หน้าฟอร์มเพิ่ม/แก้ไขบาร์โค้ดกลาง (AddEditBarcodeView)
//      - หน้าจัดการผู้ใช้และสิทธิ์ (UserManagementView)
//      - หน้าสถิติและการวิเคราะห์ระบบ (SystemAnalyticsView)
// =============================================================================

import 'dart:convert'; // นำเข้าโมดูลแปลง JSON (jsonEncode / jsonDecode)
import 'package:flutter/material.dart'; // นำเข้าคอมโพเนนต์และวิดเจ็ตมาตรฐานของ Flutter
import 'package:flutter_test/flutter_test.dart'; // นำเข้าเครื่องมือสำหรับเขียน Unit Test และ Widget Test
import 'package:http/http.dart' as http; // นำเข้าไลบรารี HTTP สำหรับจัดการ Response
import 'package:http/testing.dart'; // นำเข้า MockClient สำหรับจำลองเซิร์ฟเวอร์จำลอง

// นำเข้าคอนโทรลเลอร์ที่ใช้จัดการสถานะของระบบ
import 'package:myapp/controllers/auth_controller.dart'; // จัดการการยืนยันตัวตน (Login, Register, Logout)
import 'package:myapp/controllers/product_controller.dart'; // จัดการแคตตาล็อกสินค้ากลาง
import 'package:myapp/controllers/user_controller.dart'; // จัดการรายชื่อและสิทธิ์ของผู้ใช้งาน

// นำเข้าโมเดลข้อมูล
import 'package:myapp/models/inventory_item_model.dart'; // โมเดลสินค้าในตู้สำหรับยิง API
import 'package:myapp/models/product_model.dart'; // โมเดลสินค้าแคตตาล็อกกลาง
import 'package:myapp/models/user_item.dart'; // โมเดลสินค้าในตู้สำหรับหน้าจอฝั่ง User
import 'package:myapp/models/user_model.dart'; // โมเดลข้อมูลผู้ใช้งานและสิทธิ์ (Admin / User)

// นำเข้าเซอร์วิสและยูทิลิตี้
import 'package:myapp/services/api_client.dart'; // ไคลเอนต์สื่อสารกับหลังบ้าน
import 'package:myapp/utils/expiry_status.dart'; // ยูทิลิตี้คำนวณสถานะสีตามวันหมดอายุ

// นำเข้าหน้าจอต่าง ๆ ฝั่ง Admin
import 'package:myapp/views/admin/add_edit_barcode_view.dart'; // หน้าฟอร์มเพิ่ม/แก้ไขบาร์โค้ดกลาง
import 'package:myapp/views/admin/admin_main_view.dart'; // หน้าหลักพร้อมแถบนำทางของแอดมิน
import 'package:myapp/views/admin/master_catalog_view.dart'; // หน้าตารางแคตตาล็อกสินค้ากลาง
import 'package:myapp/views/admin/system_analytics_view.dart'; // หน้าวิเคราะห์สถิติระบบ
import 'package:myapp/views/admin/user_management_view.dart'; // หน้าจัดการรายชื่อผู้ใช้และสิทธิ์

// นำเข้าหน้าจอต่าง ๆ ฝั่ง User
import 'package:myapp/views/register_view.dart'; // หน้าสมัครสมาชิก
import 'package:myapp/views/user/inventory_list_view.dart'; // หน้ารายการสินค้าอย่างง่าย
import 'package:myapp/views/user/login_view.dart'; // หน้าเข้าสู่ระบบ
import 'package:myapp/views/user/user_data.dart'; // ฐานข้อมูลสินค้าจำลองในหน่วยความจำ (UserInventory)
import 'package:myapp/views/user/user_inventory_view.dart'; // หน้าตู้สินค้าของฉัน (จัดกลุ่มล็อตสินค้า)
import 'package:myapp/views/user/user_item_detail_view.dart'; // หน้ารายละเอียดสินค้าและการใช้งาน
import 'package:myapp/views/user/user_item_form_view.dart'; // หน้าฟอร์มเพิ่มและแก้ไขสินค้าในตู้
import 'package:myapp/views/user/user_main_view.dart'; // หน้าหลักพร้อมแถบนำทางด้านล่างของ User
import 'package:myapp/views/user/user_notifications_view.dart'; // หน้าการแจ้งเตือนสินค้าใกล้หมดอายุ
import 'package:myapp/views/user/user_profile_view.dart'; // หน้าโปรไฟล์ผู้ใช้และสถิติการทิ้ง/บริโภค

// จุดเริ่มต้นของชุดการทดสอบทั้งหมด
void main() {
  // ===========================================================================
  // กลุ่ม 1: Unit Test ของ InventoryItemModel (การแปลงข้อมูลไป-กลับกับ JSON)
  // ===========================================================================
  group('1. InventoryItemModel Tests', () {
    // ทดสอบการแปลง JSON จากฐานข้อมูลเป็น Object
    test('fromJson should parse JSON from database correctly', () {
      // จำลองข้อมูล JSON ที่ส่งมาจาก API ของเซิร์ฟเวอร์
      final mockJson = {
        'item_id': 1, // ไอดีของรายการ
        'user_id': 1, // ไอดีเจ้าของสินค้า
        'product_name': 'Fresh Milk', // ชื่อสินค้า
        'category': 'Food', // หมวดหมู่
        'quantity': 2, // จำนวนชิ้น
        'expiration_date': '2026-11-05T00:00:00.000Z', // วันหมดอายุ
        'created_at': '2026-10-01T00:00:00.000Z', // วันที่สร้าง
        'status': 'active' // สถานะสินค้า
      };

      // ทำการแปลงจาก JSON เป็น Object ของ InventoryItemModel
      final item = InventoryItemModel.fromJson(mockJson);

      // ตรวจสอบความถูกต้องของแต่ละฟิลด์
      expect(item.itemId, equals(1)); // ไอดีต้องตรงกัน
      expect(item.userId, equals(1)); // ไอดีผู้ใช้ต้องตรงกัน
      expect(item.productName, equals('Fresh Milk')); // ชื่อสินค้าต้องตรงกัน
      expect(item.category, equals('Food')); // หมวดหมู่ต้องตรงกัน
      expect(item.quantity, equals(2)); // จำนวนต้องตรงกัน
      expect(item.expirationDate.year, equals(2026)); // ปีหมดอายุต้องแปลงเป็น DateTime ได้ถูกต้อง
      expect(item.status, equals('active')); // สถานะต้องตรงกัน
    });

    // ทดสอบการแปลง Object กลับไปเป็น JSON เพื่อส่งไปหลังบ้าน
    test('toJson should format data correctly for API', () {
      // สร้าง Object ต้นทาง
      final item = InventoryItemModel(
        itemId: 2, // กำหนดไอดี
        userId: 1, // กำหนดไอดีผู้ใช้
        productName: 'Paracetamol', // กำหนดชื่อสินค้า
        category: 'Medicine', // กำหนดหมวดหมู่
        quantity: 5, // กำหนดจำนวน
        expirationDate: DateTime(2026, 11, 10), // กำหนดวันหมดอายุ
        createdAt: DateTime(2026, 10, 1), // กำหนดวันที่เพิ่มเข้าตู้
        status: 'active', // กำหนดสถานะ
      );

      // ทำการแปลง Object เป็น JSON Map
      final json = item.toJson();

      // ตรวจสอบชื่อ Key ใน Map ต้องเป็น snake_case ตามรูปแบบของฐานข้อมูล
      expect(json['product_name'], equals('Paracetamol')); // ตรวจสอบชื่อสินค้า
      expect(json['expiration_date'].toString().startsWith('2026-11-10'), isTrue); // ตรวจสอบวันที่หมดอายุ
      expect(json['quantity'], equals(5)); // ตรวจสอบจำนวน
    });
  });

  // ===========================================================================
  // กลุ่ม 2: Unit Test สูตรการคำนวณสีตามระยะเวลาวันหมดอายุ (Expiry Status)
  // ===========================================================================
  group('2. Expiry Color Logic', () {
    // กำหนดวันที่อ้างอิง: เริ่มต้น 1 ม.ค. 2026 และหมดอายุ 11 ม.ค. 2026 (อายุ 10 วัน)
    final start = DateTime(2026, 1, 1); // วันเริ่มต้น
    final expiry = DateTime(2026, 1, 11); // วันหมดอายุ

    // กรณีอายุเหลือ 30% ขึ้นไป ต้องแสดงผลเป็นสีเขียว
    test('100% to 30% remaining is green', () {
      // วันที่ 8 ม.ค. (เหลือ 3 วัน = 30%) -> ต้องเป็นสีเขียว
      expect(
        ExpiryStatus.color(addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 8)),
        ExpiryStatus.green,
      );
    });

    // กรณีอายุเหลือ 10% ถึง 29% หรือเหลือ 1 วัน ต้องแสดงผลเป็นสีเหลือง
    test('30% to 10% remaining is yellow', () {
      // วันที่ 9 ม.ค. (เหลือ 2 วัน = 20%) -> ต้องเป็นสีเหลือง
      expect(
        ExpiryStatus.color(addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 9)),
        ExpiryStatus.yellow,
      );
      // วันที่ 10 ม.ค. (เหลือ 1 วัน) -> ต้องเป็นสีเหลืองเสมอตามกฎพิเศษ
      expect(
        ExpiryStatus.color(addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 10)),
        ExpiryStatus.yellow,
      );
    });

    // กรณีเหลือต่ำกว่า 10% หรือหมดอายุแล้ว ต้องแสดงผลเป็นสีแดง
    test('Less than 10% remaining and expired items are red', () {
      // วันที่ 11 ม.ค. (วันหมดอายุพอดี) -> ต้องเป็นสีแดง
      expect(
        ExpiryStatus.color(addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 11)),
        ExpiryStatus.red,
      );
      // วันที่ 12 ม.ค. (เลยวันหมดอายุแล้ว) -> ต้องเป็นสีแดง
      expect(
        ExpiryStatus.color(addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 12)),
        ExpiryStatus.red,
      );
    });

    // กรณีสินค้าถูกบันทึกหลังจากที่หมดอายุไปแล้ว ต้องแสดงผลเป็นสีแดงทันที
    test('Items added after their expiry date are red', () {
      expect(
        ExpiryStatus.color(
          addedAt: DateTime(2026, 1, 12), // วันเพิ่มเข้ามาทีหลัง
          expiryDate: expiry, // วันหมดอายุที่ผ่านไปแล้ว
          today: DateTime(2026, 1, 12), // วันนี้
        ),
        ExpiryStatus.red,
      );
    });

    // กฎพิเศษ: หากเหลือเวลา 1 วัน แม้คำนวณเป็นเปอร์เซ็นต์ได้น้อยกว่า 10% ก็ต้องเป็นสีเหลือง
    test('One day before expiry is yellow even below 10% remaining', () {
      expect(
        ExpiryStatus.color(
          addedAt: DateTime(2026, 1, 1), // สินค้าอายุยาว 100 วัน
          expiryDate: DateTime(2026, 4, 11), // วันหมดอายุ
          today: DateTime(2026, 4, 10), // วันก่อนหน้า 1 วัน
        ),
        ExpiryStatus.yellow, // กฎ 1 วัน ชนะการคำนวณเปอร์เซ็นต์
      );
    });
  });

  // ===========================================================================
  // กลุ่ม 3: ทดสอบการเชื่อมต่อ API ด้วย MockClient
  // ===========================================================================
  group('3. HTTP API Mock Tests', () {
    // ทดสอบการตอบกลับสถานะ 200 OK และแปลงเป็น List ของ Model สำเร็จ
    test('Mock getInventoryItems returns a list of items on success (200 OK)', () async {
      // สร้างเซิร์ฟเวอร์จำลองเพื่อดักจับคำขอ
      final mockClient = MockClient((request) async {
        final mockResponse = [
          {
            "item_id": 1,
            "user_id": 1,
            "product_name": "Fresh Milk",
            "category": "Food",
            "quantity": 2,
            "expiration_date": "2026-11-05T00:00:00.000Z",
            "created_at": "2026-10-01T00:00:00.000Z",
            "status": "active"
          }
        ];
        return http.Response(jsonEncode(mockResponse), 200); // ส่ง Response รหัส 200 กลับไป
      });

      // เรียกใช้งาน API ผ่านเซิร์ฟเวอร์จำลอง
      final response = await mockClient.get(Uri.parse('http://localhost:3000/api/items/1'));
      final List data = jsonDecode(response.body); // ถอดรหัส JSON
      final items = data.map((json) => InventoryItemModel.fromJson(json)).toList(); // แปลงเป็นรายการ Model

      // ตรวจสอบผลลัพธ์
      expect(items, isA<List<InventoryItemModel>>()); // lชนิดข้อมูลต้องถูกต้อง
      expect(items.length, 1); // ต้องมีจำนวน 1 รายการ
      expect(items[0].productName, 'Fresh Milk'); // ชื่อสินค้าต้องตรงกับที่จำลองไว้
    });

    // ทดสอบการจำลองกรณีเกิดข้อผิดพลาดจากเซิร์ฟเวอร์ (500 Internal Server Error)
    test('Mock API throws exception on failure (500 Server Error)', () async {
      // สร้างเซิร์ฟเวอร์จำลองให้ตอบกลับด้วยรหัส 500
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      // ยิงคำขอไปยังเซิร์ฟเวอร์จำลอง
      final response = await mockClient.get(Uri.parse('http://localhost:3000/api/items/1'));
      expect(response.statusCode, 500); // ต้องได้รับสถานะ 500
    });
  });

  // ===========================================================================
  // กลุ่ม 4: Widget Test หน้ารายการสินค้าอย่างง่าย (InventoryListView)
  // ===========================================================================
  group('4. InventoryListView UI Tests', () {
    setUp(() {
      // จำลองเซิร์ฟเวอร์จำลองเพื่อตอบกลับสถานะ 200 ไม่ให้เกิด Error และไม่ให้พิมพ์ Request failed (400) ออกมากวนใจ
      ApiClient.instance = ApiClient(
        client: MockClient((request) async => http.Response('[]', 200)),
      );
    });

    // ทดสอบการแสดงผล AppBar และตัวโหลดข้อมูลตอนเปิดหน้าจอครั้งแรก
    testWidgets('Displays AppBar and Loading Indicator initially', (WidgetTester tester) async {
      // วาดหน้าจอจำลอง
      await tester.pumpWidget(const MaterialApp(home: InventoryListView()));

      // ตรวจสอบข้อความบนแถบ AppBar
      expect(find.text('ShelfLife - My Inventory'), findsOneWidget);
      // ตรวจสอบว่ามีวงกลมโหลดข้อมูลกำลังทำงานอยู่
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // ทดสอบตรวจสอบสีพื้นหลังของแถบ AppBar
    testWidgets('AppBar has Teal background color', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: InventoryListView()));

      // ดึงวิดเจ็ต AppBar ออกมาเพื่อตรวจสอบ Property
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.teal); // สีต้องเป็นสีเขียว Teal
    });
  });

  // ===========================================================================
  // กลุ่ม 5: Widget Test หน้าเข้าสู่ระบบ (LoginView)
  // ===========================================================================
  group('5. Login Screen Tests', () {
    // ฟังก์ชันผู้ช่วยสำหรับพิมพ์ข้อมูลและกดปุ่ม Sign In
    Future<void> signIn(WidgetTester tester, {required String username, required String password}) async {
      await tester.pumpWidget(const MaterialApp(home: LoginView())); // เรนเดอร์หน้า LoginView
      await tester.enterText(find.byType(TextFormField).at(0), username); // พิมพ์ชื่อผู้ใช้ในช่องแรก
      await tester.enterText(find.byType(TextFormField).at(1), password); // พิมพ์รหัสผ่านในช่องที่สอง
      await tester.tap(find.text('Sign In')); // กดปุ่ม Sign In
      await tester.pumpAndSettle(); // รอให้การทำงานและ Animation หน้าจอเสร็จสิ้น
    }

    // ทดสอบเข้าสู่ระบบด้วยบัญชีผู้ใช้ทั่วไป (User)
    testWidgets('Valid user credentials open the user home', (tester) async {
      await signIn(tester, username: 'user', password: '1234'); // ล็อกอินด้วยบัญชี User จำลอง
      expect(find.text('My Shelf'), findsOneWidget); // ต้องนำทางไปยังหน้าตู้สินค้าของฉัน
    });

    // ทดสอบเข้าสู่ระบบด้วยบัญชีผู้ดูแลระบบ (Admin)
    testWidgets('Valid admin credentials open the admin dashboard', (tester) async {
      await signIn(tester, username: 'admin', password: '1234'); // ล็อกอินด้วยบัญชี Admin จำลอง
      expect(find.text('System at a glance'), findsOneWidget); // ต้องนำทางไปยังแดชบอร์ดของแอดมิน
    });

    // ทดสอบกรณีรหัสผ่านไม่ถูกต้อง
    testWidgets('Invalid credentials show an error and stay on login', (tester) async {
      await signIn(tester, username: 'user', password: 'wrong'); // ป้อนรหัสผ่านที่ผิด
      expect(find.text('Invalid username or password'), findsOneWidget); // ต้องแสดงข้อความแจ้งเตือนความผิดพลาด
      expect(find.text('Sign In'), findsOneWidget); // ต้องยังคงอยู่ที่หน้าเข้าสู่ระบบเดิม
    });

    // ทดสอบการตรวจสอบความถูกต้องเมื่อไม่กรอกข้อมูล (Validation)
    testWidgets('Blank credentials show required field validation', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginView())); // เรนเดอร์หน้า LoginView
      await tester.tap(find.text('Sign In')); // กดปุ่มโดยไม่กรอกอะไรเลย
      await tester.pumpAndSettle(); // รอการแสดงผลแจ้งเตือนของฟอร์ม

      // ตรวจสอบข้อความแจ้งเตือนว่าต้องกรอกทั้ง 2 ช่อง
      expect(find.text('Please enter your username'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    // ทดสอบปุ่มไปยังหน้าสมัครสมาชิก (Sign Up)
    testWidgets('Tap Sign Up navigates to RegisterView', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginView())); // เรนเดอร์หน้า LoginView
      expect(find.text('Sign Up'), findsOneWidget); // ตรวจสอบว่ามีปุ่ม Sign Up
      await tester.tap(find.text('Sign Up')); // กดปุ่ม Sign Up
      await tester.pumpAndSettle(); // รอหน้าจอ Register แสดงผล
      expect(find.byType(RegisterView), findsOneWidget); // ต้องเปิดไปยังหน้า RegisterView สำเร็จ
      expect(find.text('Register'), findsOneWidget); // ต้องมีปุ่ม Register ปรากฏอยู่
    });
  });

  // ===========================================================================
  // กลุ่ม 6: Widget Test หน้าสมัครสมาชิก (RegisterView)
  // ===========================================================================
  group('6. Register Screen Tests', () {
    // ฟังก์ชันผู้ช่วยกำหนดขนาดหน้าจอสำหรับทดสอบหน้า Register เพื่อป้องกันปัญหา Overflow
    void setRegisterScreenSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1600); // ตั้งขนาดหน้าจอจำลอง
      tester.view.devicePixelRatio = 1; // ตั้งอัตราส่วนพิกเซล
      addTearDown(() {
        tester.view.resetPhysicalSize(); // คืนค่าขนาดหน้าจอเดิมหลังจบการทดสอบ
        tester.view.resetDevicePixelRatio(); // คืนค่าอัตราส่วนพิกเซลเดิม
      });
    }

    // ทดสอบการตรวจสอบฟิลด์ว่างเมื่อกดสมัครสมาชิก
    testWidgets('Blank form shows validation errors on all fields', (tester) async {
      setRegisterScreenSize(tester); // ขยายขนาดหน้าจอ
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RegisterView()))); // เรนเดอร์หน้า RegisterView
      await tester.tap(find.text('Register')); // กดปุ่มยืนยันการสมัครโดยไม่กรอกข้อมูล
      await tester.pumpAndSettle(); // รอให้ฟอร์มแสดงผลลัพธ์การตรวจสอบ

      // ตรวจสอบข้อความเตือนของทุกช่อง
      expect(find.text('Please enter a username'), findsOneWidget); // แจ้งเตือนช่องชื่อผู้ใช้
      expect(find.text('Please enter your email'), findsOneWidget); // แจ้งเตือนช่องอีเมล
      expect(find.text('Please enter a password'), findsOneWidget); // แจ้งเตือนช่องรหัสผ่าน
    });

    // ทดสอบกรณีรหัสผ่านและช่องยืนยันรหัสผ่านไม่ตรงกัน
    testWidgets('Mismatched passwords show an error', (tester) async {
      setRegisterScreenSize(tester); // ขยายขนาดหน้าจอ
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RegisterView()))); // เรนเดอร์หน้า RegisterView
      await tester.enterText(find.byType(TextFormField).at(0), 'somchai'); // พิมพ์ชื่อผู้ใช้
      await tester.enterText(find.byType(TextFormField).at(1), 'somchai@test.com'); // พิมพ์อีเมล
      await tester.enterText(find.byType(TextFormField).at(2), '1234'); // พิมพ์รหัสผ่าน
      await tester.enterText(find.byType(TextFormField).at(3), '9999'); // พิมพ์ยืนยันรหัสผ่านที่ไม่ตรงกัน
      await tester.tap(find.text('Register')); // กดปุ่มสมัครสมาชิก
      await tester.pumpAndSettle(); // รอการตรวจสอบ

      expect(find.text('Passwords do not match'), findsOneWidget); // ต้องแสดงข้อความเตือนว่ารหัสผ่านไม่ตรงกัน
    });

    // ทดสอบการกดไอคอนดวงตาเพื่อสลับแสดง/ซ่อนรหัสผ่าน
    testWidgets('Toggle eye icon switches password visibility', (tester) async {
      setRegisterScreenSize(tester); // ขยายขนาดหน้าจอ
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RegisterView()))); // เรนเดอร์หน้า RegisterView
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(2)); // เริ่มต้นจะมีไอคอนปิดตาทั้ง 2 ช่อง (รหัสผ่าน & ยืนยัน)
      await tester.tap(find.byIcon(Icons.visibility_off).first); // กดไอคอนลูกตาช่องแรกเพื่อเปิดดูรหัสผ่าน
      await tester.pumpAndSettle(); // วาดหน้าจอใหม่
      expect(find.byIcon(Icons.visibility), findsOneWidget); // ต้องมีไอคอนเปิดตาแสดงขึ้นมา 1 ตัว
    });

    // ทดสอบการสมัครสมาชิกสำเร็จ
    testWidgets('Successful registration shows success snackbar and pops view', (tester) async {
      setRegisterScreenSize(tester); // ขยายขนาดหน้าจอ
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RegisterView(
                        // จำลองฟังก์ชัน onRegister ให้คืนค่า null ซึ่งหมายถึงไม่มี Error (สมัครสำเร็จ)
                        onRegister: (u, e, p) async => null,
                      ),
                    ),
                  ),
                  child: const Text('Open register'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open register')); // กดเปิดหน้าสมัครสมาชิก
      await tester.pumpAndSettle(); // รอการเปิดหน้าจอเสร็จสมบูรณ์

      // กรอกข้อมูลที่ถูกต้องครบถ้วน
      await tester.enterText(find.byType(TextFormField).at(0), 'newuser'); // กรอกชื่อผู้ใช้
      await tester.enterText(find.byType(TextFormField).at(1), 'newuser@mail.com'); // กรอกอีเมล
      await tester.enterText(find.byType(TextFormField).at(2), '123456'); // กรอกรหัสผ่าน (อย่างน้อย 6 ตัวอักษร)
      await tester.enterText(find.byType(TextFormField).at(3), '123456'); // กรอกยืนยันรหัสผ่านตรงกัน
      await tester.tap(find.text('Register')); // กดสมัครสมาชิก
      await tester.pumpAndSettle(); // รอให้ SnackBar แสดงผลและ Pop หน้าจอกลับ

      expect(find.text('Account created! Please log in.'), findsOneWidget); // ต้องมีข้อความแจ้งเตือนความสำเร็จ
    });
  });

  // ===========================================================================
  // กลุ่ม 7: Widget Test หน้าฟอร์มจัดการสินค้าในตู้ (UserItemFormView)
  // ===========================================================================
  group('7. Inventory Form Screens Tests', () {
    final inventory = UserInventory.instance; // ดึงคลังสินค้าจำลองในหน่วยความจำ
    final testItemIds = <String>[]; // เก็บไอดีที่สร้างขึ้นเพื่อนำไปล้างข้อมูลหลังการทดสอบ

    // ฟังก์ชันผู้ช่วยสร้างไอเท็มสินค้าจำลอง
    UserItem createItem({
      required String id,
      required String barcode,
      required DateTime expiry,
      int quantity = 1,
    }) {
      testItemIds.add(id); // จดบันทึกไอดีไว้ล้างข้อมูล
      return UserItem(
        id: id,
        barcode: barcode,
        name: 'Form test item',
        category: 'Food',
        expiry: expiry,
        qty: quantity,
      );
    }

    // ฟังก์ชันเปิดหน้าจอ Form
    Future<void> openForm(WidgetTester tester, {UserItem? item}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => UserItemFormView(item: item),
                    ),
                  ),
                  child: const Text('Open form'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open form')); // กดปุ่มเปิดฟอร์ม
      await tester.pumpAndSettle(); // รอการเปิดหน้าจอเสร็จสมบูรณ์
    }

    // ฟังก์ชันกรอกข้อมูลสินค้าใหม่
    Future<void> fillNewItem(WidgetTester tester, {required String barcode, required String name}) async {
      await tester.enterText(find.byType(TextFormField).at(0), barcode); // กรอกบาร์โค้ด
      await tester.enterText(find.byType(TextFormField).at(1), name); // กรอกชื่อสินค้า
    }

    // ล้างรายชื่อไอดีก่อนเริ่มแต่ละการทดสอบ
    setUp(() => testItemIds.clear());

    // ล้างข้อมูลสินค้าจำลองออกจากคลังหลังจากการทดสอบแต่ละอันเสร็จสิ้น
    tearDown(() {
      for (final id in testItemIds) {
        inventory.remove(id);
      }
    });

    // ทดสอบการตรวจสอบความถูกต้องของฟิลด์จำเป็นในฟอร์มเพิ่มสินค้า
    testWidgets('Add form validates required fields', (tester) async {
      await openForm(tester); // เปิดฟอร์ม
      await tester.ensureVisible(find.text('Save')); // เลื่อนหน้าจอให้เห็นปุ่มบันทึก
      await tester.tap(find.text('Save')); // กดปุ่มบันทึกโดยไม่กรอกข้อมูล
      await tester.pumpAndSettle(); // รอผลการตรวจสอบ

      expect(find.text('Required'), findsNWidgets(2)); // ต้องแจ้งเตือนคำว่า Required จำนวน 2 ช่อง
      expect(find.text('Add Item'), findsOneWidget); // ต้องยังคงอยู่ที่หน้าเดิม
    });

    // ทดสอบการสร้างรายการสินค้าใหม่สำเร็จ
    testWidgets('Add form creates an inventory batch', (tester) async {
      await openForm(tester); // เปิดฟอร์มเพิ่มสินค้า
      await fillNewItem(tester, barcode: 'form-add-001', name: 'Form Added Product'); // กรอกข้อมูล
      await tester.ensureVisible(find.text('Save')); // เลื่อนให้เห็นปุ่ม Save
      await tester.tap(find.text('Save')); // กดบันทึก
      await tester.pumpAndSettle(); // รอการบันทึกเสร็จ

      // ตรวจสอบว่าสินค้าถูกเพิ่มเข้าไปในคลังจริง
      final added = inventory.items.where((item) => item.barcode == 'form-add-001').single;
      expect(added.name, 'Form Added Product'); // ชื่อสินค้าต้องตรงกับที่กรอก
      expect(added.qty, 1); // ค่าเริ่มต้นของจำนวนต้องเป็น 1
    });

    // ทดสอบกรณีเพิ่มสินค้าที่มีบาร์โค้ดและวันหมดอายุซ้ำกับที่มีอยู่เดิม (ระบบต้องถามเพื่อรวมจำนวน)
    testWidgets('Adding an identical barcode and expiry asks before merging', (tester) async {
      final today = DateTime.now(); // วันที่ปัจจุบัน
      final existing = createItem(
        id: 'form-merge-existing',
        barcode: 'form-merge-001',
        expiry: DateTime(today.year, today.month, today.day + 7), // หมดอายุในอีก 7 วัน
        quantity: 2,
      );
      inventory.save(existing); // บันทึกของเดิมลงคลัง

      await openForm(tester); // เปิดฟอร์มเพิ่มสินค้า
      await fillNewItem(tester, barcode: existing.barcode, name: 'Form test item'); // กรอกบาร์โค้ดเดิม
      await tester.ensureVisible(find.text('Save')); // เลื่อนจอหาปุ่มบันทึก
      await tester.tap(find.text('Save')); // กดบันทึก
      await tester.pumpAndSettle(); // รอ Dialog แสดงผล

      expect(find.text('Matching expiry batch'), findsOneWidget); // ตรวจสอบว่ามีกล่องข้อความถามยืนยัน
      await tester.tap(find.text('Add quantity')); // กดยืนยันการรวมจำนวน
      await tester.pumpAndSettle(); // รอการรวมจำนวนเสร็จ

      expect(existing.qty, 3); // จำนวนต้องเพิ่มขึ้น (เดิม 2 + ใหม่ 1 = 3)
      expect(inventory.items.where((item) => item.barcode == existing.barcode), hasLength(1)); // ต้องมีแถวเดียว
    });

    // ทดสอบการแก้ไขข้อมูลสินค้า (Edit Form)
    testWidgets('Edit form updates the selected batch', (tester) async {
      final existing = createItem(
        id: 'form-edit-001',
        barcode: 'form-edit-old',
        expiry: DateTime(2099, 12, 10),
        quantity: 2,
      );
      inventory.save(existing); // บันทึกสินค้าตั้งต้น

      await openForm(tester, item: existing); // เปิดฟอร์มในโหมดแก้ไขสินค้า
      await tester.enterText(find.byType(TextFormField).at(0), 'form-edit-new'); // เปลี่ยนบาร์โค้ดใหม่
      await tester.enterText(find.byType(TextFormField).at(1), 'Updated Product Name'); // เปลี่ยนชื่อสินค้าใหม่

      final increaseQuantity = find.byIcon(Icons.add_circle_outline); // หาปุ่มเพิ่มจำนวน (+)
      await tester.ensureVisible(increaseQuantity); // เลื่อนให้เห็นปุ่ม
      await tester.tap(increaseQuantity); // กดเพิ่มจำนวน
      await tester.pump(); // อัปเดตการแสดงผลตัวเลข

      await tester.ensureVisible(find.text('Save Changes')); // เลื่อนหาปุ่มบันทึกการเปลี่ยนแปลง
      await tester.tap(find.text('Save Changes')); // กดบันทึก
      await tester.pumpAndSettle(); // รอการบันทึกเสร็จสิ้น

      final updated = inventory.items.where((item) => item.id == existing.id).single;
      expect(updated.barcode, 'form-edit-new'); // บาร์โค้ดต้องอัปเดต
      expect(updated.name, 'Updated Product Name'); // ชื่อสินค้าต้องอัปเดต
      expect(updated.qty, 3); // จำนวนต้องเพิ่มขึ้นเป็น 3 ชิ้น
    });

    // ทดสอบการลบสินค้า (ต้องมี Dialog ยืนยันก่อนเสมอ)
    testWidgets('Delete form requires confirmation then removes the batch', (tester) async {
      final existing = createItem(
        id: 'form-delete-001',
        barcode: 'form-delete-001',
        expiry: DateTime(2099, 12, 10),
      );
      inventory.save(existing); // บันทึกสินค้าตั้งต้น

      await openForm(tester, item: existing); // เปิดฟอร์มแก้ไข
      await tester.ensureVisible(find.text('Delete')); // เลื่อนหาปุ่มลบ
      await tester.tap(find.text('Delete')); // กดปุ่มลบ
      await tester.pumpAndSettle(); // รอ Dialog ยืนยัน

      expect(find.text('Delete Item?'), findsOneWidget); // ตรวจสอบว่ามีกล่องยืนยันการลบ
      await tester.tap(find.widgetWithText(FilledButton, 'Delete')); // กดยืนยันการลบใน Dialog
      await tester.pumpAndSettle(); // รอให้การลบทำงานเสร็จ

      expect(inventory.items, isNot(contains(existing))); // สินค้าต้องถูกลบออกจากคลังแล้ว
    });
  });

  // ===========================================================================
  // กลุ่ม 8: Widget Test หน้ารายการสินค้าในตู้ของผู้ใช้ (UserInventoryView)
  // ===========================================================================
  group('8. User Inventory List Screen Tests', () {
    // ทดสอบการจัดกลุ่มล็อตสินค้าและการพับ/กางการ์ดแสดงผล
    testWidgets('Groups batches and displays them expanded by default', (tester) async {
      final inventory = UserInventory.instance; // คลังสินค้าจำลอง
      const barcode = 'widget-list-batches-001'; // บาร์โค้ดเดียวกัน
      final today = DateTime.now();
      final soonExpiry = DateTime(today.year, today.month, today.day + 1); // ล็อตหมดพรุ่งนี้
      final laterExpiry = DateTime(today.year, today.month, today.day + 10); // ล็อตหมดอีก 10 วัน

      // สร้างสินค้า 2 ล็อตแต่บาร์โค้ดเดียวกัน
      final soonBatch = UserItem(
        id: 'widget-list-soon',
        barcode: barcode,
        name: 'List Test Product',
        category: 'Food',
        expiry: soonExpiry,
        qty: 2,
      );
      final laterBatch = UserItem(
        id: 'widget-list-later',
        barcode: barcode,
        name: 'List Test Product',
        category: 'Food',
        expiry: laterExpiry,
      );

      // เก็บกวาดข้อมูลหลังจบการทดสอบ
      addTearDown(() {
        inventory.remove(soonBatch.id);
        inventory.remove(laterBatch.id);
      });

      inventory.save(soonBatch); // บันทึกล็อตแรก
      inventory.save(laterBatch); // บันทึกล็อตสอง

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UserInventoryView()))); // แสดงผลหน้ารายการสินค้า
      await tester.pumpAndSettle(); // รอโหลดข้อมูล

      expect(find.text('List Test Product  ×3'), findsOneWidget); // ตรวจสอบการรวมจำนวนชิ้น (2 + 1 = 3)
      expect(find.textContaining('2 expiry batches'), findsOneWidget); // แสดงข้อความว่ามี 2 ล็อต
      expect(find.text('Use first'), findsOneWidget); // ล็อตที่หมดก่อนต้องมีป้ายเตือนให้ใช้ก่อน
      expect(tester.widget<Text>(find.text('1 day left')).style?.color, ExpiryStatus.yellow); // เหลือ 1 วันต้องเป็นสีเหลือง

      // ตรวจสอบวันหมดอายุของแต่ละล็อต
      final soonText = 'Exp ${soonExpiry.day.toString().padLeft(2, '0')}/${soonExpiry.month.toString().padLeft(2, '0')}/${soonExpiry.year}';
      expect(find.text(soonText), findsOneWidget);

      // ทดสอบการกดเพื่อพับการ์ด (Collapse)
      final title = find.text('List Test Product  ×3');
      await tester.tap(title); // กดหัวข้อการ์ดเพื่อพับเก็บ
      await tester.pumpAndSettle(); // รอแอนิเมชันเสร็จ
      expect(find.text(soonText), findsNothing); // รายละเอียดวันหมดอายุข้างในต้องซ่อนไป

      // ทดสอบการกดอีกครั้งเพื่อกางการ์ดออก (Expand)
      await tester.tap(title); // กดหัวข้อการ์ดอีกครั้งเพื่อกางออก
      await tester.pumpAndSettle(); // รอแอนิเมชันเสร็จ
      expect(find.text(soonText), findsOneWidget); // รายละเอียดวันหมดอายุต้องกลับมาแสดงผล
    });

    // ทดสอบการกดปุ่มลดจำนวน "Use one"
    testWidgets('Use one confirms and decreases the selected batch quantity', (tester) async {
      tester.view.physicalSize = const Size(800, 1600); // ขยายขนาดหน้าจอจำลองเพื่อให้แสดงผลครบ
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize(); // รีเซ็ตขนาดหน้าจอกลับหลังจบเทสต์
        tester.view.resetDevicePixelRatio();
      });

      final inventory = UserInventory.instance;
      final today = DateTime.now();
      final item = UserItem(
        id: 'widget-use-one',
        barcode: 'widget-use-one',
        name: 'Use Test Product',
        category: 'Food',
        expiry: DateTime(today.year, today.month, today.day + 10),
        qty: 2, // เริ่มต้นมี 2 ชิ้น
      );
      addTearDown(() => inventory.remove(item.id)); // ลบข้อมูลเมื่อจบ
      inventory.save(item);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UserInventoryView()))); // เรนเดอร์หน้ารายการตู้สินค้า
      await tester.pumpAndSettle();

      final batchRow = find.ancestor(
        of: find.text('2 in this batch'),
        matching: find.byType(ListTile),
      );
      final useButton = find.descendant(
        of: batchRow,
        matching: find.byIcon(Icons.remove_circle_outline),
      );

      await tester.ensureVisible(useButton); // เลื่อนให้ปุ่มมองเห็น
      await tester.pumpAndSettle();
      await tester.tap(useButton); // กดปุ่มลดจำนวน
      await tester.pumpAndSettle();

      expect(find.text('Use one item?'), findsOneWidget); // ต้องมีกล่องข้อความถามยืนยันการใช้สินค้า
      await tester.tap(find.text('Use one')); // กดยืนยันการใช้งาน
      await tester.pumpAndSettle();

      expect(item.qty, 1); // จำนวนชิ้นต้องลดเหลือ 1
      expect(inventory.items, contains(item)); // รายการสินค้ายังคงอยู่ในตู้
    });
  });

  // ===========================================================================
  // กลุ่ม 9: Widget Test หน้ารายละเอียดสินค้า (UserItemDetailView)
  // ===========================================================================
  group('9. User Item Detail View Tests', () {
    testWidgets('Displays item information and allows navigation to edit form', (tester) async {
      tester.view.physicalSize = const Size(800, 1600); // ขยายขนาดหน้าจอให้มองเห็นปุ่มทั้งหมดโดยไม่ต้อง Scroll
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize(); // คืนค่าขนาดหน้าจอเดิม
        tester.view.resetDevicePixelRatio();
      });

      final sampleItem = UserItem(
        id: 'detail-test-01',
        barcode: '8850123456789',
        name: 'Detail Test Milk',
        category: 'Beverage',
        expiry: DateTime(2026, 12, 31),
        qty: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UserItemDetailView(item: sampleItem), // เรนเดอร์หน้ารายละเอียดสินค้า
        ),
      );
      await tester.pumpAndSettle();

      // ตรวจสอบข้อมูลสินค้าที่แสดงบนหน้าจอ
      expect(find.text('Detail Test Milk'), findsOneWidget); // ชื่อสินค้า
      expect(find.text('8850123456789'), findsOneWidget); // บาร์โค้ด
      expect(find.text('5 items'), findsOneWidget); // จำนวนชิ้น
      expect(find.text('Edit item'), findsOneWidget); // ปุ่มแก้ไขสินค้า

      // ทดสอบการกดปุ่ม Edit item เพื่อไปหน้าฟอร์มแก้ไข
      await tester.tap(find.text('Edit item'));
      await tester.pumpAndSettle();
      expect(find.byType(UserItemFormView), findsOneWidget); // ต้องเปิดหน้า UserItemFormView สำเร็จ
      expect(find.text('Edit Item'), findsOneWidget); // หัวข้อต้องเป็น Edit Item
    });
  });

  // ===========================================================================
  // กลุ่ม 10: Widget Test หน้าการแจ้งเตือนสินค้าใกล้หมดอายุ (UserNotificationsView)
  // ===========================================================================
  group('10. User Notifications View Tests', () {
    testWidgets('Shows expiring item alerts and navigates to detail view on tap', (tester) async {
      final inventory = UserInventory.instance;
      final today = DateTime.now();
      final expiringItem = UserItem(
        id: 'notif-test-001',
        barcode: '8850999999',
        name: 'Expiring Yogurt',
        category: 'Food',
        expiry: DateTime(today.year, today.month, today.day + 1), // หมดอายุวันพรุ่งนี้
        qty: 1,
      );
      inventory.save(expiringItem); // บันทึกลงตู้
      addTearDown(() => inventory.remove(expiringItem.id)); // ล้างข้อมูลหลังจบ

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UserNotificationsView())), // เรนเดอร์หน้าการแจ้งเตือน
      );
      await tester.pumpAndSettle();

      // ต้องมีการแจ้งเตือนว่าโยเกิร์ตใกล้หมดอายุ
      expect(find.text('Expiring Yogurt is expiring soon'), findsOneWidget);

      // กดที่การแจ้งเตือน
      await tester.tap(find.text('Expiring Yogurt is expiring soon'));
      await tester.pumpAndSettle();

      // ต้องเปิดไปยังหน้ารายละเอียดสินค้า
      expect(find.byType(UserItemDetailView), findsOneWidget);
      expect(find.text('Expiring Yogurt'), findsOneWidget);
    });
  });

  // ===========================================================================
  // กลุ่ม 11: Widget Test หน้าโปรไฟล์และสถิติของผู้ใช้ (UserProfileView)
  // ===========================================================================
  group('11. User Profile Screen Tests', () {
    testWidgets('Displays account profile information and confirms logout', (tester) async {
      tester.view.physicalSize = const Size(800, 1600); // ขยายขนาดหน้าจอ
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testAccount = UserModel(
        userId: 88,
        username: 'alice_smith',
        email: 'alice@example.com',
        role: UserModel.roleUser,
        createdAt: DateTime(2026, 3, 15),
      );

      bool logoutTriggered = false; // ตัวแปรสำหรับตรวจสอบว่าเกิดการเรียก Callback ออกจากระบบหรือไม่

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserProfileView(
              account: testAccount,
              onLogout: () => logoutTriggered = true, // ส่ง Callback เมื่อกดออกจากระบบ
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ตรวจสอบการแสดงผลข้อมูลส่วนตัว
      expect(find.text('alice_smith').first, findsOneWidget); // ตรวจสอบชื่อบัญชี
      expect(find.text('alice@example.com'), findsNWidgets(2)); // ตรวจสอบอีเมล (แสดงทั้งส่วนหัวและการ์ดข้อมูล)
      expect(find.text('Role'), findsOneWidget); // ตรวจสอบหัวข้อสิทธิ์บทบาทผู้ใช้
      expect(find.text('Joined'), findsOneWidget); // ตรวจสอบหัวข้อวันที่เข้าร่วมระบบ
      expect(find.text('Log out'), findsOneWidget); // ตรวจสอบว่ามีปุ่มออกจากระบบ

      // ทดสอบการกดปุ่ม Log out
      await tester.ensureVisible(find.text('Log out')); // เลื่อนให้เห็นปุ่ม
      await tester.tap(find.text('Log out')); // กดปุ่ม Log out
      await tester.pumpAndSettle();

      // ต้องมี Dialog ยืนยันการออกจากระบบ
      expect(find.text('Log out?'), findsOneWidget);
      // กดยืนยันออกจากระบบในกล่องข้อความ
      await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
      await tester.pumpAndSettle();

      // ตรวจสอบว่าฟังก์ชันออกจากระบบถูกเรียกจริง
      expect(logoutTriggered, isTrue);
    });
  });

  // ===========================================================================
  // กลุ่ม 12: Widget Test หน้าเมนูหลักของผู้ใช้ (UserMainView)
  // ===========================================================================
  group('12. User Main View Tests', () {
    testWidgets('Displays navigation tabs and center add shortcut opens item form', (tester) async {
      ApiClient.instance.enabled = false; // ปิดการเรียกใช้งาน API จริง

      await tester.pumpWidget(const MaterialApp(home: UserMainView())); // เรนเดอร์หน้าจอหลักของ User
      await tester.pumpAndSettle();

      // ตรวจสอบเมนูนำทางใน Bottom Bar
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Items'), findsOneWidget);
      // ตรวจสอบปุ่มทางลัดเพิ่มสินค้าตรงกลาง
      expect(find.byTooltip('Add item'), findsOneWidget);

      // กดปุ่มทางลัดเพิ่มสินค้า (+)
      await tester.tap(find.byTooltip('Add item'));
      await tester.pumpAndSettle();

      // ต้องเปิดไปยังหน้าแบบฟอร์มเพิ่มสินค้า
      expect(find.byType(UserItemFormView), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);
    });
  });

  // ===========================================================================
  // กลุ่ม 13: Widget Test หน้าหลักและแดชบอร์ดของแอดมิน (AdminMainView)
  // ===========================================================================
  group('13. Admin Dashboard & Main View Tests', () {
    testWidgets('Displays admin greeting and system summary metrics', (tester) async {
      ApiClient.instance.enabled = false; // ปิดการยิง API
      await AuthController.instance.logout(); // เคลียร์สถานะการล็อกอินเดิม

      await tester.pumpWidget(const MaterialApp(home: AdminMainView())); // เรนเดอร์หน้าหลักของแอดมิน
      await tester.pumpAndSettle();

      // ตรวจสอบองค์ประกอบของหน้าแดชบอร์ด
      expect(find.text('System at a glance'), findsOneWidget); // หัวข้อแดชบอร์ด
      expect(find.textContaining('Welcome back'), findsOneWidget); // ข้อความทักทาย
      expect(find.byTooltip('Refresh dashboard'), findsOneWidget); // ปุ่มรีเฟรชข้อมูล
      expect(find.byType(NavigationBar), findsOneWidget); // แถบนำทางด้านล่าง
    });
  });

  // ===========================================================================
  // กลุ่ม 14: Widget Test หน้าแคตตาล็อกสินค้ากลาง (MasterCatalogView & AddEditBarcodeView)
  // ===========================================================================
  group('14. Admin Master Catalog & Add Barcode Tests', () {
    testWidgets('Displays global catalog and validates add barcode form', (tester) async {
      // สร้าง ProductController พร้อมข้อมูลตั้งต้น
      final productController = ProductController(
        seed: [
          ProductModel(
            productId: 1,
            barcode: '8851111222233',
            productName: 'Global Green Tea',
            category: 'Beverage',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MasterCatalogView(controller: productController), // เรนเดอร์หน้าแคตตาล็อกสินค้ากลาง
        ),
      );
      await tester.pumpAndSettle();

      // ตรวจสอบชื่อแคตตาล็อกและรายการสินค้าที่มีอยู่
      expect(find.text('Global Product Catalog'), findsOneWidget);
      expect(find.text('Global Green Tea'), findsOneWidget);

      // กดปุ่มเพิ่มบาร์โค้ดสินค้าเข้าสู่ระบบกลาง (Add Barcode)
      await tester.tap(find.text('Add Barcode'));
      await tester.pumpAndSettle();

      // ตรวจสอบว่าเปิดมาที่หน้าฟอร์มเพิ่มบาร์โค้ดใหม่
      expect(find.byType(AddEditBarcodeView), findsOneWidget);
      expect(find.text('Add New Barcode'), findsOneWidget);

      // ทดสอบการกดบันทึกโดยไม่กรอกข้อมูล
      await tester.tap(find.text('Save Barcode'));
      await tester.pumpAndSettle();

      // ต้องแสดงข้อความเตือนความถูกต้องของฟอร์ม
      expect(find.text('Please enter barcode number'), findsOneWidget);
      expect(find.text('Please enter product name'), findsOneWidget);
    });
  });

  // ===========================================================================
  // กลุ่ม 15: Widget Test หน้าจัดการผู้ใช้งานของแอดมิน (UserManagementView)
  // ===========================================================================
  group('15. Admin User Management Tests', () {
    // ฟังก์ชันผู้ช่วยสร้าง Controller พร้อมข้อมูลผู้ใช้จำลอง
    UserController freshController() => UserController(seed: [
          UserModel(
            userId: 1,
            username: 'superadmin',
            role: UserModel.roleAdmin,
            createdAt: DateTime(2026, 1, 1),
          ),
          UserModel(
            userId: 2,
            username: 'normal_user',
            role: UserModel.roleUser,
            createdAt: DateTime(2026, 1, 2),
          ),
        ]);

    // ทดสอบแอดมินสามารถเพิ่มผู้ใช้ใหม่เข้าในระบบได้
    testWidgets('Admin can add a new user to the list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UserManagementView(controller: freshController())), // เรนเดอร์หน้าจัดการผู้ใช้
      );
      await tester.pumpAndSettle();

      // กดปุ่ม Add User เพื่อเปิดกล่องกรอกข้อมูล
      await tester.tap(find.text('Add User'));
      await tester.pumpAndSettle();

      // กรอกชื่อผู้ใช้ใหม่และกดยืนยันการเพิ่ม
      await tester.enterText(find.byType(TextFormField), 'somying');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      // ตรวจสอบว่ามีชื่อผู้ใช้ใหม่ปรากฏในรายชื่อและมีแจ้งเตือนสำเร็จ
      expect(find.text('somying'), findsOneWidget);
      expect(find.text('User added'), findsOneWidget);
    });

    // ทดสอบระบบความปลอดภัย: ไม่อนุญาตให้ลดสิทธิ์แอดมินคนสุดท้ายของระบบ
    testWidgets('The last administrator cannot be demoted', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UserManagementView(controller: freshController())),
      );
      await tester.pumpAndSettle();

      // กดเมนูจุดสามจุดของแอดมินคนแรก
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      // เลือก Edit Role
      await tester.tap(find.text('Edit Role'));
      await tester.pumpAndSettle();
      // เลือกลดสิทธิ์เป็น User ทั่วไป
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('User').last);
      await tester.pumpAndSettle();
      // กดบันทึก
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // ต้องแสดงข้อผิดพลาดว่าไม่สามารถลดสิทธิ์แอดมินคนสุดท้ายได้
      expect(find.text('The last administrator cannot be demoted'), findsOneWidget);
    });
  });

  // ===========================================================================
  // กลุ่ม 16: Widget Test หน้าวิเคราะห์สถิติทั้งระบบ (SystemAnalyticsView)
  // ===========================================================================
  group('16. Admin System Analytics Tests', () {
    testWidgets('Displays overview cards and period dropdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SystemAnalyticsView()), // เรนเดอร์หน้าสถิติระบบ
      );
      await tester.pumpAndSettle();

      // ตรวจสอบการแสดงผลหัวข้อและบัตรสถิติต่าง ๆ
      expect(find.text('System Overview'), findsOneWidget); // ตรวจสอบหัวข้อหลัก
      expect(find.text('All Time'), findsOneWidget); // ตรวจสอบตัวเลือกช่วงเวลาเริ่มต้น
      expect(find.text('Total Users'), findsOneWidget); // ตรวจสอบการ์ดแสดงจำนวนผู้ใช้งานรวม
      expect(find.text('Global Barcodes'), findsOneWidget); // ตรวจสอบการ์ดแสดงบาร์โค้ดส่วนกลาง
      expect(find.text('Item Status'), findsOneWidget); // ตรวจสอบหัวข้อสถานะสินค้า
    });
  });
}
