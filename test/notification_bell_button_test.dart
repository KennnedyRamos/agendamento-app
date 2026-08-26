import 'package:agendamento_app/app/widgets/notification_bell_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the unread notification count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              NotificationBellButton(
                userId: 'user-id',
                unreadCountStream: Stream.value(7),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
  });

  testWidgets('limits a large unread count to 99+', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              NotificationBellButton(
                userId: 'user-id',
                unreadCountStream: Stream.value(120),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('99+'), findsOneWidget);
  });
}
