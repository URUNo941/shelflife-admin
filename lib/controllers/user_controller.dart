import 'api_client.dart';
import '../models/auth_session_model.dart';
import '../models/user_model.dart';

class UserController {
  UserController({ApiClient apiClient = const ApiClient()}) : _api = apiClient;

  final ApiClient _api;

  Future<AuthSessionModel> login({
    required String username,
    required String password,
  }) async {
    final response = await _api.post('/auth/login', {
      'username': username,
      'password': password,
    });
    _api.expectStatus(response, 200);
    return AuthSessionModel.fromJson(
      Map<String, dynamic>.from(_api.decode(response) as Map),
    );
  }

  Future<List<UserModel>> getUsers() async {
    final response = await _api.get('/users');
    _api.expectStatus(response, 200);
    final data = _api.decode(response) as List<dynamic>;
    return data
        .map((json) => UserModel.fromJson(
              Map<String, dynamic>.from(json as Map),
            ))
        .toList();
  }

  Future<UserModel> getUser(int userId) async {
    final response = await _api.get('/users/$userId');
    _api.expectStatus(response, 200);
    return UserModel.fromJson(
      Map<String, dynamic>.from(_api.decode(response) as Map),
    );
  }

  Future<UserModel> addUser({
    required String username,
    required String password,
    String role = 'user',
  }) async {
    final response = await _api.post('/users', {
      'username': username,
      'password': password,
      'role': role,
    });
    _api.expectStatus(response, 201);
    return UserModel.fromJson(
      Map<String, dynamic>.from(_api.decode(response) as Map),
    );
  }

  Future<UserModel> updateUser(
    int userId, {
    String? username,
    String? password,
    String? role,
  }) async {
    final response = await _api.patch('/users/$userId', {
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (role != null) 'role': role,
    });
    _api.expectStatus(response, 200);
    return UserModel.fromJson(
      Map<String, dynamic>.from(_api.decode(response) as Map),
    );
  }

  Future<void> deleteUser(int userId) async {
    final response = await _api.delete('/users/$userId');
    _api.expectStatus(response, 204);
  }
}
