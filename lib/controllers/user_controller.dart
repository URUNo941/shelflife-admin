import 'package:flutter/foundation.dart';

import '../models/mock_data.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';

/// Controller จัดการผู้ใช้ (หน้า User Management) เก็บข้อมูลในหน่วยความจำ
class UserController extends ChangeNotifier {
  UserController({List<UserModel>? seed})
      : _seed = seed,
        _users = [...(seed ?? MockData.users())] {
    _nextId = _computeNextId();
  }

  /// instance กลางที่หน้าจอใช้ร่วมกัน (Login, Register, Admin)
  static final UserController instance = UserController();

  final List<UserModel>? _seed;
  final List<UserModel> _users;
  late int _nextId;

  List<UserModel> get users => List.unmodifiable(_users);
  int get adminCount => _users.where((u) => u.isAdmin).length;

  int _computeNextId() => _users.fold(0, (m, u) => u.userId > m ? u.userId : m) + 1;

  static String _key(String username) => username.trim().toLowerCase();

  UserModel? findByUsername(String username) {
    final key = _key(username);
    for (final user in _users) {
      if (_key(user.username) == key) return user;
    }
    return null;
  }

  UserModel? findById(int userId) {
    for (final user in _users) {
      if (user.userId == userId) return user;
    }
    return null;
  }

  bool exists(String username) => findByUsername(username) != null;

  /// ค้นหาตามชื่อ/บทบาท และกรองตามบทบาท ('All' | 'Admin' | 'User')
  List<UserModel> search({String query = '', String role = 'All'}) {
    final q = query.trim().toLowerCase();
    return _users.where((u) {
      final matchesSearch =
          '${u.username} ${u.roleLabel}'.toLowerCase().contains(q);
      final matchesRole = role == 'All' || u.roleLabel == role;
      return matchesSearch && matchesRole;
    }).toList();
  }

  /// คืนข้อความ error ถ้าชื่อผู้ใช้ใช้ไม่ได้ หรือ null ถ้าใช้ได้
  String? validateNewUsername(String username) {
    final name = username.trim();
    if (name.isEmpty) return 'Enter a username';
    if (exists(name)) return 'Username already exists';
    return null;
  }

  /// เพิ่มผู้ใช้ใหม่ไว้บนสุดของรายการ คืน error หรือ null ถ้าสำเร็จ
  String? add({
    required String username,
    String role = UserModel.roleUser,
    String email = '',
  }) {
    final error = validateNewUsername(username);
    if (error != null) return error;
    _users.insert(
      0,
      UserModel(
        userId: _nextId++,
        username: username.trim(),
        email: email.trim(),
        role: UserModel.normalizeRole(role),
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return null;
  }

  /// เปลี่ยนบทบาท ห้ามลดสิทธิ์ admin คนสุดท้าย
  String? changeRole(int userId, String role) {
    final index = _users.indexWhere((u) => u.userId == userId);
    if (index < 0) return 'User not found';
    final user = _users[index];
    final newRole = UserModel.normalizeRole(role);
    if (user.isAdmin && newRole == UserModel.roleUser && adminCount == 1) {
      return 'The last administrator cannot be demoted';
    }
    _users[index] = user.copyWith(role: newRole);
    notifyListeners();
    return null;
  }

  /// ลบผู้ใช้ ห้ามลบ admin คนสุดท้าย
  String? delete(int userId) {
    final user = findById(userId);
    if (user == null) return 'User not found';
    if (user.isAdmin && adminCount == 1) {
      return 'The last administrator cannot be deleted';
    }
    _users.removeWhere((u) => u.userId == userId);
    notifyListeners();
    return null;
  }

  // ---------------------------------------------------------------------------
  // เวอร์ชัน async ที่หน้าจอเรียก: ถ้าเปิด API จะไปที่ /api/users (admin เท่านั้น)
  // ไม่งั้นใช้ข้อมูลในหน่วยความจำ (method sync ด้านบน)
  // ---------------------------------------------------------------------------
  ApiClient get _api => ApiClient.instance;
  bool get _online => _api.enabled;

  /// ดึงรายชื่อผู้ใช้ล่าสุดจาก backend
  Future<String?> load() async {
    if (!_online) return null;
    try {
      final rows = await _api.get('/users') as List;
      _users
        ..clear()
        ..addAll(rows.map((r) => UserModel.fromJson(r as Map<String, dynamic>)));
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> create({
    required String username,
    String role = UserModel.roleUser,
    String email = '',
    String password = '',
  }) async {
    if (!_online) return add(username: username, role: role, email: email);
    final error = validateNewUsername(username);
    if (error != null) return error;
    if (password.length < 6) return 'Password must be at least 6 characters';
    try {
      final row = await _api.post('/users', {
        'username': username.trim(),
        if (email.trim().isNotEmpty) 'email': email.trim(),
        'password': password,
        'role': UserModel.normalizeRole(role),
      });
      _users.insert(0, UserModel.fromJson(row as Map<String, dynamic>));
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> setRole(int userId, String role) async {
    if (!_online) return changeRole(userId, role);
    try {
      final row = await _api.put('/users/$userId', {
        'role': UserModel.normalizeRole(role),
      });
      final index = _users.indexWhere((u) => u.userId == userId);
      if (index >= 0) _users[index] = UserModel.fromJson(row as Map<String, dynamic>);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> remove(int userId) async {
    if (!_online) return delete(userId);
    try {
      await _api.delete('/users/$userId');
      _users.removeWhere((u) => u.userId == userId);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// ล้างข้อมูลตอน logout (โหมด API)
  void clearCache() {
    _users.clear();
    notifyListeners();
  }

  /// คืนค่าข้อมูลเริ่มต้น (ใช้ใน test)
  void reset() {
    _users
      ..clear()
      ..addAll(_seed ?? MockData.users());
    _nextId = _computeNextId();
    notifyListeners();
  }
}
