import 'package:agendamento_app/app/screens/notifications_page.dart';
import 'package:agendamento_app/app/services/notification_history_service.dart';
import 'package:flutter/material.dart';

class NotificationBellButton extends StatelessWidget {
  final String userId;
  final Stream<int>? unreadCountStream;

  const NotificationBellButton({
    super.key,
    required this.userId,
    this.unreadCountStream,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<int>(
      stream: unreadCountStream ??
          NotificationHistoryService().watchUnreadCount(userId),
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          tooltip: count > 0 ? '$count notificações não lidas' : 'Notificações',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationsPage(userId: userId),
              ),
            );
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                count > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
              ),
              if (count > 0)
                Positioned(
                  top: -7,
                  right: -9,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: colors.error,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.surface, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: TextStyle(
                        color: colors.onError,
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
