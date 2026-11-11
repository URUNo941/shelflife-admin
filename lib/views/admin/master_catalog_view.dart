import 'package:flutter/material.dart';
import 'api_admin_view.dart';

class MasterCatalogView extends StatelessWidget {
  final VoidCallback? onBackToDashboard;
  const MasterCatalogView({super.key, this.onBackToDashboard});
  @override
  Widget build(BuildContext context) =>
      ApiAdminView(kind: 'products', onBack: onBackToDashboard);
}
