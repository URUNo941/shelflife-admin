import 'package:flutter/material.dart';
import 'api_admin_view.dart';

class UserManagementView extends StatelessWidget {
  final VoidCallback? onBackToDashboard;
  const UserManagementView({super.key, this.onBackToDashboard});
  @override
  Widget build(BuildContext context) =>
      ApiAdminView(kind: 'users', onBack: onBackToDashboard);
}
