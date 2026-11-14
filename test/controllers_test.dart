import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/controllers/auth_controller.dart';
import 'package:myapp/controllers/product_controller.dart';
import 'package:myapp/controllers/user_controller.dart';
import 'package:myapp/controllers/user_inventory_controller.dart';
import 'package:myapp/models/user_item.dart';
import 'package:myapp/models/user_model.dart';

void main() {
  group('UserController', () {
    late UserController users;
    setUp(() => users = UserController());

    test('add inserts a new user at the top with the next id', () {
      final before = users.users.length;
      final maxId = users.users.map((u) => u.userId).reduce((a, b) => a > b ? a : b);

      expect(users.add(username: '  newbie ', role: 'User'), isNull);
      expect(users.users.length, before + 1);
      expect(users.users.first.username, 'newbie');
      expect(users.users.first.userId, maxId + 1);
      expect(users.users.first.isAdmin, isFalse);
    });

    test('add rejects blank and duplicate usernames (case-insensitive)', () {
      expect(users.add(username: '   '), 'Enter a username');
      expect(users.add(username: 'ADMIN'), 'Username already exists');
    });

    test('changeRole promotes and demotes users', () {
      final sarah = users.findByUsername('sarah')!;
      expect(users.changeRole(sarah.userId, 'Admin'), isNull);
      expect(users.findByUsername('sarah')!.isAdmin, isTrue);
      expect(users.changeRole(sarah.userId, 'User'), isNull);
      expect(users.findByUsername('sarah')!.isAdmin, isFalse);
    });

    test('the last administrator cannot be demoted or deleted', () {
      final admin = users.findByUsername('admin')!;
      expect(users.adminCount, 1);
      expect(users.changeRole(admin.userId, 'User'),
          'The last administrator cannot be demoted');
      expect(users.delete(admin.userId),
          'The last administrator cannot be deleted');
      expect(users.findByUsername('admin'), isNotNull);
    });

    test('delete removes a regular user and reports unknown ids', () {
      final john = users.findByUsername('john')!;
      expect(users.delete(john.userId), isNull);
      expect(users.exists('john'), isFalse);
      expect(users.delete(9999), 'User not found');
    });

    test('search filters by text and by role', () {
      expect(users.search(query: 'sar').map((u) => u.username), ['sarah']);
      expect(users.search(role: 'Admin').every((u) => u.isAdmin), isTrue);
      expect(users.search(query: 'zzz'), isEmpty);
    });

    test('notifies listeners on change and reset restores seed data', () {
      var calls = 0;
      users.addListener(() => calls++);
      users.add(username: 'temp');
      expect(calls, 1);
      users.reset();
      expect(calls, 2);
      expect(users.exists('temp'), isFalse);
    });
  });

  group('ProductController', () {
    late ProductController products;
    setUp(() => products = ProductController());

    test('add validates barcode and name', () {
      expect(products.add(barcode: '', productName: 'X'),
          'Please enter barcode number');
      expect(products.add(barcode: '12ab', productName: 'X'),
          'Barcode must contain numbers only');
      expect(products.add(barcode: '8850123456789', productName: 'X'),
          'This barcode already exists');
      expect(products.add(barcode: '111', productName: '  '),
          'Please enter product name');
    });

    test('add, findByBarcode, update and delete a product', () {
      expect(
        products.add(
            barcode: ' 1234567890 ', productName: 'Rice', category: 'Food'),
        isNull,
      );
      final rice = products.findByBarcode('1234567890')!;
      expect(rice.productName, 'Rice');

      expect(
        products.update(rice.productId,
            barcode: '1234567890', productName: 'Jasmine Rice', category: 'Food'),
        isNull,
      );
      expect(products.findByBarcode('1234567890')!.productName, 'Jasmine Rice');

      expect(products.delete(rice.productId), isTrue);
      expect(products.findByBarcode('1234567890'), isNull);
      expect(products.delete(rice.productId), isFalse);
    });

    test('update keeps its own barcode but rejects another product barcode', () {
      final milk = products.findByBarcode('8850123456789')!;
      expect(
        products.update(milk.productId,
            barcode: milk.barcode, productName: 'Milk', category: 'Food'),
        isNull,
      );
      expect(
        products.update(milk.productId,
            barcode: '8850987654321', productName: 'Milk', category: 'Food'),
        'This barcode already exists',
      );
      expect(
        products.update(9999,
            barcode: '1', productName: 'Milk', category: 'Food'),
        'Product not found',
      );
    });

    test('search filters by query and category and sorts', () {
      expect(
        products.search(query: 'milk').map((p) => p.productName),
        ['Fresh Milk'],
      );
      expect(
        products.search(category: 'Medicine').every((p) => p.category == 'Medicine'),
        isTrue,
      );
      final byName =
          products.search(sortBy: 'Name').map((p) => p.productName).toList();
      expect(byName, [...byName]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
    });

    test('categories and counts reflect the catalog', () {
      expect(products.categories, containsAll(['Food', 'Medicine']));
      expect(products.countInCategory('All'), products.products.length);
      expect(
        products.countInCategory('Food'),
        products.products.where((p) => p.category == 'Food').length,
      );
    });
  });

  group('AuthController', () {
    late UserController users;
    late AuthController auth;
    setUp(() {
      users = UserController();
      auth = AuthController(users: users);
    });

    test('demo accounts log in with the right role', () {
      final admin = auth.login('admin', '1234');
      expect(admin?.isAdmin, isTrue);
      expect(auth.currentUser, same(admin));

      final user = auth.login('USER', '1234');
      expect(user?.role, UserModel.roleUser);
    });

    test('wrong password or unknown user fails and keeps logged out', () {
      expect(auth.login('user', 'wrong'), isNull);
      expect(auth.login('nobody', '1234'), isNull);
      expect(auth.isLoggedIn, isFalse);
    });

    test('logout clears the current user', () {
      auth.login('user', '1234');
      auth.logout();
      expect(auth.currentUser, isNull);
    });

    test('register validates input', () {
      expect(
          auth.register(username: 'ab', email: 'a@b.co', password: 'secret1'),
          'At least 3 characters');
      expect(
          auth.register(username: 'abc', email: 'not-an-email', password: 'secret1'),
          'Invalid email');
      expect(auth.register(username: 'abc', email: 'a@b.co', password: '123'),
          'At least 6 characters');
      expect(
          auth.register(username: 'sarah', email: 'a@b.co', password: 'secret1'),
          'Username already exists');
    });

    test('a registered user can log in with their own password only', () {
      expect(
        auth.register(username: 'mint', email: 'mint@example.com', password: 'secret1'),
        isNull,
      );
      expect(users.findByUsername('mint')?.email, 'mint@example.com');
      expect(auth.login('mint', AuthController.demoPassword), isNull);
      expect(auth.login('mint', 'secret1')?.username, 'mint');
    });

    test('a deleted user can no longer log in', () {
      final john = users.findByUsername('john')!;
      users.delete(john.userId);
      expect(auth.login('john', '1234'), isNull);
    });
  });

  group('UserInventory summary', () {
    final inventory = UserInventory.instance;
    tearDown(() {
      inventory.remove('summary-expired');
      inventory.remove('summary-fresh');
    });

    test('totalQuantity and expiredCount follow added batches', () {
      final qtyBefore = inventory.totalQuantity;
      final expiredBefore = inventory.expiredCount;
      final now = DateTime.now();

      inventory.save(UserItem(
        id: 'summary-expired',
        barcode: 'sum-1',
        name: 'Old yogurt',
        category: 'Food',
        expiry: DateTime(now.year, now.month, now.day - 2),
        addedAt: DateTime(now.year, now.month, now.day - 10),
        qty: 2,
      ));
      inventory.save(UserItem(
        id: 'summary-fresh',
        barcode: 'sum-2',
        name: 'Rice',
        category: 'Food',
        expiry: DateTime(now.year + 1, now.month, now.day),
        qty: 3,
      ));

      expect(inventory.totalQuantity, qtyBefore + 5);
      expect(inventory.expiredCount, expiredBefore + 1);
    });
  });
}
