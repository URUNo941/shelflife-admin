import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _sessionTokenKey = 'shelflife.session_token';

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
  Future<String?> signIn(
    String username,
    String password, {
    bool rememberMe = true,
  }) async {
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
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      try {
        final preferences = await SharedPreferences.getInstance();
        final saved = rememberMe
            ? await preferences.setString(_sessionTokenKey, token)
            : await preferences.remove(_sessionTokenKey);
        if (!saved) return 'Could not save your sign-in preference.';
      } on PlatformException catch (error) {
        return 'Could not save your sign-in preference: ${error.message ?? error.code}';
      } on MissingPluginException catch (error) {
        return 'Could not save your sign-in preference: ${error.message}';
      }
      _client.token = token;
      _currentUser = user;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.statusCode == 401 ? 'Invalid username or password' : e.message;
    }
  }

  /// Restore a remembered session and validate it with the backend.
  /// A network/server failure keeps the saved token so the user can retry.
  Future<String?> restoreSession() async {
    if (!_online) return null;

    final SharedPreferences preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      final savedToken = preferences.getString(_sessionTokenKey);
      if (savedToken == null || savedToken.isEmpty) return null;

      _client.token = savedToken;
      final data = await _client.get('/auth/me');
      _currentUser = UserModel.fromJson(data as Map<String, dynamic>);
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 404) {
        _client.token = null;
        _currentUser = null;
        try {
          await _clearSavedSession();
        } on StateError catch (storageError) {
          return storageError.message;
        }
        notifyListeners();
        return null;
      }
      return error.message;
    } on PlatformException catch (error) {
      return 'Could not restore your saved session: ${error.message ?? error.code}';
    } on MissingPluginException catch (error) {
      return 'Could not restore your saved session: ${error.message}';
    } on FormatException catch (error) {
      _client.token = null;
      _currentUser = null;
      try {
        await _clearSavedSession();
      } on StateError catch (storageError) {
        return storageError.message;
      }
      notifyListeners();
      return 'The saved session is invalid: ${error.message}';
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
  Future<void> logout() async {
    _currentUser = null;
    if (_online) {
      _client.token = null;
      UserInventory.instance.clear();
      StatsController.instance.clear();
      ProductController.instance.clearCache();
      UserController.instance.clearCache();
    }
    notifyListeners();
    if (_online) await _clearSavedSession();
  }

  Future<void> _clearSavedSession() async {
    try {
      final removed =
          await (await SharedPreferences.getInstance()).remove(_sessionTokenKey);
      if (!removed) {
        throw StateError('Could not clear the saved sign-in session.');
      }
    } on PlatformException catch (error) {
      throw StateError(
        'Could not clear the saved sign-in session: ${error.message ?? error.code}',
      );
    } on MissingPluginException catch (error) {
      throw StateError(
        'Could not clear the saved sign-in session: ${error.message}',
      );
    }
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
