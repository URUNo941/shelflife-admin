import 'package:flutter/material.dart';

import '../../controllers/stats_controller.dart';
import '../../controllers/user_inventory_controller.dart';
import '../../models/stats_model.dart';

/// การ์ดสถิติ "Consumed vs Discarded" ของผู้ใช้ (ระบบสถิติลดขยะอาหาร)
/// โหลดใหม่ทุกครั้งที่ของในตู้เปลี่ยน (ใช้หมด / ทิ้ง / เพิ่ม)
class WasteStatsCard extends StatefulWidget {
  const WasteStatsCard({super.key});

  @override
  State<WasteStatsCard> createState() => _WasteStatsCardState();
}

class _WasteStatsCardState extends State<WasteStatsCard> {
  final _stats = StatsController.instance;
  final _inventory = UserInventory.instance;
  String _period = 'All Time';

  @override
  void initState() {
    super.initState();
    _inventory.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _inventory.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _stats.loadMine(period: StatsController.periods[_period]!);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _stats,
      builder: (context, _) {
        final StatsModel s = _stats.mine;
        final finished = s.consumed.batches + s.discarded.batches;
        final consumedRatio = finished == 0 ? 0.0 : s.consumed.batches / finished;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(
                  child: Text('My food waste',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                DropdownButton<String>(
                  value: _period,
                  underline: const SizedBox.shrink(),
                  items: StatsController.periods.keys
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (p) {
                    if (p == null) return;
                    setState(() => _period = p);
                    _reload();
                  },
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _tile('Consumed', s.consumed.batches, const Color(0xFF0D7A53)),
                const SizedBox(width: 12),
                _tile('Discarded', s.discarded.batches, const Color(0xFFDC2626)),
                const SizedBox(width: 12),
                _tile('Expired now', s.expired.batches, const Color(0xFFD97706)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: finished == 0 ? 0 : consumedRatio,
                  backgroundColor: finished == 0
                      ? Colors.grey.shade200
                      : const Color(0xFFFCA5A5),
                  color: const Color(0xFF0D7A53),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                finished == 0
                    ? 'No finished batches yet. Use "Mark as consumed" or "Mark as discarded" in My Inventory.'
                    : 'Waste rate ${s.wasteRate.toStringAsFixed(1)}% '
                        '(${s.discarded.batches} of $finished finished batches were thrown away)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(String label, int value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );
}
