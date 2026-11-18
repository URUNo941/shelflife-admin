import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/stats_controller.dart';
import '../user/login_view.dart' show LoginView;

class AdminDashboardView extends StatelessWidget {
  final ValueChanged<int> onNavigateToTab;
  final Future<void> Function()? onRefresh;
  final bool isLoading;

  const AdminDashboardView({
    super.key,
    required this.onNavigateToTab,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // ตัวเลขบนการ์ดอัปเดตตามข้อมูลใน controller
    return ListenableBuilder(
      listenable: Listenable.merge([
        UserController.instance,
        ProductController.instance,
        StatsController.instance,
      ]),
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    // ตัวเลขทั้งระบบจาก GET /api/stats/system (ทุกผู้ใช้ ไม่ใช่แค่ตู้ของ admin)
    final system = StatsController.instance.system;
    final totalUsers =
        system.totalUsers ?? UserController.instance.users.length;
    final totalBarcodes =
        system.totalProducts ?? ProductController.instance.products.length;
    final inventoryItems = system.active.quantity;
    final expiredItems = system.expired.batches;
    final adminName = AuthController.instance.currentUser?.username ?? 'Admin';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.menu, size: 28),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Wrap(
                        children: [
                          const ListTile(
                            title: Text(
                              'Admin navigation',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.home_rounded),
                            title: const Text('Dashboard'),
                            onTap: () {
                              Navigator.pop(context);
                              onNavigateToTab(0);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.assignment_outlined),
                            title: const Text('Catalog'),
                            onTap: () {
                              Navigator.pop(context);
                              onNavigateToTab(1);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.people_outline_rounded),
                            title: const Text('Users'),
                            onTap: () {
                              Navigator.pop(context);
                              onNavigateToTab(2);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.insert_chart_outlined),
                            title: const Text('Analytics'),
                            onTap: () {
                              Navigator.pop(context);
                              onNavigateToTab(3);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Refresh dashboard',
                    onPressed: isLoading ? null : onRefresh,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.notifications_none_rounded, size: 28),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Notifications'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange),
                                title: Text(
                                    '$expiredItems batch${expiredItems == 1 ? ' is' : 'es are'} expired'),
                                subtitle: const Text('Review inventory status'),
                              ),
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.person_add_alt_1,
                                    color: Color(0xFF0D7A53)),
                                title: Text('New users this month'),
                                subtitle:
                                    Text('Check the user management page'),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Admin profile',
                    onSelected: (value) {
                      if (value == 'profile') {
                        showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Admin profile'),
                            content: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFDCFCE7),
                                child: Text(adminName[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Color(0xFF0D7A53))),
                              ),
                              title: Text(adminName),
                              subtitle: const Text('Administrator account'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  final shouldLogout = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Log out?'),
                                      content: const Text(
                                        'Are you sure you want to log out?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Log out'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (shouldLogout != true ||
                                      !context.mounted) {
                                    return;
                                  }
                                  try {
                                    await AuthController.instance.logout();
                                  } on StateError catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(error.message)));
                                    }
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const LoginView(),
                                    ),
                                    (route) => false,
                                  );
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text('Log out'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'profile',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.account_circle_outlined),
                          title: Text('Profile'),
                        ),
                      ),
                    ],
                    child: CircleAvatar(
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Text(
                        adminName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF0D7A53),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D7A53), Color(0xFF075E41)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D7A53).withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ADMIN CONSOLE',
                  style: TextStyle(
                    color: Color(0xFFD1FAE5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Welcome back, $adminName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Here is what is happening across ShelfLife today.',
                  style: TextStyle(color: Color(0xFFE7F7EF), fontSize: 14),
                ),
                const SizedBox(height: 18),
                FilledButton.tonalIcon(
                  onPressed: () => onNavigateToTab(1),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Manage catalog'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF075E41),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'System at a glance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Live overview',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          GridView.extent(
            maxCrossAxisExtent: 240,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _buildStatCard(
                icon: Icons.people_outline_rounded,
                iconBgColor: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF0D7A53),
                value: '$totalUsers',
                label: 'Total Users',
              ),
              _buildStatCard(
                icon: Icons.qr_code_2_rounded,
                iconBgColor: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF0D7A53),
                value: '$totalBarcodes',
                label: 'Global Barcodes',
              ),
              _buildStatCard(
                icon: Icons.widgets_outlined,
                iconBgColor: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                value: '$inventoryItems',
                label: 'Inventory Items',
              ),
              _buildStatCard(
                icon: Icons.warning_amber_rounded,
                iconBgColor: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                value: '$expiredItems',
                label: 'Expired Items',
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Quick Actions Title
          const Text(
            'Quick Actions',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 16),

          // Quick Action Buttons
          _buildQuickActionButton(
            icon: Icons.qr_code_2_rounded,
            title: 'Manage Barcode Catalog',
            onTap: () => onNavigateToTab(1),
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            icon: Icons.people_outline_rounded,
            title: 'User Management',
            onTap: () => onNavigateToTab(2),
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            icon: Icons.insert_chart_outlined_rounded,
            title: 'System Overview',
            onTap: () => onNavigateToTab(3),
          ),
        ],
      ),
    );
  }

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
            color: Colors.black.withValues(alpha: 0.03),
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

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF0D7A53), size: 26),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: Colors.grey),
      ),
    );
  }
}
