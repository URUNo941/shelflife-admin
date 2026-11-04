import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  const ApiClient({
    this.baseUrl = 'http://localhost:3000/api',
    this.accessToken,
  });

  final String baseUrl;
  final String? accessToken;

  Future<http.Response> get(String path) =>
      http.get(_uri(path), headers: _headers);

  Future<http.Response> post(String path, Map<String, dynamic> body) =>
      http.post(_uri(path), headers: _headers, body: jsonEncode(body));

  Future<http.Response> patch(String path, Map<String, dynamic> body) =>
      http.patch(_uri(path), headers: _headers, body: jsonEncode(body));

  Future<http.Response> delete(String path) =>
      http.delete(_uri(path), headers: _headers);

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  void expectStatus(http.Response response, int expectedStatus) {
    if (response.statusCode == expectedStatus) return;

    var detail = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        detail = decoded['message'] as String;
      }
    } on FormatException {
      // Keep the response body as the error detail when it is not JSON.
    }
    throw Exception('Request failed (${response.statusCode}): $detail');
  }

  dynamic decode(http.Response response) => jsonDecode(response.body);
}
