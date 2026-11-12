import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/utils/expiry_status.dart';
import 'package:myapp/views/user/user_data.dart';

void main() {

   group('UserInventory batch behavior', () {
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
        name: 'Test product',
        category: 'Food',
        expiry: expiry,
        qty: quantity,
      );
    }

    setUp(() => testItemIds.clear());
    tearDown(() {
      for (final id in testItemIds) {
        inventory.remove(id);
      }
    });

    test('Finds a batch by normalized barcode and calendar expiry date', () {
      final expiry = DateTime(2099, 12, 10);
      final existing = createItem(
        id: 'unit-find-existing',
        barcode: 'Unit-Find-001',
        expiry: expiry,
      );
      inventory.save(existing);

      expect(
        inventory.findBatch(
          barcode: ' unit-find-001 ',
          expiry: DateTime(2099, 12, 10, 23, 59),
        ),
        same(existing),
      );
      expect(
        inventory.findBatch(
          barcode: 'unit-find-001',
          expiry: DateTime(2099, 12, 11),
        ),
        isNull,
      );
      expect(
        inventory.findBatch(barcode: 'different-barcode', expiry: expiry),
        isNull,
      );
    });

    test('Same barcode with a different expiry remains a separate batch', () {
      final first = createItem(
        id: 'unit-expiry-first',
        barcode: 'unit-expiry-001',
        expiry: DateTime(2099, 12, 10),
      );
      final second = createItem(
        id: 'unit-expiry-second',
        barcode: 'unit-expiry-001',
        expiry: DateTime(2099, 12, 20),
        quantity: 3,
      );

      inventory.save(first);
      inventory.save(second);

      expect(inventory.items, contains(first));
      expect(inventory.items, contains(second));
      expect(first.qty, 1);
      expect(second.qty, 3);
    });

    test('Explicit merge adds quantity to the selected batch', () {
      final existing = createItem(
        id: 'unit-merge-existing',
        barcode: 'unit-merge-001',
        expiry: DateTime(2099, 12, 10),
        quantity: 2,
      );
      final additional = createItem(
        id: 'unit-merge-additional',
        barcode: 'unit-merge-001',
        expiry: DateTime(2099, 12, 10),
        quantity: 4,
      );
      inventory.save(existing);
      inventory.save(additional, mergeInto: existing);

      expect(existing.qty, 6);
      expect(inventory.items, contains(existing));
      expect(inventory.items, isNot(contains(additional)));
    });

    test('Editing into an existing batch merges and removes the old batch', () {
      final oldBatch = createItem(
        id: 'unit-edit-old',
        barcode: 'unit-edit-old',
        expiry: DateTime(2099, 12, 10),
        quantity: 2,
      );
      final matchingBatch = createItem(
        id: 'unit-edit-match',
        barcode: 'unit-edit-new',
        expiry: DateTime(2099, 12, 20),
        quantity: 5,
      );
      final editedBatch = createItem(
        id: oldBatch.id,
        barcode: matchingBatch.barcode,
        expiry: matchingBatch.expiry,
        quantity: 3,
      );
      inventory.save(oldBatch);
      inventory.save(matchingBatch);

      inventory.save(
        editedBatch,
        replacing: oldBatch,
        mergeInto: matchingBatch,
      );

      expect(matchingBatch.qty, 8);
      expect(inventory.items, isNot(contains(oldBatch)));
      expect(inventory.items, contains(matchingBatch));
    });

    test('Removing a batch deletes only the selected batch', () {
      final first = createItem(
        id: 'unit-remove-first',
        barcode: 'unit-remove-001',
        expiry: DateTime(2099, 12, 10),
      );
      final second = createItem(
        id: 'unit-remove-second',
        barcode: 'unit-remove-001',
        expiry: DateTime(2099, 12, 20),
      );
      inventory.save(first);
      inventory.save(second);

      inventory.remove(first.id);

      expect(inventory.items, isNot(contains(first)));
      expect(inventory.items, contains(second));
    });
  });
  
  group('ExpiryStatus color rules', () {
    final addedAt = DateTime(2026, 1, 1);
    final expiryDate = DateTime(2026, 1, 11);

    test('100% remaining is green', () {
      expect(
        ExpiryStatus.color(
          addedAt: addedAt,
          expiryDate: expiryDate,
          today: addedAt,
        ),
        ExpiryStatus.green,
      );
    });

    test('30% remaining is green', () {
      expect(
        ExpiryStatus.color(
          addedAt: addedAt,
          expiryDate: expiryDate,
          today: DateTime(2026, 1, 8),
        ),
        ExpiryStatus.green,
      );
    });

    test('Between 10% and below 30% remaining is yellow', () {
      expect(
        ExpiryStatus.color(
          addedAt: addedAt,
          expiryDate: expiryDate,
          today: DateTime(2026, 1, 9),
        ),
        ExpiryStatus.yellow,
      );
      expect(
        ExpiryStatus.color(
          addedAt: addedAt,
          expiryDate: expiryDate,
          today: DateTime(2026, 1, 10),
        ),
        ExpiryStatus.yellow,
      );
    });

    test('Below 10% remaining is red unless one day remains', () {
      expect(
        ExpiryStatus.color(
          addedAt: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 4, 11),
          today: DateTime(2026, 4, 9),
        ),
        ExpiryStatus.red,
      );
      expect(
        ExpiryStatus.color(
          addedAt: DateTime(2026, 1, 1),
          expiryDate: DateTime(2026, 4, 11),
          today: DateTime(2026, 4, 10),
        ),
        ExpiryStatus.yellow,
      );
    });

    test('Expires today and expired dates are red', () {
      expect(
        ExpiryStatus.color(
          addedAt: addedAt,
          expiryDate: expiryDate,
          today: expiryDate,
        ),
        ExpiryStatus.red,
      );
      expect(
        ExpiryStatus.color(
          addedAt: addedAt,
          expiryDate: expiryDate,
          today: DateTime(2026, 1, 12),
        ),
        ExpiryStatus.red,
      );
    });
  });

  group('UserItem expiry labels', () {
    test('One day remaining uses singular label and yellow status', () {
      final today = DateTime.now();
      final item = UserItem(
        id: 'unit-label-one-day',
        barcode: 'unit-label-one-day',
        name: 'Test item',
        category: 'Food',
        addedAt: today,
        expiry: DateTime(today.year, today.month, today.day + 1),
      );

      expect(item.statusText, '1 day left');
      expect(item.statusColor, ExpiryStatus.yellow);
      expect(item.isExpiringSoon, isTrue);
    });

    test('Expired item shows days elapsed and red status', () {
      final today = DateTime.now();
      final item = UserItem(
        id: 'unit-label-expired',
        barcode: 'unit-label-expired',
        name: 'Expired item',
        category: 'Food',
        addedAt: DateTime(today.year, today.month, today.day - 10),
        expiry: DateTime(today.year, today.month, today.day - 2),
      );

      expect(item.statusText, 'Expired 2d ago');
      expect(item.statusColor, ExpiryStatus.red);
      expect(item.isExpired, isTrue);
      expect(item.isCritical, isTrue);
    });
  });
}
