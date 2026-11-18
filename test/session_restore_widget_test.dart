import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/main.dart';
import 'package:myapp/services/api_client.dart';
import 'package:myapp/views/user/login_view.dart';
import 'package:myapp/views/user/user_main_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('remembered login opens the user area after app reload',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'shelflife.session_token': 'remembered-jwt',
    });
    ApiClient.instance = ApiClient(
      baseUrl: 'http://test/api',
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({
              'user_id': 2,
              'username': 'sarah',
              'email': null,
              'role': 'user',
              'created_at': '2026-11-03T06:27:43.000Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/items') {
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      }),
    )..enable();

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(UserMainView), findsOneWidget);
    expect(find.byType(LoginView), findsNothing);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(UserMainView), findsOneWidget);
    expect(find.byType(LoginView), findsNothing);
  });
}
