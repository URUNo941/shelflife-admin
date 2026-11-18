import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/api_client.dart';
import 'package:myapp/views/user/user_data.dart';
import 'package:myapp/views/user/user_item_detail_view.dart';
import 'package:myapp/views/user/user_item_form_view.dart';
import 'package:myapp/views/user/user_main_view.dart';
import 'package:myapp/views/user/user_notifications_view.dart';
import 'package:myapp/views/admin/admin_main_view.dart';

void main() {
  final inventory = UserInventory.instance;

  testWidgets('notification opens item details, then edit form',
      (tester) async {
    final today = DateTime.now();
    final item = UserItem(
      id: 'notification-navigation-test',
      barcode: 'notification-navigation-test',
      name: 'Notification Test Milk',
      category: 'Food',
      expiry: DateTime(today.year, today.month, today.day + 2),
    );
    addTearDown(() => inventory.remove(item.id));
    inventory.save(item);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UserNotificationsView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text('Notification Test Milk is expiring soon'), findsOneWidget);
    await tester.tap(find.text('Notification Test Milk is expiring soon'));
    await tester.pumpAndSettle();
    expect(find.byType(UserItemDetailView), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    final editButton = find.text('Edit item');
    expect(editButton, findsOneWidget);
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(find.byType(UserItemFormView), findsOneWidget);
    expect(find.text('Edit Item'), findsOneWidget);
  });

  testWidgets('center add shortcut opens a new item form', (tester) async {
    ApiClient.instance.enabled = false;
    await tester.pumpWidget(const MaterialApp(home: UserMainView()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add item'));
    await tester.pumpAndSettle();

    expect(find.byType(UserItemFormView), findsOneWidget);
    expect(find.text('Add Item'), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
    expect(find.text('Take Picture'), findsOneWidget);
  });

  testWidgets('admin dashboard has refreshed overview and navigation',
      (tester) async {
    ApiClient.instance.enabled = false;
    await tester.pumpWidget(const MaterialApp(home: AdminMainView()));
    await tester.pumpAndSettle();

    expect(find.text('System at a glance'), findsOneWidget);
    expect(find.text('Welcome back, Admin'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('Refresh dashboard'), findsOneWidget);
  });
}
