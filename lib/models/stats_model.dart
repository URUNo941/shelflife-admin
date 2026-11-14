// =============================================================================
// StatsModel = สถิติ Consumed vs Discarded (ระบบสถิติลดขยะอาหาร)
// -----------------------------------------------------------------------------
// - ได้จาก GET /api/stats/me (ของผู้ใช้คนเดียว) หรือ /api/stats/system (admin)
// - batches = จำนวนล็อต, quantity = จำนวนชิ้นรวม
// - wasteRate = % ของที่ "ทิ้ง" เทียบกับของที่ใช้จบแล้วทั้งหมด (ยิ่งต่ำยิ่งดี)
// =============================================================================
class StatCount {
  final int batches;
  final int quantity;
  const StatCount({this.batches = 0, this.quantity = 0});

  factory StatCount.fromJson(Map<String, dynamic>? json) => StatCount(
        batches: (json?['batches'] as num?)?.toInt() ?? 0,
        quantity: (json?['quantity'] as num?)?.toInt() ?? 0,
      );
}

class StatsModel {
  final String period;
  final StatCount active;
  final StatCount consumed;
  final StatCount discarded;
  final StatCount expired;
  final double wasteRate;
  final List<MapEntry<String, int>> topDiscardedCategories;
  final int? totalUsers; // มีเฉพาะสถิติระบบ (admin)
  final int? totalProducts;

  const StatsModel({
    this.period = 'all',
    this.active = const StatCount(),
    this.consumed = const StatCount(),
    this.discarded = const StatCount(),
    this.expired = const StatCount(),
    this.wasteRate = 0,
    this.topDiscardedCategories = const [],
    this.totalUsers,
    this.totalProducts,
  });

  static const empty = StatsModel();

  /// ล็อตทั้งหมดที่นับในช่วงนี้ (ยังอยู่ + ใช้หมด + ทิ้ง)
  int get totalBatches => active.batches + consumed.batches + discarded.batches;

  factory StatsModel.fromJson(Map<String, dynamic> json) => StatsModel(
        period: (json['period'] as String?) ?? 'all',
        active: StatCount.fromJson(json['active'] as Map<String, dynamic>?),
        consumed: StatCount.fromJson(json['consumed'] as Map<String, dynamic>?),
        discarded: StatCount.fromJson(json['discarded'] as Map<String, dynamic>?),
        expired: StatCount.fromJson(json['expired'] as Map<String, dynamic>?),
        wasteRate: (json['waste_rate'] as num?)?.toDouble() ?? 0,
        topDiscardedCategories: [
          for (final row in (json['top_discarded_categories'] as List? ?? const []))
            MapEntry((row as Map)['category'] as String, (row['batches'] as num).toInt()),
        ],
        totalUsers: (json['total_users'] as num?)?.toInt(),
        totalProducts: (json['total_products'] as num?)?.toInt(),
      );
}
