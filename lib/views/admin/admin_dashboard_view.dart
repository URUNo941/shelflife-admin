import 'package:flutter/material.dart';
import 'api_admin_view.dart';

class AdminDashboardView extends StatelessWidget {
  final ValueChanged<int>? onNavigateToTab;
  const AdminDashboardView({super.key, this.onNavigateToTab});
  @override
  Widget build(BuildContext context) => ApiAdminView(kind: 'dashboard');
}
