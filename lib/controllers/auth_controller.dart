import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'user_controller.dart';

/// Controller ล็อกอิน / สมัครสมาชิก แบบ mock (ยังไม่ต่อ API)
///
/// ผู้ใช้ที่มีอยู่แล้วใช้รหัสผ่านทดลอง [demoPassword]
/// ผู้ใช้ที่สมัครใหม่ใช้รหัสผ่านที่ตั้งตอนสมัคร
class AuthController extends ChangeNotifier {
  AuthController({UserController? users})
      : _users = users ?? UserController.instance;

  static final AuthController instance = AuthController();
  static const demoPassword = '1234';

  final UserController _users;
  final Map<String, String> _passwords = {};
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  static String _key(String username) => username.trim().toLowerCase();

  static String? validateUsername(String username) {
    final name = username.trim();
    if (name.isEmpty) return 'Please enter a username';
    if (name.length < 3) return 'At least 3 characters';
    return null;
  }

  static String? validateEmail(String email) {
    final value = email.trim();
    if (value.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Invalid email';
    }
    return null;
  }

  static String? validatePassword(String password) {
    if (password.isEmpty) return 'Please enter a password';
    if (password.length < 6) return 'At least 6 characters';
    return null;
  }

  /// คืนผู้ใช้ที่ล็อกอินสำเร็จ หรือ null ถ้าชื่อ/รหัสผ่านไม่ถูก
  UserModel? login(String username, String password) {
    final user = _users.findByUsername(username);
    if (user == null) return null;
    final expected = _passwords[_key(username)] ?? demoPassword;
    if (password != expected) return null;
    _currentUser = user;
    notifyListeners();
    return user;
  }

  /// สมัครสมาชิก คืนข้อความ error หรือ null ถ้าสำเร็จ
  String? register({
    required String username,
    required String email,
    required String password,
  }) {
    final error = validateUsername(username) ??
        validateEmail(email) ??
        validatePassword(password);
    if (error != null) return error;
    final addError = _users.add(username: username, email: email);
    if (addError != null) return addError;
    _passwords[_key(username)] = password;
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
