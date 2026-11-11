import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : client = client ?? http.Client();
  static final instance = ApiClient();
  final http.Client client;
  static const baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://localhost:3000/api');
  String? token;
  Map<String, dynamic>? user;
  int _session = 0;
  void logout() {
    token = null;
    user = null;
    _session++;
  }

  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) async {
    final session = _session;
    final req = http.Request(method, Uri.parse('$baseUrl$path'));
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    final response = await http.Response.fromStream(
            await client.send(req).timeout(const Duration(seconds: 15)))
        .timeout(const Duration(seconds: 15));
    if (session != _session) {
      throw ApiException('Session changed. Please sign in again.', 401);
    }
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      throw ApiException('Invalid server response.', response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 && token != null) logout();
      throw ApiException(
          data is Map
              ? data['message']?.toString() ?? 'Request failed.'
              : 'Request failed.',
          response.statusCode);
    }
    return data;
  }

  Future<void> login(String username, String password) async {
    logout();
    final data = await request(
        'POST', '/auth/login', {'username': username, 'password': password});
    token = data['token'] as String;
    user = Map<String, dynamic>.from(data['user']);
  }
}
