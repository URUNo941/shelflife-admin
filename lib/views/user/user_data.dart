import 'package:flutter/material.dart';

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
  int qty;

  UserItem({
    required this.id,
    required this.barcode,
    required this.name,
    required this.category,
    required this.expiry,
    this.qty = 1,
  });

  int get daysLeft {
    final n = DateTime.now();
    return expiry.difference(DateTime(n.year, n.month, n.day)).inDays;
  }

  bool get isExpired => daysLeft < 0;
  bool get isExpiringSoon => daysLeft >= 0 && daysLeft <= 7;

  Color get statusColor => isExpired
      ? const Color(0xFFDC2626)
      : isExpiringSoon
          ? const Color(0xFFD97706)
          : kUserGreen;

  String get statusText => isExpired
      ? 'Expired ${-daysLeft}d ago'
      : daysLeft == 0
          ? 'Expires today'
          : '$daysLeft days left';
}

/// ที่เก็บข้อมูลชั่วคราวในหน่วยความจำ (mock)
/// ตอนต่อ API: เปลี่ยน add/update/remove ให้เรียก API แล้วค่อย notifyListeners()
class UserInventory extends ChangeNotifier {
  UserInventory._();
  static final UserInventory instance = UserInventory._();

  final List<UserItem> items = [
    UserItem(id: 'u1', barcode: '8850123456789', name: 'Fresh Milk', category: 'Food', expiry: _day(2)),
    UserItem(id: 'u2', barcode: '8850987654321', name: 'Sliced Bread', category: 'Food', expiry: _day(5)),
    UserItem(id: 'u3', barcode: '8850111222333', name: 'Paracetamol 500mg', category: 'Medicine', expiry: _day(120)),
    UserItem(id: 'u4', barcode: '8850444555666', name: 'Instant Noodles', category: 'Food', expiry: _day(-3)),
    UserItem(id: 'u5', barcode: '8850777888999', name: 'Eggs', category: 'Food', expiry: _day(14)),
  ];

  int _seq = 100;
  String newId() => 'u${_seq++}';

  void add(UserItem item) {
    items.add(item);
    notifyListeners();
  }

  void update() => notifyListeners(); // เรียกหลังแก้ค่าใน UserItem

  void remove(String id) {
    items.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}