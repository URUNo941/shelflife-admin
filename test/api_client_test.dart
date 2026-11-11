import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/services/api_client.dart';

void main() {
  test(
      'login stores real session, inventory sends bearer token, logout clears it',
      () async {
    final requests = <http.Request>[];
    final api = ApiClient(client: MockClient((r) async {
      requests.add(r);
      if (r.url.path.endsWith('/login')) {
        return http.Response(
            jsonEncode({
              'token': 'test-token',
              'user': {'user_id': 3, 'role': 'user'}
            }),
            200);
      }
      return http.Response('[]', 200);
    }));
    await api.login('alice', 'password');
    expect(jsonDecode(requests.first.body)['username'], 'alice');
    await api.request('GET', '/me/inventory');
    expect(requests.last.headers['Authorization'], 'Bearer test-token');
    api.logout();
    expect(api.token, isNull);
    expect(api.user, isNull);
  });
  test('401 expires session; failed writes report server message', () async {
    final api = ApiClient(
        client: MockClient((_) async =>
            http.Response('{"message":"Account unavailable."}', 401)));
    api.token = 'expired';
    api.user = {'user_id': 1};
    await expectLater(
        api.request('POST', '/me/inventory', {'quantity': 2}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Account unavailable.')));
    expect(api.token, isNull);
    expect(api.user, isNull);
  });
}
