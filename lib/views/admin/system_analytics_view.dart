import 'package:flutter/material.dart';

class SystemAnalyticsView extends StatefulWidget {
  const SystemAnalyticsView({super.key});

  @override
  State<SystemAnalyticsView> createState() => _SystemAnalyticsViewState();
}

class _SystemAnalyticsViewState extends State<SystemAnalyticsView> {
  String selectedPeriod = 'This Month';

  static const _periodItemStats = {
    'Today': {'active': 42, 'consumed': 6, 'discarded': 2},
    'This Week': {'active': 302, 'consumed': 56, 'discarded': 22},
    'This Month': {'active': 980, 'consumed': 180, 'discarded': 80},
    'This Year': {'active': 1120, 'consumed': 245, 'discarded': 115},
  };

  @override
  Widget build(BuildContext context) {
    final itemStats = _periodItemStats[selectedPeriod]!;
    final activeItems = itemStats['active']!;
    final consumedItems = itemStats['consumed']!;
    final discardedItems = itemStats['discarded']!;
    final totalItems = activeItems + consumedItems + discardedItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Time Period Dropdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'System Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPeriod,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.black54),
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedPeriod = newValue;
                            });
                          }
                        },
                        items: <String>[
                          'Today',
                          'This Week',
                          'This Month',
                          'This Year'
                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stat Cards Grid (2x2)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  _buildStatCard(
                    icon: Icons.people_outline_rounded,
                    iconBgColor: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF0D7A53),
                    value: '128',
                    label: 'Total Users',
                  ),
                  _buildStatCard(
                    icon: Icons.qr_code_2_rounded,
                    iconBgColor: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF0D7A53),
                    value: '350',
                    label: 'Global Barcodes',
                  ),
                  _buildStatCard(
                    icon: Icons.widgets_outlined,
                    iconBgColor: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    value: totalItems.toString(),
                    label: 'Inventory Items',
                  ),
                  _buildStatCard(
                    icon: Icons.warning_amber_rounded,
                    iconBgColor: const Color(0xFFFEE2E2),
                    iconColor: const Color(0xFFDC2626),
                    value: discardedItems.toString(),
                    label: 'Expired Items',
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Item Status Title
              const Text(
                'Item Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // Donut Chart & Legend Section
              Row(
                children: [
                  // Donut Chart
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(150, 150),
                          painter: DonutChartPainter(
                            activeRatio: activeItems / totalItems,
                            consumedRatio: consumedItems / totalItems,
                            discardedRatio: discardedItems / totalItems,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              totalItems.toString(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Items',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Chart Legends List
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(
                          color: const Color(0xFF10B981),
                          label: 'Active',
                          value:
                              '$activeItems (${(activeItems * 100 / totalItems).round()}%)',
                        ),
                        const SizedBox(height: 16),
                        _buildLegendItem(
                          color: const Color(0xFF0EA5E9),
                          label: 'Consumed',
                          value:
                              '$consumedItems (${(consumedItems * 100 / totalItems).round()}%)',
                        ),
                        const SizedBox(height: 16),
                        _buildLegendItem(
                          color: const Color(0xFFEF4444),
                          label: 'Discarded',
                          value:
                              '$discardedItems (${(discardedItems * 100 / totalItems).round()}%)',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Card สถิติ
  Widget _buildStatCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // รายการ Legend
  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// วาดกราฟวงกลม Donut Chart ด้วย CustomPainter
class DonutChartPainter extends CustomPainter {
  final double activeRatio;
  final double consumedRatio;
  final double discardedRatio;

  const DonutChartPainter({
    required this.activeRatio,
    required this.consumedRatio,
    required this.discardedRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 22.0;

    final paintActive = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintConsumed = Paint()
      ..color = const Color(0xFF0EA5E9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintDiscarded = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    const fullCircle = 2 * 3.141592653589793;
    const gap = 0.08;
    final activeAngle = fullCircle * activeRatio - gap;
    final consumedAngle = fullCircle * consumedRatio - gap;
    final discardedAngle = fullCircle * discardedRatio - gap;

    double startAngle = -3.141592653589793 / 2;

    canvas.drawArc(rect, startAngle, activeAngle, false, paintActive);
    startAngle += activeAngle + gap;

    canvas.drawArc(rect, startAngle, consumedAngle, false, paintConsumed);
    startAngle += consumedAngle + gap;

    canvas.drawArc(rect, startAngle, discardedAngle, false, paintDiscarded);
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) =>
      activeRatio != oldDelegate.activeRatio ||
      consumedRatio != oldDelegate.consumedRatio ||
      discardedRatio != oldDelegate.discardedRatio;
}
