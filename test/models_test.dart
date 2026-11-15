import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/mock_data.dart';
import 'package:myapp/models/product_model.dart';
import 'package:myapp/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('fromJson parses a users row and normalizes the role', () {
      final user = UserModel.fromJson({
        'user_id': 7,
        'username': 'sarah',
        'role': 'admin',
        'created_at': '2026-10-05T08:00:00.000Z',
      });

      expect(user.userId, 7);
      expect(user.username, 'sarah');
      expect(user.email, '');
      expect(user.isAdmin, isTrue);
      expect(user.roleLabel, 'Admin');
      expect(user.createdAt.toUtc(), DateTime.utc(2026, 10, 5, 8));
    });

    test('toJson round-trips through fromJson', () {
      final user = UserModel(
        userId: 3,
        username: 'john',
        email: 'john@example.com',
        role: UserModel.roleUser,
        createdAt: DateTime(2026, 10, 10),
      );
      final copy = UserModel.fromJson(user.toJson());

      expect(copy.userId, user.userId);
      expect(copy.username, user.username);
      expect(copy.email, user.email);
      expect(copy.role, user.role);
      expect(copy.createdAt, user.createdAt);
    });

    test('joinedLabel formats the creation date', () {
      final user = UserModel(
        userId: 1,
        username: 'a',
        role: UserModel.roleUser,
        createdAt: DateTime(2026, 1, 9),
      );
      expect(user.joinedLabel, 'Jan 9, 2026');
    });

    test('copyWith accepts display labels for role', () {
      final user = UserModel(
        userId: 1,
        username: 'a',
        role: UserModel.roleUser,
        createdAt: DateTime(2026),
      );
      expect(user.copyWith(role: 'Admin').role, UserModel.roleAdmin);
      expect(user.copyWith(role: 'User').role, UserModel.roleUser);
      expect(user.copyWith(role: 'Admin').userId, 1);
    });
  });

  group('ProductModel', () {
    test('fromJson parses a global_products row from the API', () {
      final product = ProductModel.fromJson({
        'product_id': 1,
        'barcode': '8850123456789',
        'product_name': 'Fresh Milk 1L',
        'category': 'Food',
        'created_by': 1,
        'created_at': '2026-11-03T13:27:43.000Z',
      });

      expect(product.productId, 1);
      expect(product.barcode, '8850123456789');
      expect(product.productName, 'Fresh Milk 1L');
      expect(product.category, 'Food');
      expect(product.createdBy, 1);
    });

    test('missing category defaults to General and created_by may be null',
        () {
      final product = ProductModel.fromJson({
        'product_id': 2,
        'barcode': '123',
        'product_name': 'Thing',
        'created_by': null,
        'created_at': '2026-11-03T13:27:43.000Z',
      });
      expect(product.category, 'General');
      expect(product.createdBy, isNull);
    });

    test('copyWith changes only the given fields', () {
      final product = MockData.globalProducts().first;
      final edited = product.copyWith(productName: 'Low-fat Milk');

      expect(edited.productName, 'Low-fat Milk');
      expect(edited.productId, product.productId);
      expect(edited.barcode, product.barcode);
      expect(edited.category, product.category);
    });
  });

  group('MockData', () {
    test('returns a fresh list on each call', () {
      final first = MockData.users();
      first.clear();
      expect(MockData.users(), isNotEmpty);
    });

    test('seed data has unique ids and barcodes and an admin account', () {
      final users = MockData.users();
      final products = MockData.globalProducts();

      expect(users.map((u) => u.userId).toSet().length, users.length);
      expect(products.map((p) => p.barcode).toSet().length, products.length);
      expect(users.where((u) => u.isAdmin), isNotEmpty);
    });
  });
}
