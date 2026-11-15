import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/api_client.dart';
import 'product_controller.dart';
import 'stats_controller.dart';
import 'user_controller.dart';
import 'user_inventory_controller.dart';

/// Controller ล็อกอิน / สมัครสมาชิก / ออกจากระบบ
///
/// - แอปจริง (ApiClient เปิดใช้): ส่งไป `/api/auth/login` และ `/api/auth/register`
///   backend ตรวจรหัสผ่านด้วย argon2id แล้วคืน JWT มา เก็บไว้ใน [ApiClient.token]
/// - ตอน test (ApiClient ปิด): ใช้ข้อมูลในหน่วยความจำ ผู้ใช้ตัวอย่างใช้รหัส [demoPassword]
class AuthController extends ChangeNotifier {
  AuthController({UserController? users, ApiClient? api})
      : _users = users ?? UserController.instance,
        _api = api;

  static final AuthController instance = AuthController();
  static const demoPassword = '1234';

  final UserController _users;
  final ApiClient? _api;
  final Map<String, String> _passwords = {};
  UserModel? _currentUser;

  ApiClient get _client => _api ?? ApiClient.instance;
  bool get _online => _client.enabled;

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

  // ---------------------------------------------------------------------------
  // ใช้จากหน้าจอ (async): เลือกเองว่าจะไป API หรือใช้ข้อมูลในหน่วยความจำ
  // ---------------------------------------------------------------------------

  /// คืน null ถ้าสำเร็จ หรือข้อความ error
  Future<String?> signIn(String username, String password) async {
    if (!_online) {
      return login(username, password) == null
          ? 'Invalid username or password'
          : null;
    }
    try {
      final data = await _client.post('/auth/login', {
        'username': username.trim(),
        'password': password,
      });
      _client.token = data['token'] as String;
      _currentUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.statusCode == 401 ? 'Invalid username or password' : e.message;
    }
  }

  /// สมัครสมาชิก (role = user เสมอ) คืน null ถ้าสำเร็จ หรือข้อความ error
  Future<String?> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final error = validateUsername(username) ??
        validateEmail(email) ??
        validatePassword(password);
    if (error != null) return error;
    if (!_online) {
      return register(username: username, email: email, password: password);
    }
    try {
      await _client.post('/auth/register', {
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
      });
      return null; // ให้ผู้ใช้ไป login เองที่หน้า Login
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// ออกจากระบบ: ทิ้ง token และล้างข้อมูลของผู้ใช้คนเดิมออกจากหน่วยความจำ
  void logout() {
    _currentUser = null;
    if (_online) {
      _client.token = null;
      UserInventory.instance.clear();
      StatsController.instance.clear();
      ProductController.instance.clearCache();
      UserController.instance.clearCache();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // โหมดในหน่วยความจำ (sync) ใช้ใน test และตอนยังไม่ต่อ backend
  // ---------------------------------------------------------------------------

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
}
