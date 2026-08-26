import 'package:agendamento_app/app/models/app_notification.dart';
import 'package:agendamento_app/app/models/chat_conversation.dart';
import 'package:agendamento_app/app/screens/chat_page.dart';
import 'package:agendamento_app/app/services/notification_history_service.dart';
import 'package:agendamento_app/app/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  final String userId;

  const NotificationsPage({super.key, required this.userId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationHistoryService _service = NotificationHistoryService();
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.markAllAsRead(widget.userId);
    });
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmDialog(
        title: 'Limpar notificações',
        content: Text('Deseja apagar todo o histórico de notificações?'),
        cancelLabel: 'Cancelar',
        confirmLabel: 'Limpar',
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await _service.clearAll(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Histórico de notificações limpo.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível limpar: $error')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  void _openChat(AppNotification notification) {
    final conversationId = notification.conversationId;
    final barberId = notification.barberId;
    final clientId = notification.clientId;
    final barbershopId = notification.barbershopId;
    final barbershopName = notification.barbershopName;
    final clientName = notification.clientName;
    if (conversationId == null ||
        barberId == null ||
        clientId == null ||
        barbershopId == null ||
        barbershopName == null ||
        clientName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Esta conversa não está mais disponível.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          conversation: ChatConversation(
            id: conversationId,
            barberId: barberId,
            clientId: clientId,
            barbershopId: barbershopId,
            barbershopName: barbershopName,
            clientName: clientName,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _service.watchNotifications(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _NotificationState(
              icon: Icons.cloud_off_rounded,
              title: 'Não foi possível carregar',
              message: 'Verifique sua conexão e tente novamente.',
              color: colors.error,
            );
          }

          final notifications = snapshot.data ?? const <AppNotification>[];
          if (notifications.isEmpty) {
            return _NotificationState(
              icon: Icons.notifications_none_rounded,
              title: 'Tudo tranquilo por aqui',
              message: 'Novos agendamentos, cancelamentos e pagamentos '
                  'aparecerão neste espaço.',
              color: colors.primary,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                currentUserId: widget.userId,
                onTap: notification.type == 'message_received'
                    ? () => _openChat(notification)
                    : null,
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: OutlinedButton.icon(
          onPressed: _clearing ? null : _clear,
          icon: _clearing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_sweep_outlined),
          label: Text(_clearing ? 'Limpando...' : 'Limpar'),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final String currentUserId;
  final VoidCallback? onTap;

  const _NotificationCard({
    required this.notification,
    required this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visual = _visualFor(notification.type, colors);
    return Card(
      color: notification.isRead
          ? colors.surfaceContainerLowest
          : colors.primaryContainer.withValues(alpha: 0.48),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(visual.icon, color: visual.color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_notificationBody()),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(notification.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (onTap != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.reply_rounded, size: 18),
                          label: const Text('Abrir conversa'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _notificationBody() {
    if (notification.type != 'appointment_cancelled' ||
        notification.actorId.isEmpty) {
      return notification.body;
    }
    if (notification.actorId == currentUserId) {
      return 'Você cancelou este agendamento.';
    }
    if (notification.id.endsWith('_cancelled_client')) {
      return 'A barbearia cancelou este agendamento.';
    }
    if (notification.id.endsWith('_cancelled_barber')) {
      return 'O cliente cancelou este agendamento.';
    }
    return notification.body;
  }

  ({IconData icon, Color color}) _visualFor(
    String type,
    ColorScheme colors,
  ) {
    return switch (type) {
      'appointment_created' => (
          icon: Icons.event_available_rounded,
          color: colors.primary,
        ),
      'appointment_cancelled' => (
          icon: Icons.event_busy_rounded,
          color: colors.error,
        ),
      'payment_received' || 'payment_approved' => (
          icon: Icons.payments_rounded,
          color: const Color(0xFF238B57),
        ),
      'appointment_completed' => (
          icon: Icons.task_alt_rounded,
          color: colors.tertiary,
        ),
      'message_received' => (
          icon: Icons.mark_chat_unread_rounded,
          color: colors.secondary,
        ),
      _ => (icon: Icons.notifications_rounded, color: colors.primary),
    };
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Agora';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final time = DateFormat('HH:mm').format(value);
    if (date == today) return 'Hoje, $time';
    if (date == today.subtract(const Duration(days: 1))) {
      return 'Ontem, $time';
    }
    return DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(value);
  }
}

class _NotificationState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _NotificationState({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 34),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
