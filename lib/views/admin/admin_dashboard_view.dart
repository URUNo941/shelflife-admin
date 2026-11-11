
import 'package:flutter/material.dart';
import '../user/login_view.dart' show LoginView;

class AdminDashboardView extends StatelessWidget {
  final ValueChanged<int> onNavigateToTab;

  const AdminDashboardView({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
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
                    icon: const Icon(Icons.notifications_none_rounded, size: 28),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Notifications'),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange),
                                title: Text('42 items are expired'),
                                subtitle: Text('Review inventory status'),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.person_add_alt_1,
                                    color: Color(0xFF0D7A53)),
                                title: Text('New users this month'),
                                subtitle: Text('Check the user management page'),
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
                            content: const ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: Color(0xFFDCFCE7),
                                child: Text('A',
                                    style: TextStyle(
                                        color: Color(0xFF0D7A53))),
                              ),
                              title: Text('Admin'),
                              subtitle: Text('Administrator account'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  final shouldLogout =
                                      await showDialog<bool>(
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
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Text(
                        'A',
                        style: TextStyle(
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
          const SizedBox(height: 16),

          // Title Section
          const Text(
            'Admin Console',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome back,',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const Text(
            'Admin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 24),

          // Stat Cards Grid
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
                value: '1,240',
                label: 'Inventory Items',
              ),
              _buildStatCard(
                icon: Icons.warning_amber_rounded,
                iconBgColor: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                value: '42',
                label: 'Expired Items',
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Quick Actions Title
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
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
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF0D7A53), size: 26),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
      ),
    );
  }
}