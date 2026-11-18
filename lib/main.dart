import 'package:flutter/material.dart';
import 'package:myapp/controllers/auth_controller.dart';
import 'package:myapp/services/api_client.dart';
import 'package:myapp/views/user/login_view.dart';
import 'package:myapp/views/user/user_main_view.dart';
import 'package:myapp/views/admin/admin_main_view.dart';

void main() {
  // แอปจริงคุยกับ backend (Node.js + MySQL) ผ่าน API
  // เปลี่ยนที่อยู่ได้ด้วย --dart-define=API_BASE_URL=http://<ip>:3000/api
  ApiClient.instance.enable();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShelfLife',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0D7A53),
        useMaterial3: true,
      ),
      home: const _SessionGate(),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late Future<String?> _restore;
  bool _signInInstead = false;

  @override
  void initState() {
    super.initState();
    _restore = AuthController.instance.restoreSession();
  }

  void _retry() {
    setState(() {
      _signInInstead = false;
      _restore = AuthController.instance.restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_signInInstead) return const LoginView();

    return FutureBuilder<String?>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data != null) {
          final message = snapshot.hasError
              ? 'Could not restore your sign-in: ${snapshot.error}'
              : snapshot.data!;
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 44),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Try again'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _signInInstead = true),
                      child: const Text('Sign in instead'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final user = AuthController.instance.currentUser;
        if (user == null) return const LoginView();
        return user.isAdmin ? const AdminMainView() : const UserMainView();
      },
    );
  }
}
