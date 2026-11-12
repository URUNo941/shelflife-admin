import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/controllers/user_controller.dart';
import 'package:myapp/models/user_model.dart';
import 'package:myapp/views/admin/user_management_view.dart';

void main() {
  // แต่ละ test ได้ controller ใหม่ ข้อมูลจึงไม่ปนกันระหว่าง test
  UserController freshController() => UserController(seed: [
        for (final (id, name, role) in [
          (1, 'tom123', UserModel.roleAdmin),
          (2, 'sarah', UserModel.roleUser),
          (3, 'john', UserModel.roleUser),
          (4, 'patlee', UserModel.roleUser),
        ])
          UserModel(
            userId: id,
            username: name,
            role: role,
            createdAt: DateTime(2026, 10, id),
          ),
      ]);

  Future<void> openUserManagement(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: UserManagementView(controller: freshController())),
    );
  }

  testWidgets('admin can add a user to the local list', (tester) async {
    await openUserManagement(tester);

    await tester.tap(find.text('Add User'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'newuser');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('newuser'), findsOneWidget);
    expect(find.text('User added'), findsOneWidget);
  });

  testWidgets('admin can change a user role', (tester) async {
    await openUserManagement(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Role'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.ancestor(of: find.text('sarah'), matching: find.byType(Row)),
        matching: find.text('Admin'),
      ),
      findsOneWidget,
    );
    expect(find.text('User updated'), findsOneWidget);
  });

  testWidgets('last administrator cannot be demoted', (tester) async {
    await openUserManagement(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Role'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('User').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
        find.text('The last administrator cannot be demoted'), findsOneWidget);
    expect(find.text('tom123'), findsOneWidget);
  });
}
