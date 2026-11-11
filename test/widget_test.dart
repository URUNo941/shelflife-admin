import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:myapp/models/inventory_item_model.dart';
import 'package:myapp/utils/expiry_status.dart';
import 'package:myapp/views/user/login_view.dart';
import 'package:myapp/views/user/user_data.dart';
import 'package:myapp/views/user/inventory_list_view.dart';
import 'package:myapp/views/user/user_inventory_view.dart';
import 'package:myapp/views/user/user_item_form_view.dart';

void main() {
  group('1. InventoryItemModel Tests', () {
    test('fromJson should parse JSON from database correctly', () {
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

      expect(item.itemId, equals(1));
      expect(item.userId, equals(1));
      expect(item.productName, equals('Fresh Milk'));
      expect(item.category, equals('Food'));
      expect(item.quantity, equals(2));
      expect(item.expirationDate.year, equals(2026));
      expect(item.status, equals('active'));
    });

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

      expect(json['product_name'], equals('Paracetamol'));
      expect(
          json['expiration_date'].toString().startsWith('2026-11-10'), isTrue);
      expect(json['quantity'], equals(5));
    });
  });

  group('2. Expiry Color Logic', () {
    final start = DateTime(2026, 1, 1);
    final expiry = DateTime(2026, 1, 11);

    test('100% to 30% remaining is green', () {
      expect(
        ExpiryStatus.color(
            addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 8)),
        ExpiryStatus.green,
      );
    });

    test('30% to 10% remaining is yellow', () {
      expect(
        ExpiryStatus.color(
            addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 9)),
        ExpiryStatus.yellow,
      );
      expect(
        ExpiryStatus.color(
            addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 10)),
        ExpiryStatus.yellow,
      );
    });

    test('Less than 10% remaining and expired items are red', () {
      expect(
        ExpiryStatus.color(
            addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 11)),
        ExpiryStatus.red,
      );
      expect(
        ExpiryStatus.color(
            addedAt: start, expiryDate: expiry, today: DateTime(2026, 1, 12)),
        ExpiryStatus.red,
      );
    });

    test('Items added after their expiry date are red', () {
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

  group('3. HTTP API Mock Tests', () {
    test('Mock getInventoryItems returns a list of items on success (200 OK)',
        () async {
      // สร้าง MockClient เพื่อจำลองการตอบกลับของเซิร์ฟเวอร์
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

      // ทดสอบการยิง API และแปลงข้อมูล
      final response =
          await mockClient.get(Uri.parse('http://localhost:3000/api/items/1'));
      final List data = jsonDecode(response.body);
      final items =
          data.map((json) => InventoryItemModel.fromJson(json)).toList();

      expect(items, isA<List<InventoryItemModel>>());
      expect(items.length, 1);
      expect(items[0].productName, 'Fresh Milk');
    });

    test('Mock API throws exception on failure (500 Server Error)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final response =
          await mockClient.get(Uri.parse('http://localhost:3000/api/items/1'));
      expect(response.statusCode, 500);
    });
  });

  group('4. InventoryListView UI Tests', () {
    testWidgets('Displays AppBar and Loading Indicator initially',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InventoryListView(),
        ),
      );

      // ตรวจสอบว่ามีข้อความ AppBar ปรากฏบนหน้าจอ
      expect(find.text('ShelfLife - My Inventory'), findsOneWidget);

      // ตรวจสอบว่ามีวงกลมโหลดข้อมูล (เนื่องจาก FutureBuilder กำลังทำงาน)
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
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.teal);
    });
  });

  //--------------------------------------------------------------------------------------------------------------------------------------

  group('Login screen', () {
    Future<void> signIn(
      WidgetTester tester, {
      required String username,
      required String password,
    }) async {
      await tester.pumpWidget(const MaterialApp(home: LoginView()));
      await tester.enterText(find.byType(TextFormField).at(0), username);
      await tester.enterText(find.byType(TextFormField).at(1), password);
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
    }

    testWidgets('Valid user credentials open the user home', (tester) async {
      await signIn(tester, username: 'user', password: '1234');
      expect(find.text('My Shelf'), findsOneWidget);
    });

    testWidgets('Valid admin credentials open the admin dashboard',
        (tester) async {
      await signIn(tester, username: 'admin', password: '1234');
      expect(find.text('Admin Console'), findsOneWidget);
    });

    testWidgets('Invalid credentials show an error and stay on login',
        (tester) async {
      await signIn(tester, username: 'user', password: 'wrong');
      expect(find.text('Invalid username or password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('Blank credentials show required field validation',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginView()));
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your username'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });

  group('Inventory form screens', () {
    final inventory = UserInventory.instance;
    final testItemIds = <String>[];

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
      await tester.pumpAndSettle();
    }

    Future<void> fillNewItem(
      WidgetTester tester, {
      required String barcode,
      required String name,
    }) async {
      await tester.enterText(find.byType(TextFormField).at(0), barcode);
      await tester.enterText(find.byType(TextFormField).at(1), name);
    }

    setUp(() => testItemIds.clear());
    tearDown(() {
      for (final id in testItemIds) {
        inventory.remove(id);
      }
    });

    testWidgets('Add form validates required fields', (tester) async {
      await openForm(tester);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsNWidgets(2));
      expect(find.text('Add Item'), findsOneWidget);
    });

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

      final added = inventory.items
          .where((item) => item.barcode == 'form-add-001')
          .single;
      expect(added.name, 'Form Added Product');
      expect(added.qty, 1);
    });

    testWidgets('Adding an identical barcode and expiry asks before merging',
        (tester) async {
      final today = DateTime.now();
      final existing = createItem(
        id: 'form-merge-existing',
        barcode: 'form-merge-001',
        expiry: DateTime(today.year, today.month, today.day + 7),
        quantity: 2,
      );
      inventory.save(existing);
      await openForm(tester);
      await fillNewItem(
        tester,
        barcode: existing.barcode,
        name: 'Form test item',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Matching expiry batch'), findsOneWidget);
      await tester.tap(find.text('Add quantity'));
      await tester.pumpAndSettle();

      expect(existing.qty, 3);
      expect(
        inventory.items.where((item) => item.barcode == existing.barcode),
        hasLength(1),
      );
    });

    testWidgets('Edit form updates the selected batch', (tester) async {
      final existing = createItem(
        id: 'form-edit-001',
        barcode: 'form-edit-old',
        expiry: DateTime(2099, 12, 10),
        quantity: 2,
      );
      inventory.save(existing);
      await openForm(tester, item: existing);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'form-edit-new',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Updated Product Name',
      );
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      final updated =
          inventory.items.where((item) => item.id == existing.id).single;
      expect(updated.barcode, 'form-edit-new');
      expect(updated.name, 'Updated Product Name');
      expect(updated.qty, 3);
    });

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
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Item?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(inventory.items, isNot(contains(existing)));
    });
  });

  group('Inventory list screen', () {
    testWidgets('Groups batches and displays them expanded by default',
        (tester) async {
      final inventory = UserInventory.instance;
      const barcode = 'widget-list-batches-001';
      final today = DateTime.now();
      final soonExpiry = DateTime(today.year, today.month, today.day + 1);
      final laterExpiry = DateTime(today.year, today.month, today.day + 10);
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

      expect(find.text('List Test Product  ×3'), findsOneWidget);
      expect(find.textContaining('2 expiry batches'), findsOneWidget);
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
      expect(find.text('Use first'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('1 day left')).style?.color,
        ExpiryStatus.yellow,
      );

      final title = find.text('List Test Product  ×3');
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.textContaining('2 expiry batches'), findsOneWidget);
      expect(
        find.text(
          'Exp ${soonExpiry.day.toString().padLeft(2, '0')}/${soonExpiry.month.toString().padLeft(2, '0')}/${soonExpiry.year}',
        ),
        findsNothing,
      );
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Exp ${soonExpiry.day.toString().padLeft(2, '0')}/${soonExpiry.month.toString().padLeft(2, '0')}/${soonExpiry.year}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Use one confirms and decreases the selected batch quantity',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
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

      final batchRow = find.ancestor(
        of: find.text('2 in this batch'),
        matching: find.byType(ListTile),
      );
      final useButton = find.descendant(
        of: batchRow,
        matching: find.byIcon(Icons.remove_circle_outline),
      );
      await tester.ensureVisible(useButton);
      await tester.pumpAndSettle();
      await tester.tap(useButton);
      await tester.pumpAndSettle();
      expect(find.text('Use one item?'), findsOneWidget);
      await tester.tap(find.text('Use one'));
      await tester.pumpAndSettle();

      expect(item.qty, 1);
      expect(inventory.items, contains(item));
    });
  });
}
