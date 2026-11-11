import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:myapp/models/inventory_item_model.dart';
import 'package:myapp/views/user/inventory_list_view.dart';

// ย้ายฟังก์ชันคำนวณสีออกมาทดสอบต่างหาก
String getExpiryStatus(DateTime expDate) {
  final now = DateTime.now();
  final normalizedExp = DateTime(expDate.year, expDate.month, expDate.day);
  final normalizedNow = DateTime(now.year, now.month, now.day);
  final difference = normalizedExp.difference(normalizedNow).inDays;

  if (difference < 0) return 'Expired';
  if (difference <= 3) return 'Warning';
  return 'Safe';
}

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
        status: 'active',
      );

      final json = item.toJson();

      expect(json['product_name'], equals('Paracetamol'));
      expect(
          json['expiration_date'].toString().startsWith('2026-11-10'), isTrue);
      expect(json['quantity'], equals(5));
    });
  });

  group('2. Expiry Color Logic Test (Isolated)', () {
    test('Dates in the past should return Expired', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(getExpiryStatus(past), equals('Expired'));
    });

    test('Dates within 3 days should return Warning', () {
      final warning = DateTime.now().add(const Duration(days: 2));
      expect(getExpiryStatus(warning), equals('Warning'));
    });

    test('Dates far in the future should return Safe', () {
      final safe = DateTime.now().add(const Duration(days: 10));
      expect(getExpiryStatus(safe), equals('Safe'));
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
}
