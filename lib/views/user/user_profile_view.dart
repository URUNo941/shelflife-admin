import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';
import 'login_view.dart';
import 'user_data.dart';

/// หน้าบัญชีของฉัน: แสดงข้อมูลบัญชี + ปุ่ม Log out
class UserProfileView extends StatelessWidget {
  /// ถ้าไม่ส่งมา ใช้ผู้ใช้ที่ล็อกอินอยู่ใน [AuthController]
  final UserModel? account;

  /// เรียกหลังผู้ใช้กดยืนยัน Log out
  /// ถ้าไม่ส่งมา จะย้อนกลับไปหน้าแรกของแอป (มักเป็นหน้า Login)
  /// ถ้าอยากไปหน้า Login ตรง ๆ ส่งเข้ามา เช่น
  /// onLogout: () => Navigator.pushAndRemoveUntil(context,
  ///   MaterialPageRoute(builder: (_) => const LoginView()), (r) => false)
  final VoidCallback? onLogout;

  const UserProfileView({
    super.key,
    this.account,
    this.onLogout,
  });

  static final _guest = UserModel(
    userId: 0,
    username: 'guest',
    role: UserModel.roleUser,
    createdAt: DateTime.now(),
  );

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFFEE2E2),
          child: Icon(Icons.logout, color: Color(0xFFDC2626)),
        ),
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to see your items.',
            textAlign: TextAlign.center),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    AuthController.instance.logout();
    if (onLogout != null) {
      onLogout!();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginView()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account =
        this.account ?? AuthController.instance.currentUser ?? _guest;
    final initials = account.username.isEmpty
        ? '?'
        : account.username.substring(0, 1).toUpperCase();

    return ListenableBuilder(
      listenable: UserInventory.instance,
      builder: (context, _) {
        final count = UserInventory.instance.totalQuantity;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFFDCFCE7),
                child: Text(initials,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: kUserGreen)),
              ),
              const SizedBox(height: 12),
              Text(account.username,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              Text(account.email.isEmpty ? '-' : account.email,
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(children: [
                  _row(Icons.person_outline, 'Username', account.username),
                  const Divider(height: 1),
                  _row(Icons.email_outlined, 'Email', account.email.isEmpty ? '-' : account.email),
                  const Divider(height: 1),
                  _row(Icons.badge_outlined, 'Role', account.roleLabel),
                  const Divider(height: 1),
                  _row(Icons.calendar_today_outlined, 'Joined', account.joinedLabel),
                  const Divider(height: 1),
                  _row(Icons.inventory_2_outlined, 'Items on my shelf',
                      '$count'),
                ]),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                ),
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: kUserGreen),
      title: Text(label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      subtitle: Text(value,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87)),
    );
  }
}
