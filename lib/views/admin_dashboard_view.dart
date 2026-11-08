// เปลื่ยนเป็นหน้า user
//
//
import 'package:flutter/material.dart';

class AdminDashboardView extends StatelessWidget {
  final Function(int) onNavigateToCatalog;

  const AdminDashboardView({super.key, required this.onNavigateToCatalog});

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
                onPressed: () {},
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, size: 28),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                  const CircleAvatar(
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
            onTap: () => onNavigateToCatalog(1), // สลับไปหน้า Catalog
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            icon: Icons.people_outline_rounded,
            title: 'User Management',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            icon: Icons.insert_chart_outlined_rounded,
            title: 'System Overview',
            onTap: () {},
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