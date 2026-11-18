import 'package:flutter/material.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/stats_controller.dart';
import '../../controllers/user_controller.dart';
import 'admin_dashboard_view.dart';
import 'master_catalog_view.dart';
import 'user_management_view.dart';
import 'system_analytics_view.dart';

class AdminMainView extends StatefulWidget {
  const AdminMainView({super.key});

  @override
  State<AdminMainView> createState() => _AdminMainViewState();
}

class _AdminMainViewState extends State<AdminMainView> {
  int _currentIndex = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// โหลดข้อมูลจริงจาก backend ตอนเข้าหน้า admin (โหมด test ไม่ทำอะไร)
  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);
    final errors = await Future.wait([
      UserController.instance.load(),
      ProductController.instance.load(),
    ]);
    await StatsController.instance.loadSystem();
    final error = errors.whereType<String>().firstOrNull ??
        StatsController.instance.lastError;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      AdminDashboardView(
        isLoading: _isLoading,
        onRefresh: _load,
        onNavigateToTab: (index) {
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
      const SystemAnalyticsView(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        indicatorColor: const Color(0xFFDCFCE7),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Catalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
