import 'package:flutter/material.dart';

import 'user_data.dart';
import 'user_item_detail_view.dart';
import 'user_inventory_view.dart';
import 'user_item_form_view.dart';
import 'user_notifications_view.dart';
import 'user_profile_view.dart';

/// โครงหลักฝั่ง User: Home, Inventory, Notifications, Account, and quick add.
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
        backgroundColor: const Color(0xFFFCF8FF),
        title: Text(
          const ['ShelfLife', 'My Items', 'Notifications', 'My Profile'][_index],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_index != 2)
            ListenableBuilder(
              listenable: UserInventory.instance,
              builder: (context, _) {
                final alerts = UserInventory.instance.items
                    .where((item) =>
                        item.isExpired ||
                        item.daysLeft <= 3 ||
                        item.isExpiringSoon ||
                        item.isCritical)
                    .length;
                return IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => setState(() => _index = 2),
                  icon: Badge(
                    isLabelVisible: alerts > 0,
                    label: Text('$alerts'),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                );
              },
            ),
        ],
      ),
      body: switch (_index) {
        0 => UserHomeView(
            onSeeAll: () => setState(() => _index = 1),
            onSeeNotifications: () => setState(() => _index = 2),
          ),
        1 => const UserInventoryView(),
        2 => const UserNotificationsView(),
        _ => UserProfileView(onLogout: widget.onLogout),
      },
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            _navItem(0, Icons.home_outlined, 'Home'),
            _navItem(1, Icons.inventory_2_outlined, 'Items'),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: FloatingActionButton(
                    heroTag: 'user-quick-add',
                    tooltip: 'Add item',
                    elevation: 2,
                    backgroundColor: kUserGreen,
                    foregroundColor: Colors.white,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UserItemFormView()),
                    ),
                    child: const Icon(Icons.add_rounded, size: 30),
                  ),
                ),
              ),
            ),
            _navItem(2, Icons.notifications_none_rounded, 'Alerts'),
            _navItem(3, Icons.person_outline, 'Account'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _index == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: () => setState(() => _index = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 22,
                    color: selected ? kUserGreen : Colors.grey.shade600),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? kUserGreen : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// หน้า Home ของ User (หน้า 2 ฝั่ง User): สรุปของในตู้ + ของที่ต้องรีบใช้
class UserHomeView extends StatelessWidget {
  final VoidCallback? onSeeAll;
  final VoidCallback? onSeeNotifications;
  const UserHomeView({super.key, this.onSeeAll, this.onSeeNotifications});

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
                _SmartAlert(
                  expired: expiredBatches,
                  urgent: urgent.length,
                  onTap: onSeeNotifications,
                ),
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
                          builder: (_) => UserItemDetailView(item: item)),
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
  final VoidCallback? onTap;
  const _SmartAlert({
    required this.expired,
    required this.urgent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final danger = expired > 0;
    final color = danger ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final parts = [
      if (expired > 0) '$expired batch${expired == 1 ? '' : 'es'} expired',
      if (urgent > 0) '$urgent should be used soon',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(
                  danger
                      ? Icons.warning_amber_rounded
                      : Icons.notifications_active_outlined,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    parts.join(' · '),
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right, color: color),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
