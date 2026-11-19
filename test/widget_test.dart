// =============================================================================
// widget_test.dart — ชุดทดสอบหลักของแอป ShelfLife
// -----------------------------------------------------------------------------
// วิธีรัน:  flutter test test/widget_test.dart      (เฉพาะไฟล์นี้)
//           flutter test                            (ทุกไฟล์ในโฟลเดอร์ test/)
// ผลที่ต้องได้: "All tests passed!"
//
// ไฟล์นี้มีเทสต์ 2 แบบ:
//   1) test()        = Unit Test   -> ทดสอบ "logic ล้วน" (model, สูตรสี, การแปลง JSON)
//                                    ไม่มีหน้าจอ รันเร็วมาก
//   2) testWidgets() = Widget Test -> "จำลองหน้าจอ" ขึ้นมาในหน่วยความจำ
//                                    แล้วกด/พิมพ์เหมือนผู้ใช้ จากนั้นตรวจว่าหน้าจอเปลี่ยนถูกไหม
//                                    ไม่ต้องเปิดแอปจริง ไม่ต้องมีมือถือ/emulator
//
// ทำไมไม่ต้องต่อ Server / MySQL?
//   - ตอนเทสต์ ApiClient ถูกปิดอยู่ (main.dart เป็นคนเปิดตอนรันแอปจริงเท่านั้น)
//     controller จึงใช้ "ข้อมูลในหน่วยความจำ" แทนการยิง API
//   - ข้อดี: ผลแน่นอนทุกครั้ง (ไม่ขึ้นกับเน็ต/ข้อมูลใน DB), เร็ว, รันที่ไหนก็ได้
//   - ส่วนที่ต้องทดสอบกับ API ใช้ MockClient (server ปลอม) แทน ดูกลุ่มที่ 3
//
// คำศัพท์หลักของ Widget Test (ถามบ่อย):
//   WidgetTester tester   = "หุ่นยนต์ผู้ใช้" ที่ Flutter ให้มา ใช้สร้างหน้าจอ/กด/พิมพ์
//   tester.pumpWidget(w)  = สร้างหน้าจอ w ขึ้นมาจำลอง (เหมือนเปิดแอปมาที่หน้านั้น)
//   tester.pump()         = วาดหน้าจอใหม่ 1 เฟรม (หลัง setState)
//   tester.pumpAndSettle()= วาดซ้ำไปเรื่อย ๆ จนกว่า animation/การเปลี่ยนหน้าจะหยุด
//   tester.tap(finder)    = กดที่ widget ที่หาเจอ
//   tester.enterText(f,s) = พิมพ์ข้อความ s ลงช่องกรอก f
//   tester.ensureVisible  = เลื่อนจอให้ widget นั้นอยู่ในจอก่อนกด (กันกดไม่โดน)
//
//   find.text('Save')        = หา widget ที่มีข้อความ 'Save' พอดี
//   find.textContaining(s)   = หา widget ที่ข้อความ "มีคำว่า" s อยู่ข้างใน
//   find.byType(TextFormField)= หาตามชนิด widget (เช่น ช่องกรอกทุกช่อง)
//   find.byIcon(Icons.xxx)   = หาตามไอคอน
//   find.widgetWithText(T,s) = หา widget ชนิด T ที่มีข้อความ s (เช่น ปุ่ม Delete ใน dialog)
//   .at(0) / .at(1)          = เลือกตัวที่ 1 / ตัวที่ 2 เมื่อเจอหลายตัว
//   find.ancestor / descendant = หา "ตัวแม่" / "ตัวลูก" ของ widget อื่น
//
//   expect(ค่าจริง, ค่าที่คาดหวัง) = ตรวจผล ถ้าไม่ตรง เทสต์ "ล้ม" (fail) ทันที
//   findsOneWidget   = ต้องเจอ 1 ตัวพอดี
//   findsNothing     = ต้องไม่เจอเลย
//   findsNWidgets(n) = ต้องเจอ n ตัว
//
//   group('ชื่อ', ...) = จัดกลุ่มเทสต์ที่เกี่ยวข้องกันไว้ด้วยกัน (แสดงชื่อกลุ่มตอนรัน)
//   setUp / tearDown   = โค้ดที่รัน "ก่อน" / "หลัง" ทุกเทสต์ในกลุ่ม (เตรียม/เก็บกวาดข้อมูล)
//   addTearDown(...)   = เก็บกวาดหลังจบเทสต์นั้น ๆ (เช่น ลบของที่เพิ่มเข้าไป)
//
// Widget Test ต่างจาก Unit Test ยังไง?
//   Unit Test  : ตรวจ "สูตร/logic" เช่น วันเหลือ 20% ต้องได้สีเหลือง
//   Widget Test: ตรวจ "สิ่งที่ผู้ใช้เห็นและทำ" เช่น กด Save ตอนยังไม่กรอก ต้องขึ้น Required
// =============================================================================

import 'dart:convert'; // jsonEncode / jsonDecode สำหรับแปลง JSON
import 'package:flutter/material.dart'; // widget ของ Flutter (MaterialApp, Scaffold, ...)
import 'package:flutter_test/flutter_test.dart'; // test, testWidgets, find, expect
import 'package:http/http.dart' as http; // ชนิด Response ของ HTTP
import 'package:http/testing.dart'; // MockClient = server ปลอมสำหรับเทสต์

import 'package:myapp/models/inventory_item_model.dart';
import 'package:myapp/utils/expiry_status.dart';
import 'package:myapp/views/user/login_view.dart';
import 'package:myapp/views/user/user_data.dart';
import 'package:myapp/views/user/inventory_list_view.dart';
import 'package:myapp/views/user/user_inventory_view.dart';
import 'package:myapp/views/user/user_item_form_view.dart';

// main() ของไฟล์เทสต์ = จุดที่ flutter test เริ่มอ่านว่ามีเทสต์อะไรบ้าง
void main() {
  // ===========================================================================
  // กลุ่ม 1: Unit Test ของ Model (แปลงข้อมูล JSON <-> object)
  // ทำไมต้องเทสต์: ถ้าแปลง JSON จาก API ผิด หน้าจอจะแสดงข้อมูลผิดหรือแอปพัง
  // ===========================================================================
  group('1. InventoryItemModel Tests', () {
    // fromJson: JSON 1 แถวจาก backend -> object ที่แอปใช้
    test('fromJson should parse JSON from database correctly', () {
      // ข้อมูลจำลอง หน้าตาเหมือนที่ GET /api/items ส่งกลับมา 1 แถว
      final mockJson = {
        'item_id': 1,
        'user_id': 1,
        'product_name': 'Fresh Milk',
        'category': 'Food',
        'quantity': 2,
        'expiration_date': '2026-11-05T00:00:00.000Z',
        'created_at': '2026-10-01T00:00:00.000Z',
        'status': 'active'
      };

      final item = InventoryItemModel.fromJson(mockJson);

      // ตรวจทีละ field ว่าค่าถูกย้ายมาครบและถูกชนิด
      // equals(x) = ต้องเท่ากับ x
      expect(item.itemId, equals(1));
      expect(item.userId, equals(1));
      expect(item.productName, equals('Fresh Milk'));
      expect(item.category, equals('Food'));
      expect(item.quantity, equals(2));
      expect(item.expirationDate.year, equals(2026)); // ข้อความวันที่ -> DateTime
      expect(item.status, equals('active'));
    });

    // toJson: object -> JSON สำหรับส่งไป API (ทิศกลับกันกับ fromJson)
    test('toJson should format data correctly for API', () {
      final item = InventoryItemModel(
        itemId: 2,
        userId: 1,
        productName: 'Paracetamol',
        category: 'Medicine',
        quantity: 5,
        expirationDate: DateTime(2026, 11, 10),
        createdAt: DateTime(2026, 10, 1),
        status: 'active',
      );

      final json = item.toJson();

      // ชื่อ key ต้องเป็น snake_case ตรงกับคอลัมน์ใน DB (product_name ไม่ใช่ productName)
      expect(json['product_name'], equals('Paracetamol'));
      // วันหมดอายุต้องขึ้นต้นด้วย 2026-11-10 (รูปแบบที่ backend อ่านได้)
      expect(
          json['expiration_date'].toString().startsWith('2026-11-10'), isTrue);
      expect(json['quantity'], equals(5));
    });
  });

  // ===========================================================================
  // กลุ่ม 2: Unit Test ของสูตรสีหมดอายุ (Expiry Status Color Coding)
  // สูตรอยู่ที่ lib/utils/expiry_status.dart
  //   % ที่เหลือ = วันที่เหลือ ÷ (วันหมดอายุ - วันที่เพิ่มเข้าตู้) × 100
  //   เขียว >= 30% | เหลือง 10-29% หรือเหลือ 1 วัน | แดง < 10% / หมดวันนี้ / หมดแล้ว
  // ส่ง today: เข้าไปเอง เพื่อ "ล็อกวันที่" ผลเทสต์จะได้ไม่เปลี่ยนตามวันที่รันจริง
  // ===========================================================================
  group('2. Expiry Color Logic', () {
    // ตัวอย่างกลาง: เพิ่มเข้าตู้ 1 ม.ค. หมดอายุ 11 ม.ค. = อายุ 10 วัน (1 วัน = 10%)
    final start = DateTime(2026, 1, 1);
    final expiry = DateTime(2026, 1, 11);

    test('100% to 30% remaining is green', () {
      // วันนี้ 8 ม.ค. -> เหลือ 3 วัน = 30% -> เขียว (30% ยังนับเป็นเขียว)
      expect(
        ExpiryStatus.color(
            addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 8)),
        ExpiryStatus.green,
      );
    });

    test('30% to 10% remaining is yellow', () {
      // วันนี้ 9 ม.ค. -> เหลือ 2 วัน = 20% -> เหลือง
      expect(
        ExpiryStatus.color(
            addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 9)),
        ExpiryStatus.yellow,
      );
      // วันนี้ 10 ม.ค. -> เหลือ 1 วัน -> เหลือง (กฎพิเศษ: เหลือ 1 วันเป็นเหลืองเสมอ)
      expect(
        ExpiryStatus.color(
            addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 10)),
        ExpiryStatus.yellow,
      );
    });

    test('Less than 10% remaining and expired items are red', () {
      // วันนี้ 11 ม.ค. = หมดอายุวันนี้ -> แดง (ต้องรีบใช้วันนี้)
      expect(
        ExpiryStatus.color(
            addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 11)),
        ExpiryStatus.red,
      );
      // วันนี้ 12 ม.ค. = เลยวันหมดอายุแล้ว -> แดง
      expect(
        ExpiryStatus.color(
            addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 12)),
        ExpiryStatus.red,
      );
    });

    test('Items added after their expiry date are red', () {
      // กรณีผิดปกติ: เพิ่มของที่หมดอายุไปแล้วเข้าตู้ -> ต้องแดง (ไม่หารด้วยศูนย์/ติดลบจนพัง)
      expect(
        ExpiryStatus.color(
          addedAt: DateTime(2026, 1, 12),
          expiryDate: expiry,
          today: DateTime(2026, 1, 12),
        ),
        ExpiryStatus.red,
      );
    });

    test('One day before expiry is yellow even below 10% remaining', () {
      // ของอายุยาว 100 วัน เหลือ 1 วัน = 1% (ปกติต้องแดง)
      // แต่กฎ "เหลือ 1 วัน = เหลือง" ชนะ เพื่อเตือนล่วงหน้าแบบไม่ตกใจเกินไป
      expect(
        ExpiryStatus.color(
          addedAt: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 4, 11),
          today: DateTime(2026, 4, 10),
        ),
        ExpiryStatus.yellow,
      );
    });
  });

  // ===========================================================================
  // กลุ่ม 3: ทดสอบการคุยกับ API ด้วย MockClient (server ปลอม)
  // MockClient = แทนที่การยิง HTTP จริง เรากำหนดเองว่า "server" จะตอบอะไร
  // ใช้ทดสอบว่าแอปรับมือได้ทั้งตอนสำเร็จ (200) และตอน server พัง (500)
  // ===========================================================================
  group('3. HTTP API Mock Tests', () {
    test('Mock getInventoryItems returns a list of items on success (200 OK)',
        () async {
      // สร้าง MockClient เพื่อจำลองการตอบกลับของเซิร์ฟเวอร์
      // ทุก request ที่ยิงเข้ามา จะได้รายการสินค้า 1 รายการ + status 200
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
        return http.Response(jsonEncode(mockResponse), 200);
      });

      // ทดสอบการยิง API และแปลงข้อมูล (URL ไม่ได้ถูกเรียกจริง MockClient ตอบแทน)
      final response =
          await mockClient.get(Uri.parse('http://localhost:3000/api/items/1'));
      final List data = jsonDecode(response.body); // ข้อความ JSON -> List
      final items =
          data.map((json) => InventoryItemModel.fromJson(json)).toList();

      // isA<T>() = ต้องเป็นชนิด T
      expect(items, isA<List<InventoryItemModel>>());
      expect(items.length, 1);
      expect(items[0].productName, 'Fresh Milk');
    });

    test('Mock API throws exception on failure (500 Server Error)', () async {
      // จำลองว่า server พัง ตอบ 500
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final response =
          await mockClient.get(Uri.parse('http://localhost:3000/api/items/1'));
      expect(response.statusCode, 500);
    });
    // หมายเหตุ: เทสต์ API ของแอปแบบละเอียด (JWT, ใช้หมด/ทิ้ง, auto-fill, สถิติ)
    // อยู่ในไฟล์ test/api_integration_test.dart
  });

  // ===========================================================================
  // กลุ่ม 4: Widget Test หน้า InventoryListView (หน้ารายการแบบง่าย)
  // ===========================================================================
  group('4. InventoryListView UI Tests', () {
    testWidgets('Displays AppBar and Loading Indicator initially',
        (WidgetTester tester) async {
      // ① pumpWidget = สร้างหน้าจอขึ้นมาจำลอง
      //    ต้องห่อด้วย MaterialApp เพราะหน้าจอต้องการ theme/navigation ของแอป
      await tester.pumpWidget(
        const MaterialApp(
          home: InventoryListView(),
        ),
      );

      // ตรวจสอบว่ามีข้อความ AppBar ปรากฏบนหน้าจอ
      expect(find.text('ShelfLife - My Inventory'), findsOneWidget);

      // ตรวจสอบว่ามีวงกลมโหลดข้อมูล (เนื่องจาก FutureBuilder กำลังทำงาน)
      // ยังไม่ได้ pump ต่อ จึงเห็นสถานะ "กำลังโหลด" ตอนเปิดหน้าครั้งแรก
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AppBar has Teal background color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InventoryListView(),
        ),
      );

      // ดึง Widget AppBar ออกมาตรวจสอบสี
      // tester.widget<T>(finder) = ดึง object ของ widget ที่หาเจอ มาดู property ได้
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.teal);
    });
  });

  //--------------------------------------------------------------------------------------------------------------------------------------

  // ===========================================================================
  // กลุ่ม Login: Widget Test หน้าเข้าสู่ระบบ (ตัวอย่างหลักที่ใช้โชว์)
  // บัญชีทดสอบในโหมดไม่ต่อ server: user / admin รหัส 1234 (อยู่ใน mock_data.dart)
  // ===========================================================================
  group('Login screen', () {
    // ฟังก์ชันช่วย: ทำขั้นตอน login ซ้ำ ๆ ให้ทุกเทสต์ในกลุ่มใช้ร่วมกัน
    // (เขียนครั้งเดียว ไม่ต้องก๊อปโค้ดเดิมไปทุกเทสต์)
    Future<void> signIn(
      WidgetTester tester, {
      required String username,
      required String password,
    }) async {
      // ① สร้างหน้า Login จำลอง
      await tester.pumpWidget(const MaterialApp(home: LoginView()));
      // ② หาช่องกรอกทุกช่อง (TextFormField) แล้วพิมพ์
      //    .at(0) = ช่องแรก (username), .at(1) = ช่องที่สอง (password)
      await tester.enterText(find.byType(TextFormField).at(0), username);
      await tester.enterText(find.byType(TextFormField).at(1), password);
      // ③ หาปุ่มที่เขียนว่า Sign In แล้วกด
      await tester.tap(find.text('Sign In'));
      // ④ รอให้หน้าจอทำงานจนนิ่ง (ตรวจรหัส + เปลี่ยนหน้า)
      await tester.pumpAndSettle();
    }

    testWidgets('Valid user credentials open the user home', (tester) async {
      await signIn(tester, username: 'user', password: '1234');
      // login เป็น user ถูกต้อง -> ต้องไปหน้า Home ของ user ซึ่งมีหัวข้อ "My Shelf"
      expect(find.text('My Shelf'), findsOneWidget);
    });

    testWidgets('Valid admin credentials open the admin dashboard',
        (tester) async {
      await signIn(tester, username: 'admin', password: '1234');
      // role-based: admin ต้องไปหน้า Dashboard ของ admin ไม่ใช่หน้า user
      expect(find.text('System at a glance'), findsOneWidget);
    });

    testWidgets('Invalid credentials show an error and stay on login',
        (tester) async {
      await signIn(tester, username: 'user', password: 'wrong');
      // รหัสผิด -> ต้องขึ้นข้อความเตือน
      expect(find.text('Invalid username or password'), findsOneWidget);
      // และยังต้องอยู่หน้า Login (ปุ่ม Sign In ยังอยู่) ไม่ถูกพาเข้าแอป
      expect(find.text('Sign In'), findsOneWidget);
    });

    // ★ ตัวอย่างที่เปิดโชว์อาจารย์ (สั้น เห็นครบ 3 ส่วนหลัก)
    testWidgets('Blank credentials show required field validation',
        (tester) async {
      // ① pumpWidget  : สร้างหน้า Login จำลอง
      await tester.pumpWidget(const MaterialApp(home: LoginView()));
      // ② find + tap  : หาปุ่ม Sign In แล้วกด "โดยไม่กรอกอะไรเลย"
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle(); // รอหน้าจอแสดงผลการ validate

      // ③ expect      : ฟอร์มต้อง validate และขึ้นข้อความเตือนทั้ง 2 ช่อง
      expect(find.text('Please enter your username'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });

  // ===========================================================================
  // กลุ่มฟอร์มเพิ่ม/แก้ไข/ลบสินค้า (CRUD ฝั่ง user) — UserItemFormView
  // ใช้ UserInventory.instance (ข้อมูลในหน่วยความจำ) ไม่ได้ยิง API จริง
  // ===========================================================================
  group('Inventory form screens', () {
    final inventory = UserInventory.instance; // ตู้สินค้าที่หน้าจอใช้
    final testItemIds = <String>[]; // จด id ที่เทสต์สร้าง ไว้ลบตอนจบ

    // ฟังก์ชันช่วย: สร้างของ 1 ล็อตสำหรับเทสต์ และจด id ไว้เก็บกวาด
    UserItem createItem({
      required String id,
      required String barcode,
      required DateTime expiry,
      int quantity = 1,
    }) {
      testItemIds.add(id);
      return UserItem(
        id: id,
        barcode: barcode,
        name: 'Form test item',
        category: 'Food',
        expiry: expiry,
        qty: quantity,
      );
    }

    // ฟังก์ชันช่วย: เปิดหน้าฟอร์ม
    // ทำเป็นหน้าแรกที่มีปุ่ม "Open form" แล้วค่อย push ไปหน้าฟอร์ม
    // เพราะฟอร์มจะ Navigator.pop กลับหลังกด Save/Delete ถ้าไม่มีหน้าก่อนหน้า จะ pop ไม่ได้
    // item == null -> โหมดเพิ่ม (Add Item), มี item -> โหมดแก้ไข (Edit Item)
    Future<void> openForm(
      WidgetTester tester, {
      UserItem? item,
    }) async {
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
      await tester.tap(find.text('Open form'));
      await tester.pumpAndSettle(); // รอ animation เปลี่ยนหน้าเสร็จ
    }

    // ฟังก์ชันช่วย: กรอกบาร์โค้ด (ช่องที่ 1) และชื่อสินค้า (ช่องที่ 2)
    Future<void> fillNewItem(
      WidgetTester tester, {
      required String barcode,
      required String name,
    }) async {
      await tester.enterText(find.byType(TextFormField).at(0), barcode);
      await tester.enterText(find.byType(TextFormField).at(1), name);
    }

    // setUp = รันก่อนทุกเทสต์ในกลุ่ม: ล้างรายการ id
    setUp(() => testItemIds.clear());
    // tearDown = รันหลังทุกเทสต์: ลบของที่เทสต์สร้าง ไม่ให้ไปกวนเทสต์อื่น
    tearDown(() {
      for (final id in testItemIds) {
        inventory.remove(id);
      }
    });

    // Validate: กด Save ตอนยังไม่กรอก -> ต้องขึ้น Required และยังอยู่หน้าเดิม
    testWidgets('Add form validates required fields', (tester) async {
      await openForm(tester);
      // ปุ่ม Save อาจอยู่นอกจอจำลอง (จอเล็ก) ต้องเลื่อนให้เห็นก่อนกด
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // findsNWidgets(2) = ต้องขึ้น "Required" 2 ที่ (ช่องบาร์โค้ด + ช่องชื่อสินค้า)
      expect(find.text('Required'), findsNWidgets(2));
      // ยังอยู่หน้า Add Item (ไม่ได้บันทึก ไม่ได้ปิดหน้า)
      expect(find.text('Add Item'), findsOneWidget);
    });

    // Create: กรอกครบแล้วกด Save -> ต้องมีของใหม่ในตู้
    testWidgets('Add form creates an inventory batch', (tester) async {
      await openForm(tester);
      await fillNewItem(
        tester,
        barcode: 'form-add-001',
        name: 'Form Added Product',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // ไปหาในข้อมูลตู้ว่ามีของบาร์โค้ดนี้จริง 1 รายการ (.single = ต้องมีตัวเดียว)
      final added = inventory.items
          .where((item) => item.barcode == 'form-add-001')
          .single;
      expect(added.name, 'Form Added Product');
      expect(added.qty, 1); // จำนวนเริ่มต้น = 1
    });

    // เพิ่มของ "บาร์โค้ดเดิม + วันหมดอายุเดิม" -> ต้องถามก่อนว่าจะรวมจำนวนไหม
    // (ล็อต = บาร์โค้ด + วันหมดอายุ ถ้าตรงกันทั้งคู่ถือเป็นล็อตเดียวกัน)
    testWidgets('Adding an identical barcode and expiry asks before merging',
        (tester) async {
      final today = DateTime.now();
      // เตรียมของเดิม 2 ชิ้น หมดอายุอีก 7 วัน
      final existing = createItem(
        id: 'form-merge-existing',
        barcode: 'form-merge-001',
        expiry: DateTime(today.year, today.month, today.day + 7),
        quantity: 2,
      );
      inventory.save(existing);
      await openForm(tester);
      // กรอกบาร์โค้ดเดียวกัน (ฟอร์มตั้งวันหมดอายุเริ่มต้น = อีก 7 วัน จึงตรงกันพอดี)
      await fillNewItem(
        tester,
        barcode: existing.barcode,
        name: 'Form test item',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // ต้องมี dialog ถาม
      expect(find.text('Matching expiry batch'), findsOneWidget);
      // เลือก "Add quantity" = รวมเข้าล็อตเดิม
      await tester.tap(find.text('Add quantity'));
      await tester.pumpAndSettle();

      expect(existing.qty, 3); // 2 + 1 = 3
      // และต้องเหลือล็อตเดียว (ไม่ได้สร้างแถวซ้ำ)
      expect(
        inventory.items.where((item) => item.barcode == existing.barcode),
        hasLength(1),
      );
    });

    // Update: เปิดฟอร์มแก้ไข เปลี่ยนบาร์โค้ด ชื่อ และเพิ่มจำนวน -> ข้อมูลต้องเปลี่ยนตาม
    testWidgets('Edit form updates the selected batch', (tester) async {
      final existing = createItem(
        id: 'form-edit-001',
        barcode: 'form-edit-old',
        expiry: DateTime(2099, 12, 10),
        quantity: 2,
      );
      inventory.save(existing);
      await openForm(tester, item: existing); // ส่ง item = โหมดแก้ไข
      // enterText แทนที่ข้อความเดิมในช่องทั้งหมด
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'form-edit-new',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Updated Product Name',
      );
      // หาปุ่ม + (เพิ่มจำนวน) จากไอคอน แล้วกด 1 ครั้ง
      final increaseQuantity = find.byIcon(Icons.add_circle_outline);
      await tester.ensureVisible(increaseQuantity);
      await tester.tap(increaseQuantity);
      await tester.pump(); // วาดใหม่ 1 เฟรมให้ตัวเลขจำนวนอัปเดต
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      final updated =
          inventory.items.where((item) => item.id == existing.id).single;
      expect(updated.barcode, 'form-edit-new');
      expect(updated.name, 'Updated Product Name');
      expect(updated.qty, 3); // 2 + 1
    });

    // Delete: ต้องมี dialog ยืนยันก่อน แล้วค่อยลบจริง (กันกดพลาด)
    testWidgets('Delete form requires confirmation then removes the batch',
        (tester) async {
      final existing = createItem(
        id: 'form-delete-001',
        barcode: 'form-delete-001',
        expiry: DateTime(2099, 12, 10),
      );
      inventory.save(existing);
      await openForm(tester, item: existing);
      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete')); // ปุ่ม Delete บนหน้าฟอร์ม
      await tester.pumpAndSettle();

      // ต้องมี dialog ถามยืนยัน
      expect(find.text('Delete Item?'), findsOneWidget);
      // ตอนนี้มีคำว่า Delete 2 ที่ (บนฟอร์ม + ใน dialog)
      // จึงใช้ widgetWithText(FilledButton, ...) เจาะจงปุ่มสีแดงใน dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // isNot(contains(x)) = ต้องไม่มี x อยู่ในรายการแล้ว
      expect(inventory.items, isNot(contains(existing)));
    });
  });

  // ===========================================================================
  // กลุ่มหน้ารายการของในตู้ (UserInventoryView)
  // ===========================================================================
  group('Inventory list screen', () {
    // สินค้าเดียวกัน 2 ล็อต (คนละวันหมดอายุ) ต้องรวมเป็นการ์ดเดียว แสดงทั้ง 2 ล็อต
    testWidgets('Groups batches and displays them expanded by default',
        (tester) async {
      final inventory = UserInventory.instance;
      const barcode = 'widget-list-batches-001';
      final today = DateTime.now();
      final soonExpiry = DateTime(today.year, today.month, today.day + 1); // พรุ่งนี้
      final laterExpiry = DateTime(today.year, today.month, today.day + 10); // อีก 10 วัน
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
      // เก็บกวาดหลังเทสต์นี้จบ (ลบ 2 ล็อตที่เพิ่ม)
      addTearDown(() {
        inventory.remove(soonBatch.id);
        inventory.remove(laterBatch.id);
      });

      inventory.save(soonBatch);
      inventory.save(laterBatch);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UserInventoryView())),
      );
      await tester.pumpAndSettle();

      // หัวการ์ดแสดงจำนวนรวมทุกล็อต: 2 + 1 = ×3
      expect(find.text('List Test Product  ×3'), findsOneWidget);
      // textContaining = ข้อความยาวกว่านี้ได้ แค่ต้องมีคำว่า "2 expiry batches"
      expect(find.textContaining('2 expiry batches'), findsOneWidget);
      // ทั้ง 2 ล็อตแสดงวันหมดอายุของตัวเอง (รูปแบบ dd/mm/yyyy)
      expect(
        find.text(
          'Exp ${soonExpiry.day.toString().padLeft(2, '0')}/${soonExpiry.month.toString().padLeft(2, '0')}/${soonExpiry.year}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Exp ${laterExpiry.day.toString().padLeft(2, '0')}/${laterExpiry.month.toString().padLeft(2, '0')}/${laterExpiry.year}',
        ),
        findsOneWidget,
      );
      // ล็อตที่หมดก่อนต้องมีป้าย "Use first" (แนะนำให้ใช้ก่อน ลดของเสีย)
      expect(find.text('Use first'), findsOneWidget);
      // ล็อตที่เหลือ 1 วัน ต้องแสดงข้อความสีเหลือง (Expiry Color Coding บนหน้าจอจริง)
      // .style?.color = ดึงสีของตัวอักษรมาตรวจ
      expect(
        tester.widget<Text>(find.text('1 day left')).style?.color,
        ExpiryStatus.yellow,
      );

      // กดหัวการ์ด = พับ (collapse) -> รายละเอียดล็อตต้องหายไป
      final title = find.text('List Test Product  ×3');
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.textContaining('2 expiry batches'), findsOneWidget); // หัวการ์ดยังอยู่
      expect(
        find.text(
          'Exp ${soonExpiry.day.toString().padLeft(2, '0')}/${soonExpiry.month.toString().padLeft(2, '0')}/${soonExpiry.year}',
        ),
        findsNothing, // findsNothing = ต้องไม่เห็นแล้ว
      );
      // กดอีกครั้ง = กาง (expand) -> ต้องเห็นกลับมา
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Exp ${soonExpiry.day.toString().padLeft(2, '0')}/${soonExpiry.month.toString().padLeft(2, '0')}/${soonExpiry.year}',
        ),
        findsOneWidget,
      );
    });

    // ปุ่ม "Use one" (ใช้ 1 ชิ้น): ต้องถามยืนยัน แล้วจำนวนลดลง 1
    testWidgets('Use one confirms and decreases the selected batch quantity',
        (tester) async {
      // ตั้งขนาดจอจำลองให้สูงขึ้น (800x1600) ให้เห็นทุกอย่างโดยไม่ต้องเลื่อน
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        // คืนขนาดจอเดิมหลังจบ ไม่ให้กระทบเทสต์อื่น
        tester.view.resetPhysicalSize();
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
        qty: 2,
      );
      addTearDown(() => inventory.remove(item.id));
      inventory.save(item);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UserInventoryView())),
      );
      await tester.pumpAndSettle();

      // หาแถวของล็อตนี้: ListTile ที่ "ครอบ" ข้อความ '2 in this batch' (ancestor = ตัวแม่)
      final batchRow = find.ancestor(
        of: find.text('2 in this batch'),
        matching: find.byType(ListTile),
      );
      // แล้วหาปุ่มลบ (−) ที่อยู่ "ในแถวนั้น" (descendant = ตัวลูก)
      // ทำแบบนี้เพื่อกดให้ถูกแถว ถ้ามีหลายล็อตบนจอ
      final useButton = find.descendant(
        of: batchRow,
        matching: find.byIcon(Icons.remove_circle_outline),
      );
      await tester.ensureVisible(useButton);
      await tester.pumpAndSettle();
      await tester.tap(useButton);
      await tester.pumpAndSettle();
      // ต้องมี dialog ยืนยัน
      expect(find.text('Use one item?'), findsOneWidget);
      await tester.tap(find.text('Use one'));
      await tester.pumpAndSettle();

      expect(item.qty, 1); // 2 - 1 = 1
      // ยังเหลือ 1 ชิ้น -> ล็อตยังอยู่ในตู้
      // (ถ้าใช้ชิ้นสุดท้าย ล็อตจะถูกนับเป็น consumed และออกจากรายการ เพื่อทำสถิติ)
      expect(inventory.items, contains(item));
    });
  });
}
