import 'package:flutter/material.dart';

import 'user_data.dart';
import 'user_inventory_view.dart';
import 'user_item_form_view.dart';
import 'user_profile_view.dart';

/// โครงหลักฝั่ง User: แท็บ Home / Inventory + ปุ่มเพิ่มสินค้า
class UserMainView extends StatefulWidget {
  /// เรียกเมื่อผู้ใช้กดยืนยัน Log out (ส่งมาจากจุดที่เปิดหน้านี้ เช่น หลัง login)
  final VoidCallback? onLogout;
  const UserMainView({super.key, this.onLogout});

  @override
  State<UserMainView> createState() => _UserMainViewState();
}

class _UserMainViewState extends State<UserMainView> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// ดึงของในตู้ของผู้ใช้ที่ล็อกอินจาก backend (โหมด test ไม่ทำอะไร)
  Future<void> _load() async {
    final error = await UserInventory.instance.load();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF8FF),
      appBar: AppBar(
        backgroundColor: kUserGreen,
        foregroundColor: Colors.white,
        title: Text(const ['Home', 'My Inventory', 'My Account'][_index]),
      ),
      body: switch (_index) {
        0 => UserHomeView(onSeeAll: () => setState(() => _index = 1)),
        1 => const UserInventoryView(),
        _ => UserProfileView(onLogout: widget.onLogout),
      },
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton(
              backgroundColor: kUserGreen,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserItemFormView()),
              ),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Account'),
        ],
      ),
    );
  }
}

/// หน้า Home ของ User (หน้า 2 ฝั่ง User): สรุปของในตู้ + ของที่ต้องรีบใช้
class UserHomeView extends StatelessWidget {
  final VoidCallback? onSeeAll;
  const UserHomeView({super.key, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserInventory.instance,
      builder: (context, _) {
        final items = UserInventory.instance.items;
        final totalQuantity =
            items.fold<int>(0, (total, item) => total + item.qty);
        final critical = items
            .where((item) => item.isCritical)
            .fold<int>(0, (total, item) => total + item.qty);
        final soon = items
            .where((item) => item.isExpiringSoon)
            .fold<int>(0, (total, item) => total + item.qty);
        final fresh = totalQuantity - critical - soon;
        // ของที่ยังไม่หมดอายุ แต่เป็นสีแดง/เหลือง = ควรใช้ก่อน
        final urgent = items
            .where((item) =>
                !item.isExpired && (item.isCritical || item.isExpiringSoon))
            .toList()
          ..sort((a, b) => a.expiry.compareTo(b.expiry));
        final expiredBatches = items.where((item) => item.isExpired).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome back,', style: TextStyle(color: Colors.grey)),
              const Text('My Shelf',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // Smart Alert: เตือนทันทีที่เข้าแอปถ้ามีของหมดอายุ/ใกล้หมดอายุ
              if (expiredBatches > 0 || urgent.isNotEmpty)
                _SmartAlert(expired: expiredBatches, urgent: urgent.length),
              const SizedBox(height: 4),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  _stat(Icons.inventory_2_outlined, kUserGreen,
                      '$totalQuantity', 'Total Items'),
                  _stat(Icons.schedule, const Color(0xFFD97706), '$soon',
                      'Expiring Soon'),
                  _stat(Icons.warning_amber_rounded, const Color(0xFFDC2626),
                      '$critical', 'Critical'),
                  _stat(Icons.check_circle_outline, kUserGreen, '$fresh',
                      'Still Fresh'),
                ],
              ),
              const SizedBox(height: 24),
              Row(children: [
                const Text('Use these first',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(onPressed: onSeeAll, child: const Text('View all')),
              ]),
              if (urgent.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nothing is expiring soon 🎉')),
              for (final item in urgent.take(3))
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => UserItemFormView(item: item)),
                    ),
                    title: Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(item.category),
                    trailing: Text(item.statusText,
                        style: TextStyle(
                            color: item.statusColor,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

/// แถบเตือนบนหน้า Home (Smart Alert) สีแดงถ้ามีของหมดอายุ ไม่งั้นสีเหลือง
class _SmartAlert extends StatelessWidget {
  final int expired;
  final int urgent;
  const _SmartAlert({required this.expired, required this.urgent});

  @override
  Widget build(BuildContext context) {
    final danger = expired > 0;
    final color = danger ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final parts = [
      if (expired > 0) '$expired batch${expired == 1 ? '' : 'es'} expired',
      if (urgent > 0) '$urgent should be used soon',
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(danger ? Icons.warning_amber_rounded : Icons.notifications_active_outlined,
            color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            parts.join(' · '),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}
