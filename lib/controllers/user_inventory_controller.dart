import 'package:flutter/foundation.dart';

import '../models/user_item.dart';

DateTime _day(int offset) {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day + offset);
}

/// Controller ตู้สินค้าของผู้ใช้ เก็บข้อมูลในหน่วยความจำ (mock, ยังไม่ต่อ API)
/// ตอนต่อ API: เปลี่ยน save/remove ให้เรียก API แล้วค่อย notifyListeners()
class UserInventory extends ChangeNotifier {
  UserInventory._();
  static final UserInventory instance = UserInventory._();

  final List<UserItem> items = [
    UserItem(
        id: 'u1',
        barcode: '8850123456789',
        name: 'Fresh Milk',
        category: 'Food',
        expiry: _day(2)),
    UserItem(
        id: 'u2',
        barcode: '8850987654321',
        name: 'Sliced Bread',
        category: 'Food',
        expiry: _day(5)),
    UserItem(
        id: 'u3',
        barcode: '8850111222333',
        name: 'Paracetamol 500mg',
        category: 'Medicine',
        expiry: _day(120)),
    UserItem(
        id: 'u4',
        barcode: '8850444555666',
        name: 'Instant Noodles',
        category: 'Food',
        expiry: _day(-3)),
    UserItem(
        id: 'u5',
        barcode: '8850777888999',
        name: 'Eggs',
        category: 'Food',
        expiry: _day(14)),
  ];

  int _seq = 100;
  String newId() => 'u${_seq++}';

  /// จำนวนชิ้นรวมทุกล็อต
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.qty);

  /// จำนวนล็อตที่หมดอายุแล้ว
  int get expiredCount => items.where((item) => item.isExpired).length;

  /// จำนวนล็อตที่ใกล้หมดอายุ (ยังไม่หมด)
  int get expiringSoonCount =>
      items.where((item) => item.isExpiringSoon).length;

  UserItem? findBatch({
    required String barcode,
    required DateTime expiry,
    String? excludingId,
  }) {
    final normalizedBarcode = barcode.trim().toLowerCase();
    for (final item in items) {
      final itemExpiry =
          DateTime(item.expiry.year, item.expiry.month, item.expiry.day);
      if (item.id != excludingId &&
          item.barcode.trim().toLowerCase() == normalizedBarcode &&
          itemExpiry == DateTime(expiry.year, expiry.month, expiry.day)) {
        return item;
      }
    }
    return null;
  }

  void save(UserItem item, {UserItem? replacing, UserItem? mergeInto}) {
    if (mergeInto != null) {
      mergeInto.qty += item.qty;
      if (replacing != null) {
        items.removeWhere((existing) => existing.id == replacing.id);
      }
    } else if (replacing == null) {
      items.add(item);
    } else {
      final index = items.indexWhere((existing) => existing.id == replacing.id);
      if (index >= 0) items[index] = item;
    }
    notifyListeners();
  }

  void update() => notifyListeners(); // เรียกหลังแก้ค่าใน UserItem

  void remove(String id) {
    items.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
