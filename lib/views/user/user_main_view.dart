import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'login_view.dart';

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
    UserInventory.instance.refresh();
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
      body: ListenableBuilder(
          listenable: UserInventory.instance,
          builder: (context, _) {
            final inv = UserInventory.instance;
            if (inv.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (inv.error != null) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(inv.error!),
                TextButton(onPressed: inv.refresh, child: const Text('Retry')),
                TextButton(
                    onPressed: () {
                      ApiClient.instance.logout();
                      inv.clear();
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginView()),
                          (_) => false);
                    },
                    child: const Text('Return to sign in'))
              ]));
            }
            return switch (_index) {
              0 => UserHomeView(onSeeAll: () => setState(() => _index = 1)),
              1 => const UserInventoryView(),
              _ => UserProfileView(onLogout: widget.onLogout),
            };
          }),
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
        final expired = items.where((i) => i.isExpired).length;
        final soon = items.where((i) => i.isExpiringSoon).length;
        final fresh = items.length - expired - soon;
        final urgent = items
            .where((i) => i.isExpired || i.isExpiringSoon)
            .toList()
          ..sort((a, b) => a.expiry.compareTo(b.expiry));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome back,', style: TextStyle(color: Colors.grey)),
              const Text('My Shelf',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  _stat(Icons.inventory_2_outlined, kUserGreen,
                      '${items.length}', 'Total Items'),
                  _stat(Icons.schedule, const Color(0xFFD97706), '$soon',
                      'Expiring Soon'),
                  _stat(Icons.warning_amber_rounded, const Color(0xFFDC2626),
                      '$expired', 'Expired'),
                  _stat(Icons.check_circle_outline, const Color(0xFF1E88E5),
                      '$fresh', 'Still Fresh'),
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
