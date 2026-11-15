import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Error ที่ได้จาก backend (เช่น 401, 409) พร้อมข้อความจาก field "message"
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// จุดเดียวที่แอปคุยกับ backend (Node.js + MySQL)
///
/// - เก็บ JWT หลัง login แล้วแนบ `Authorization: Bearer <token>` ให้ทุก request
/// - [enabled] = false (ค่าเริ่มต้น) controller จะทำงานแบบ in-memory (ใช้ใน unit/widget test)
///   main.dart เรียก [enable] ตอนเปิดแอปจริง ให้ทุกอย่างวิ่งผ่าน API
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? defaultBaseUrl(),
        _client = client ?? http.Client();

  static ApiClient instance = ApiClient();

  /// กำหนดเองได้ตอนรัน: flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api
  static String defaultBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Android emulator มองเครื่องคอมเป็น 10.0.2.2 ส่วน Chrome/Windows ใช้ localhost
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  final String baseUrl;
  final http.Client _client;
  bool enabled = false;
  String? token;

  void enable() => enabled = true;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Content-Type'] = 'application/json; charset=UTF-8';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 10)),
      );
    } catch (_) {
      throw const ApiException(0, 'Cannot connect to the server. Is the backend running?');
    }

    final text = utf8.decode(response.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 400) {
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Request failed (${response.statusCode})';
      throw ApiException(response.statusCode, message);
    }
    return data;
  }
}

/// แปลงวันที่จาก API: "2026-11-05" (DATE) หรือ "2026-11-03T06:27:43.000Z" (TIMESTAMP)
/// เป็นเวลาท้องถิ่นเสมอ จะได้ไม่เพี้ยนวันเพราะ UTC
DateTime parseApiDate(String value) => DateTime.parse(value).toLocal();

/// วันที่ -> "YYYY-MM-DD" สำหรับคอลัมน์ DATE
String formatApiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
