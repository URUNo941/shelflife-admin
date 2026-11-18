// Unit tests ของชั้นที่คุยกับ backend (ApiClient + controllers ในโหมด API)
// ใช้ MockClient แทน server จริง: ตรวจว่าแอปยิง endpoint / method / body / JWT ถูก
// และแปลง JSON ที่ backend ส่งกลับมาเป็น model ได้ถูกต้อง
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/controllers/auth_controller.dart';
import 'package:myapp/controllers/product_controller.dart';
import 'package:myapp/controllers/stats_controller.dart';
import 'package:myapp/controllers/user_controller.dart';
import 'package:myapp/controllers/user_inventory_controller.dart';
import 'package:myapp/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// server จำลอง: บันทึกทุก request ไว้ตรวจ แล้วตอบตาม handler
class FakeServer {
  final requests = <http.Request>[];
  final Future<http.Response> Function(http.Request) handler;
  FakeServer(this.handler);

  ApiClient client() => ApiClient(
        baseUrl: 'http://test/api',
        client: MockClient((request) {
          requests.add(request);
          return handler(request);
        }),
      )..enable();
}

http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> itemRow({
  int id = 7,
  int qty = 2,
  String status = 'active',
  String expiry = '2099-01-10',
  String? imageUrl,
}) =>
    {
      'item_id': id,
      'user_id': 2,
      'product_id': 1,
      'barcode': '8850123456789',
      'product_name': 'Fresh Milk 1L',
      'category': 'Food',
      'quantity': qty,
      'expiration_date': expiry,
      'image_url': imageUrl,
      'status': status,
      'status_updated_at': null,
      'created_at': '2099-01-01T03:00:00.000Z',
      'updated_at': '2099-01-01T03:00:00.000Z',
    };

void main() {
  final inventory = UserInventory.instance;

  tearDown(() {
    ApiClient.instance = ApiClient(); // กลับเป็นโหมด in-memory ให้ test อื่น
    inventory.clear();
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiClient', () {
    test('sends JSON with the bearer token and decodes the reply', () async {
      final server = FakeServer((_) async => json({'ok': true}));
      final api = server.client()..token = 'abc.def.ghi';
      final data = await api.post('/items', {'product_name': 'Milk'});
      final sent = server.requests.single;
      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'http://test/api/items');
      expect(sent.headers['Authorization'], 'Bearer abc.def.ghi');
      expect(jsonDecode(sent.body), {'product_name': 'Milk'});
      expect(data, {'ok': true});
    });

    test('turns error replies into ApiException with the server message',
        () async {
      final server = FakeServer(
          (_) async => json({'message': 'Authentication required.'}, 401));
      await expectLater(
        server.client().get('/items'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 401)
            .having((e) => e.message, 'message', 'Authentication required.')),
      );
    });

    test('dates from the API are read as local calendar dates', () {
      final d = parseApiDate('2026-11-05');
      expect([d.year, d.month, d.day], [2026, 11, 5]);
      expect(formatApiDate(DateTime(2026, 1, 9)), '2026-01-09');
    });
  });

  group('AuthController (API mode)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('signIn stores the JWT and the user returned by the backend',
        () async {
      final server = FakeServer((r) async => json({
            'token': 'jwt-token',
            'user': {
              'user_id': 2,
              'username': 'sarah',
              'email': null,
              'role': 'user',
              'created_at': '2026-11-03T06:27:43.000Z'
            },
          }));
      ApiClient.instance = server.client();
      final auth = AuthController(users: UserController(seed: const []));
      expect(await auth.signIn('sarah', 'secret1'), isNull);
      expect(ApiClient.instance.token, 'jwt-token');
      expect(auth.currentUser!.username, 'sarah');
      expect(auth.currentUser!.isAdmin, isFalse);
      expect(jsonDecode(server.requests.single.body),
          {'username': 'sarah', 'password': 'secret1'});
    });

    test('remembered session is restored and validated against the API',
        () async {
      final loginServer = FakeServer((_) async => json({
            'token': 'remembered-jwt',
            'user': {
              'user_id': 2,
              'username': 'sarah',
              'email': null,
              'role': 'user',
              'created_at': '2026-11-03T06:27:43.000Z',
            },
          }));
      ApiClient.instance = loginServer.client();
      final loginAuth = AuthController(users: UserController(seed: const []));
      expect(await loginAuth.signIn('sarah', 'secret1'), isNull);

      final restoreServer = FakeServer((_) async => json({
            'user_id': 2,
            'username': 'sarah',
            'email': null,
            'role': 'user',
            'created_at': '2026-11-03T06:27:43.000Z',
          }));
      ApiClient.instance = restoreServer.client();
      final restoredAuth =
          AuthController(users: UserController(seed: const []));

      expect(await restoredAuth.restoreSession(), isNull);
      expect(restoreServer.requests.single.url.path, '/api/auth/me');
      expect(
        restoreServer.requests.single.headers['Authorization'],
        startsWith('Bearer '),
      );
      expect(ApiClient.instance.token, 'remembered-jwt');
      expect(restoredAuth.currentUser?.username, 'sarah');
    });

    test('signIn does not persist the token when Remember me is unchecked',
        () async {
      ApiClient.instance = FakeServer((_) async => json({
            'token': 'temporary-jwt',
            'user': {
              'user_id': 2,
              'username': 'sarah',
              'email': null,
              'role': 'user',
              'created_at': '2026-11-03T06:27:43.000Z',
            },
          })).client();
      final auth = AuthController(users: UserController(seed: const []));

      expect(
        await auth.signIn('sarah', 'secret1', rememberMe: false),
        isNull,
      );
      expect(
        (await SharedPreferences.getInstance())
            .getString('shelflife.session_token'),
        isNull,
      );
    });

    test('wrong password shows the login error and keeps no token', () async {
      ApiClient.instance = FakeServer((_) async =>
          json({'message': 'Invalid username or password.'}, 401)).client();
      final auth = AuthController(users: UserController(seed: const []));
      expect(
          await auth.signIn('sarah', 'nope'), 'Invalid username or password');
      expect(ApiClient.instance.token, isNull);
      expect(auth.isLoggedIn, isFalse);
    });

    test('signUp validates locally, then posts to /auth/register', () async {
      final server =
          FakeServer((_) async => json({'token': 't', 'user': {}}, 201));
      ApiClient.instance = server.client();
      final auth = AuthController(users: UserController(seed: const []));
      expect(
          await auth.signUp(
              username: 'ab', email: 'a@b.co', password: 'secret1'),
          'At least 3 characters');
      expect(server.requests, isEmpty);
      expect(
          await auth.signUp(
              username: 'mint', email: 'mint@x.co', password: 'secret1'),
          isNull);
      expect(server.requests.single.url.path, '/api/auth/register');
    });

    test('logout forgets the token and the previous user\'s items', () async {
      SharedPreferences.setMockInitialValues({
        'shelflife.session_token': 'jwt',
      });
      ApiClient.instance = FakeServer((_) async => json([])).client()
        ..token = 'jwt';
      inventory.items.add(UserInventory.itemFromJson(itemRow()));
      await AuthController.instance.logout();
      expect(ApiClient.instance.token, isNull);
      expect(
        (await SharedPreferences.getInstance())
            .getString('shelflife.session_token'),
        isNull,
      );
      expect(inventory.items, isEmpty);
    });
  });

  group('UserInventory (API mode)', () {
    test('load maps API rows to items', () async {
      ApiClient.instance = FakeServer((_) async => json([
            itemRow(imageUrl: 'http://localhost:3000/uploads/milk.jpg'),
          ])).client();
      expect(await inventory.load(), isNull);
      final item = inventory.items.single;
      expect(item.id, '7');
      expect(item.name, 'Fresh Milk 1L');
      expect(item.qty, 2);
      expect(item.imageUrl, 'http://localhost:3000/uploads/milk.jpg');
      expect([item.expiry.year, item.expiry.month, item.expiry.day],
          [2099, 1, 10]);
    });

    test('use one on a multi-item batch lowers the quantity on the server',
        () async {
      final server = FakeServer((r) async => json(itemRow(qty: 1)));
      ApiClient.instance = server.client();
      inventory.items.add(UserInventory.itemFromJson(itemRow(qty: 2)));
      expect(await inventory.useOne(inventory.items.single), isNull);
      expect(server.requests.single.method, 'PUT');
      expect(server.requests.single.url.path, '/api/items/7');
      expect(jsonDecode(server.requests.single.body), {'quantity': 1});
      expect(inventory.items.single.qty, 1);
    });

    test('using the last one marks the batch consumed (kept for statistics)',
        () async {
      final server =
          FakeServer((r) async => json(itemRow(qty: 1, status: 'consumed')));
      ApiClient.instance = server.client();
      inventory.items.add(UserInventory.itemFromJson(itemRow(qty: 1)));
      await inventory.useOne(inventory.items.single);
      expect(jsonDecode(server.requests.single.body), {'status': 'consumed'});
      expect(inventory.items, isEmpty);
    });

    test('discard sends status discarded; delete sends DELETE', () async {
      final server = FakeServer((r) async => r.method == 'DELETE'
          ? http.Response('', 204)
          : json(itemRow(status: 'discarded')));
      ApiClient.instance = server.client();
      inventory.items
        ..add(UserInventory.itemFromJson(itemRow(id: 7)))
        ..add(UserInventory.itemFromJson(itemRow(id: 8)));
      await inventory.discard(inventory.items.first);
      await inventory.deleteItem('8');
      expect(server.requests.map((r) => '${r.method} ${r.url.path}'),
          ['PUT /api/items/7', 'DELETE /api/items/8']);
      expect(jsonDecode(server.requests.first.body), {'status': 'discarded'});
      expect(inventory.items, isEmpty);
    });

    test('saving a new item posts product data and expiry as YYYY-MM-DD',
        () async {
      final server = FakeServer((r) async => json(itemRow(id: 9), 201));
      ApiClient.instance = server.client();
      final draft = UserInventory.itemFromJson(itemRow(id: 0))
        ..qty = 3
        ..imageUrl = 'http://localhost:3000/uploads/milk.jpg';
      expect(await inventory.saveItem(draft), isNull);
      final body = jsonDecode(server.requests.single.body) as Map;
      expect(body['barcode'], '8850123456789');
      expect(body['quantity'], 3);
      expect(body['expiration_date'], '2099-01-10');
      expect(body['image_url'], 'http://localhost:3000/uploads/milk.jpg');
      expect(inventory.items.single.id, '9');
    });

    test('server errors are returned for the screen to show', () async {
      ApiClient.instance = FakeServer(
              (_) async => json({'message': 'Inventory item not found.'}, 404))
          .client();
      inventory.items.add(UserInventory.itemFromJson(itemRow()));
      expect(await inventory.discard(inventory.items.single),
          'Inventory item not found.');
      expect(inventory.items, hasLength(1)); // ไม่ลบออกถ้า server ไม่ยืนยัน
    });
  });

  group('Smart Barcode Auto-Fill', () {
    test('lookup asks the catalog endpoint and returns name + category',
        () async {
      final server = FakeServer((_) async => json({
            'product_id': 2,
            'barcode': '8850111222333',
            'product_name': 'Paracetamol 500mg (10s)',
            'category': 'Medicine',
            'created_at': '2026-11-03T06:27:43.000Z',
          }));
      ApiClient.instance = server.client();
      final product =
          await ProductController(seed: const []).lookup('8850111222333');
      expect(server.requests.single.url.path,
          '/api/products/master/8850111222333');
      expect(product!.productName, 'Paracetamol 500mg (10s)');
      expect(product.category, 'Medicine');
    });

    test('unknown barcode returns null so the user can type it in', () async {
      ApiClient.instance =
          FakeServer((_) async => json({'message': 'Product not found.'}, 404))
              .client();
      expect(await ProductController(seed: const []).lookup('000'), isNull);
    });
  });

  group('Consumed vs Discarded statistics', () {
    test('loadMine parses the stats endpoint', () async {
      final server = FakeServer((_) async => json({
            'period': 'month',
            'active': {'batches': 3, 'quantity': 5},
            'consumed': {'batches': 6, 'quantity': 9},
            'discarded': {'batches': 2, 'quantity': 2},
            'expired': {'batches': 1, 'quantity': 1},
            'waste_rate': 25,
            'top_discarded_categories': [
              {'category': 'Food', 'batches': 2}
            ],
          }));
      ApiClient.instance = server.client();
      await StatsController.instance.loadMine(period: 'month');
      final s = StatsController.instance.mine;
      expect(server.requests.single.url.toString(),
          'http://test/api/stats/me?period=month');
      expect(s.consumed.batches, 6);
      expect(s.discarded.batches, 2);
      expect(s.wasteRate, 25);
      expect(s.topDiscardedCategories.single.key, 'Food');
    });

    test('offline mode counts consumed and discarded batches locally',
        () async {
      inventory.items
        ..add(UserInventory.itemFromJson(itemRow(id: 1, qty: 1)))
        ..add(UserInventory.itemFromJson(itemRow(id: 2)))
        ..add(UserInventory.itemFromJson(itemRow(id: 3)));
      await inventory.useOne(inventory.items.first); // last one -> consumed
      await inventory.discard(inventory.items.first);
      await StatsController.instance.loadMine();
      final s = StatsController.instance.mine;
      expect(s.consumed.batches, 1);
      expect(s.discarded.batches, 1);
      expect(s.active.batches, 1);
      expect(s.wasteRate, 50);
    });
  });
}
