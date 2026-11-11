import '../../services/api_client.dart';
import 'package:flutter/material.dart';

const kUserGreen = Color(0xFF0D7A53);
const kCategories = ['Food', 'Medicine', 'Other'];

/// สินค้าในตู้ของผู้ใช้ 1 ชิ้น
class UserItem {
  final String id;
  String barcode;
  String name;
  String category;
  DateTime expiry;
  int qty;
  String status;

  UserItem({
    required this.id,
    required this.barcode,
    required this.name,
    required this.category,
    required this.expiry,
    this.qty = 1,
    this.status = 'active',
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

class UserInventory extends ChangeNotifier {
  UserInventory._();
  static final instance = UserInventory._();
  final List<UserItem> items = [];
  bool loading = false;
  String? error;
  int _generation = 0;
  void clear() {
    _generation++;
    items.clear();
    error = null;
    loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    final generation = _generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rows =
          await ApiClient.instance.request('GET', '/me/inventory') as List;
      if (generation != _generation) return;
      items
        ..clear()
        ..addAll(rows.map((j) => UserItem(
            id: '${j['item_id']}',
            barcode: j['barcode'] ?? '',
            name: j['product_name'],
            category: j['category'],
            expiry: DateTime.parse(j['expiration_date']),
            status: j['status'],
            qty: j['quantity'])));
    } catch (e) {
      if (generation == _generation) error = '$e';
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> save(UserItem item, {required bool create}) async {
    await ApiClient.instance.request(create ? 'POST' : 'PATCH',
        create ? '/me/inventory' : '/me/inventory/${item.id}', {
      'barcode': item.barcode.isEmpty ? null : item.barcode,
      'product_name': item.name,
      'category': item.category,
      'quantity': item.qty,
      'status': item.status,
      'expiration_date': item.expiry.toIso8601String().substring(0, 10),
    });
    await refresh();
  }

  Future<void> remove(String id) async {
    await ApiClient.instance.request('DELETE', '/me/inventory/$id');
    await refresh();
  }
}
