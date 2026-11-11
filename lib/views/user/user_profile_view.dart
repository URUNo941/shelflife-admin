import 'package:flutter/material.dart';

import 'login_view.dart';
import 'user_data.dart';

/// ข้อมูลบัญชีผู้ใช้ (mock) ตอนต่อ API ให้แปลงข้อมูลที่ได้หลัง login เป็น class นี้
class UserAccount {
  final String username;
  final String email;
  final String role;
  final String joined;
  const UserAccount({
    required this.username,
    required this.email,
    required this.role,
    required this.joined,
  });

  static const mock = UserAccount(
    username: 'sarah',
    email: 'sarah@example.com',
    role: 'User',
    joined: 'Oct 5, 2026',
  );
}

/// หน้าบัญชีของฉัน: แสดงข้อมูลบัญชี + ปุ่ม Log out
class UserProfileView extends StatelessWidget {
  final UserAccount account;

  /// เรียกหลังผู้ใช้กดยืนยัน Log out
  /// ถ้าไม่ส่งมา จะย้อนกลับไปหน้าแรกของแอป (มักเป็นหน้า Login)
  /// ถ้าอยากไปหน้า Login ตรง ๆ ส่งเข้ามา เช่น
  /// onLogout: () => Navigator.pushAndRemoveUntil(context,
  ///   MaterialPageRoute(builder: (_) => const LoginView()), (r) => false)
  final VoidCallback? onLogout;

  const UserProfileView({
    super.key,
    this.account = UserAccount.mock,
    this.onLogout,
  });

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
    final initials = account.username.isEmpty
        ? '?'
        : account.username.substring(0, 1).toUpperCase();

    return ListenableBuilder(
      listenable: UserInventory.instance,
      builder: (context, _) {
        final count = UserInventory.instance.items
            .fold<int>(0, (total, item) => total + item.qty);
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
              Text(account.email,
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
                  _row(Icons.email_outlined, 'Email', account.email),
                  const Divider(height: 1),
                  _row(Icons.badge_outlined, 'Role', account.role),
                  const Divider(height: 1),
                  _row(Icons.calendar_today_outlined, 'Joined', account.joined),
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
