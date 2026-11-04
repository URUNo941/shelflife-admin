import 'package:flutter/material.dart';
import 'admin_dashboard_view.dart';
import 'master_catalog_view.dart';
import 'user_management_view.dart';
import 'system_analytics_view.dart'; // <-- 1. เพิ่ม import ไฟล์ใหม่

class AdminMainView extends StatefulWidget {
  const AdminMainView({super.key});

  @override
  State<AdminMainView> createState() => _AdminMainViewState();
}

class _AdminMainViewState extends State<AdminMainView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      AdminDashboardView(
        onNavigateToCatalog: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      MasterCatalogView(
        onBackToDashboard: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      UserManagementView(
        onBackToDashboard: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      const SystemAnalyticsView(), // <-- 2. เปลี่ยนแท็บที่ 4 เป็น SystemAnalyticsView
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0D7A53),
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Catalog',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart_outlined_rounded),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
