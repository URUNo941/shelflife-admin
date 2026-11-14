import 'package:flutter/foundation.dart';

import '../models/user_item.dart';
import '../services/api_client.dart';

DateTime _day(int offset) {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day + offset);
}

/// Controller ตู้สินค้าของผู้ใช้ที่ล็อกอินอยู่
///
/// - แอปจริง (ApiClient เปิดใช้): ทุกการเพิ่ม/แก้/ลบ/ใช้/ทิ้ง ส่งไปที่ `/api/items`
///   แล้วค่อยอัปเดตรายการในหน่วยความจำ + notifyListeners() ให้หน้าจอวาดใหม่
/// - ตอน test: ใช้รายการตัวอย่างด้านล่างในหน่วยความจำ
///
/// `items` เก็บเฉพาะล็อตที่ยัง active (ยังอยู่ในตู้)
/// ล็อตที่ "ใช้หมด" (consumed) หรือ "ทิ้ง" (discarded) จะออกจากรายการ แต่นับเป็นสถิติ
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

  /// สถิติในหน่วยความจำ (โหมด test) จำนวนล็อตที่ใช้หมด / ทิ้ง
  int consumedCount = 0;
  int discardedCount = 0;

  int _seq = 100;
  String newId() => 'u${_seq++}';

  ApiClient get _api => ApiClient.instance;
  bool get _online => _api.enabled;

  bool _loading = false;
  bool get loading => _loading;
  String? lastError;

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

  // ---------------------------------------------------------------------------
  // โหลด / ล้าง
  // ---------------------------------------------------------------------------

  /// ดึงของในตู้ (เฉพาะ active) ของผู้ใช้ที่ล็อกอินอยู่
  Future<String?> load() async {
    if (!_online) return null;
    _loading = true;
    notifyListeners();
    try {
      final rows = await _api.get('/items') as List;
      items
        ..clear()
        ..addAll(rows.map((r) => itemFromJson(r as Map<String, dynamic>)));
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
    return lastError;
  }

  void clear() {
    items.clear();
    consumedCount = 0;
    discardedCount = 0;
    notifyListeners();
  }

  /// JSON 1 แถวจาก API -> UserItem (id ของล็อต = item_id)
  static UserItem itemFromJson(Map<String, dynamic> json) => UserItem(
        id: '${json['item_id']}',
        barcode: (json['barcode'] as String?) ?? '',
        name: json['product_name'] as String,
        category: (json['category'] as String?) ?? 'Other',
        expiry: parseApiDate(json['expiration_date'] as String),
        addedAt: json['created_at'] == null
            ? null
            : parseApiDate(json['created_at'] as String),
        qty: (json['quantity'] as num?)?.toInt() ?? 1,
      );

  static Map<String, dynamic> _toJson(UserItem item) => {
        'barcode': item.barcode.trim().isEmpty ? null : item.barcode.trim(),
        'product_name': item.name.trim(),
        'category': item.category,
        'quantity': item.qty,
        'expiration_date': formatApiDate(item.expiry),
      };

  // ---------------------------------------------------------------------------
  // CRUD ที่หน้าจอเรียก (async)
  // ---------------------------------------------------------------------------

  /// เพิ่มล็อตใหม่ / แก้ล็อตเดิม / รวมจำนวนเข้าล็อตที่วันหมดอายุตรงกัน
  Future<String?> saveItem(UserItem item,
      {UserItem? replacing, UserItem? mergeInto}) async {
    if (!_online) {
      save(item, replacing: replacing, mergeInto: mergeInto);
      return null;
    }
    try {
      if (mergeInto != null) {
        final row = await _api.put('/items/${mergeInto.id}', {
          'quantity': mergeInto.qty + item.qty,
        });
        _replace(mergeInto.id, itemFromJson(row as Map<String, dynamic>));
        if (replacing != null) {
          await _api.delete('/items/${replacing.id}');
          items.removeWhere((e) => e.id == replacing.id);
        }
      } else if (replacing == null) {
        final row = await _api.post('/items', _toJson(item));
        items.add(itemFromJson(row as Map<String, dynamic>));
      } else {
        final row = await _api.put('/items/${replacing.id}', _toJson(item));
        _replace(replacing.id, itemFromJson(row as Map<String, dynamic>));
      }
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// ใช้ไป 1 ชิ้น: เหลือหลายชิ้น = ลดจำนวน, ชิ้นสุดท้าย = ล็อตนี้ "consumed"
  Future<String?> useOne(UserItem item) async {
    if (item.qty > 1) {
      if (!_online) {
        item.qty--;
        notifyListeners();
        return null;
      }
      try {
        final row = await _api.put('/items/${item.id}', {'quantity': item.qty - 1});
        _replace(item.id, itemFromJson(row as Map<String, dynamic>));
        notifyListeners();
        return null;
      } on ApiException catch (e) {
        return e.message;
      }
    }
    return _finish(item, 'consumed');
  }

  /// ใช้หมดทั้งล็อต (Mark as Consumed)
  Future<String?> markConsumed(UserItem item) => _finish(item, 'consumed');

  /// ทิ้งทั้งล็อต เช่น หมดอายุ/เสีย (Mark as Discarded)
  Future<String?> discard(UserItem item) => _finish(item, 'discarded');

  Future<String?> _finish(UserItem item, String status) async {
    if (_online) {
      try {
        await _api.put('/items/${item.id}', {'status': status});
      } on ApiException catch (e) {
        return e.message;
      }
    }
    items.removeWhere((e) => e.id == item.id);
    if (status == 'consumed') {
      consumedCount++;
    } else {
      discardedCount++;
    }
    notifyListeners();
    return null;
  }

  /// ลบล็อตทิ้ง (กรอกผิด) ไม่นับเป็นสถิติ
  Future<String?> deleteItem(String id) async {
    if (_online) {
      try {
        await _api.delete('/items/$id');
      } on ApiException catch (e) {
        return e.message;
      }
    }
    remove(id);
    return null;
  }

  void _replace(String id, UserItem updated) {
    final index = items.indexWhere((e) => e.id == id);
    if (index >= 0) {
      items[index] = updated;
    } else {
      items.add(updated);
    }
  }

  // ---------------------------------------------------------------------------
  // โหมดในหน่วยความจำ (sync) ใช้ใน test
  // ---------------------------------------------------------------------------

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
