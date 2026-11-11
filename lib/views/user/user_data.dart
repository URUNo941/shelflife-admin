import 'package:flutter/material.dart';
import '../../utils/expiry_status.dart';

const kUserGreen = Color(0xFF0D7A53);
const kCategories = ['Food', 'Medicine', 'Other'];

DateTime _day(int offset) {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day + offset);
}

/// สินค้าในตู้ของผู้ใช้ 1 ชิ้น
class UserItem {
  final String id;
  String barcode;
  String name;
  String category;
  DateTime expiry;
  final DateTime addedAt;
  int qty;

  UserItem({
    required this.id,
    required this.barcode,
    required this.name,
    required this.category,
    required this.expiry,
    DateTime? addedAt,
    this.qty = 1,
  }) : addedAt = addedAt ?? DateTime.now();

  int get daysLeft {
    final n = DateTime.now();
    return expiry.difference(DateTime(n.year, n.month, n.day)).inDays;
  }

  bool get isExpired => daysLeft < 0;
  double get remainingLifePercentage => ExpiryStatus.remainingPercentage(
        addedAt: addedAt,
        expiryDate: expiry,
      );
  bool get isCritical =>
      daysLeft <= 0 || (daysLeft > 1 && remainingLifePercentage < 10);
  bool get isExpiringSoon =>
      daysLeft >= 0 &&
      (daysLeft == 1 ||
          (remainingLifePercentage >= 10 && remainingLifePercentage < 30));

  Color get statusColor =>
      ExpiryStatus.color(addedAt: addedAt, expiryDate: expiry);

  String get statusText => isExpired
      ? 'Expired ${-daysLeft}d ago'
      : daysLeft == 0
          ? 'Expires today'
          : '$daysLeft day${daysLeft == 1 ? '' : 's'} left';
}

/// ที่เก็บข้อมูลชั่วคราวในหน่วยความจำ (mock)
/// ตอนต่อ API: เปลี่ยน add/update/remove ให้เรียก API แล้วค่อย notifyListeners()
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
