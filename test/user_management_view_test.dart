import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/views/admin/user_management_view.dart';

void main() {
  Future<void> openUserManagement(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: UserManagementView()),
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
