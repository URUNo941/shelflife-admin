import 'package:flutter/material.dart';
import 'api_admin_view.dart';

class SystemAnalyticsView extends StatelessWidget {
  const SystemAnalyticsView({super.key});
  @override
  Widget build(BuildContext context) => ApiAdminView(kind: 'analytics');
}
