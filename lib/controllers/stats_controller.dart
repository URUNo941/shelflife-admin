import 'package:flutter/foundation.dart';

import '../models/stats_model.dart';
import '../services/api_client.dart';
import 'product_controller.dart';
import 'user_controller.dart';
import 'user_inventory_controller.dart';

/// Controller สถิติ Consumed vs Discarded
///
/// - [mine] = ของผู้ใช้ที่ล็อกอิน (หน้า Account)
/// - [system] = ทั้งระบบ (หน้า Dashboard / Analytics ของ admin)
/// แอปจริงดึงจาก `/api/stats/...` ตอน test คำนวณจากข้อมูลในหน่วยความจำ
class StatsController extends ChangeNotifier {
  StatsController._();
  static final StatsController instance = StatsController._();

  /// ตัวเลือกช่วงเวลาบนหน้าจอ -> ค่า period ที่ส่งให้ API
  static const periods = {
    'Today': 'today',
    'This Week': 'week',
    'This Month': 'month',
    'This Year': 'year',
    'All Time': 'all',
  };

  StatsModel mine = StatsModel.empty;
  StatsModel system = StatsModel.empty;
  String? lastError;

  ApiClient get _api => ApiClient.instance;
  bool get _online => _api.enabled;

  Future<void> loadMine({String period = 'all'}) async {
    // รอให้ build รอบนี้จบก่อน (หน้าจอเรียกจาก initState) ค่อยแจ้ง listener
    await Future<void>.value();
    if (!_online) {
      mine = _localSummary(period);
    } else {
      try {
        mine = StatsModel.fromJson(
            await _api.get('/stats/me?period=$period') as Map<String, dynamic>);
        lastError = null;
      } on ApiException catch (e) {
        lastError = e.message;
      }
    }
    notifyListeners();
  }

  Future<void> loadSystem({String period = 'all'}) async {
    await Future<void>.value();
    if (!_online) {
      final local = _localSummary(period);
      system = StatsModel(
        period: period,
        active: local.active,
        consumed: local.consumed,
        discarded: local.discarded,
        expired: local.expired,
        wasteRate: local.wasteRate,
        totalUsers: UserController.instance.users.length,
        totalProducts: ProductController.instance.products.length,
      );
    } else {
      try {
        system = StatsModel.fromJson(
            await _api.get('/stats/system?period=$period') as Map<String, dynamic>);
        lastError = null;
      } on ApiException catch (e) {
        lastError = e.message;
      }
    }
    notifyListeners();
  }

  void clear() {
    mine = StatsModel.empty;
    system = StatsModel.empty;
    notifyListeners();
  }

  /// สถิติจากข้อมูลในหน่วยความจำ (ไม่มีวันที่ของการใช้/ทิ้ง จึงไม่แยกช่วงเวลา)
  StatsModel _localSummary(String period) {
    final inv = UserInventory.instance;
    final expired = inv.items.where((i) => i.isExpired);
    final finished = inv.consumedCount + inv.discardedCount;
    return StatsModel(
      period: period,
      active: StatCount(batches: inv.items.length, quantity: inv.totalQuantity),
      consumed: StatCount(batches: inv.consumedCount, quantity: inv.consumedCount),
      discarded: StatCount(batches: inv.discardedCount, quantity: inv.discardedCount),
      expired: StatCount(
        batches: expired.length,
        quantity: expired.fold(0, (sum, i) => sum + i.qty),
      ),
      wasteRate: finished == 0
          ? 0
          : (inv.discardedCount * 1000 / finished).round() / 10,
    );
  }
}
