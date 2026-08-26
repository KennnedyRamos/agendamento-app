import 'package:agendamento_app/app/services/appointment_service.dart';
import 'package:agendamento_app/app/utils/cancellation_utils.dart';
import 'package:agendamento_app/app/widgets/confirm_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class BarberDashboardTab extends StatefulWidget {
  final VoidCallback? onOpenAgenda;

  const BarberDashboardTab({super.key, this.onOpenAgenda});

  @override
  State<BarberDashboardTab> createState() => _BarberDashboardTabState();
}

class _BarberDashboardTabState extends State<BarberDashboardTab> {
  final AppointmentService _appointmentService = AppointmentService();
  bool _completingAppointment = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR');
  }

  Future<void> _completeAppointment(_RoutineAppointment appointment) async {
    if (_completingAppointment) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Concluir atendimento',
        content: Text(
          'Confirmar que o atendimento de ${appointment.clientName} foi concluído?',
        ),
        cancelLabel: 'Voltar',
        confirmLabel: 'Concluir',
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _completingAppointment = true);
    try {
      await _appointmentService.completeAppointment(
        appointmentId: appointment.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atendimento concluído.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível concluir: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _completingAppointment = false);
    }
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Bom dia';
    if (now.hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _longDate(DateTime date) {
    final value = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(date);
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _nextTimingLabel(_RoutineAppointment appointment, DateTime now) {
    final scheduledAt = appointment.scheduledAt;
    final difference = scheduledAt.difference(now);
    if (_sameDay(scheduledAt, now)) {
      if (difference.inMinutes <= 0) return 'Horário em andamento';
      if (difference.inMinutes < 60) {
        return 'Começa em ${difference.inMinutes} min';
      }
      return 'Hoje às ${appointment.hourLabel}';
    }
    if (_sameDay(scheduledAt, now.add(const Duration(days: 1)))) {
      return 'Amanhã às ${appointment.hourLabel}';
    }
    return DateFormat("EEE, dd/MM 'às' HH:mm", 'pt_BR').format(scheduledAt);
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Usuário não autenticado'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _appointmentService.watchAppointmentsForBarber(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _DashboardMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Não foi possível carregar sua rotina',
            message: 'Confira a conexão e tente novamente.',
          );
        }

        final now = DateTime.now();
        final todayKey = DateFormat('yyyy-MM-dd').format(now);
        final appointments = (snapshot.data?.docs ?? [])
            .map(_RoutineAppointment.fromDocument)
            .where((appointment) => appointment.scheduledAt.year > 2000)
            .toList();

        final today = appointments
            .where((appointment) => appointment.date == todayKey)
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        final upcoming = appointments
            .where((appointment) =>
                appointment.isActive && !appointment.scheduledAt.isBefore(now))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        final nextAppointment = upcoming.firstOrNull;
        final scheduledToday =
            today.where((appointment) => !appointment.isCancelled).length;
        final remainingToday = today
            .where((appointment) =>
                appointment.isActive && !appointment.scheduledAt.isBefore(now))
            .length;
        final completedToday =
            today.where((appointment) => appointment.isCompleted).length;
        final cancelledToday =
            today.where((appointment) => appointment.isCancelled).length;

        final cutoff = now.subtract(const Duration(hours: 24));
        final newInLastDay = appointments
            .where((appointment) =>
                appointment.createdAt != null &&
                appointment.createdAt!.isAfter(cutoff))
            .length;
        final cancelledByClientsInLastDay = appointments
            .where((appointment) =>
                appointment.cancelledBy == 'client' &&
                appointment.cancelledAt != null &&
                appointment.cancelledAt!.isAfter(cutoff))
            .length;
        final recentEvents = _buildRecentEvents(appointments).take(5).toList();

        return RefreshIndicator(
          onRefresh: () async => Future<void>.delayed(
            const Duration(milliseconds: 350),
          ),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                '${_greeting(now)}, sua rotina está aqui',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _longDate(now),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _NextAppointmentHero(
                appointment: nextAppointment,
                timingLabel: nextAppointment == null
                    ? null
                    : _nextTimingLabel(nextAppointment, now),
                onOpenAgenda: widget.onOpenAgenda,
              ),
              const SizedBox(height: 14),
              _RoutinePulse(
                newAppointments: newInLastDay,
                clientCancellations: cancelledByClientsInLastDay,
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Resumo de hoje',
                subtitle: 'Atualizado em tempo real',
              ),
              const SizedBox(height: 12),
              _MetricsGrid(
                scheduled: scheduledToday,
                remaining: remainingToday,
                completed: completedToday,
                cancelled: cancelledToday,
              ),
              const SizedBox(height: 26),
              _SectionTitle(
                title: 'Agenda de hoje',
                subtitle: today.isEmpty
                    ? 'Nenhum horário reservado'
                    : '${today.length} movimentações',
                actionLabel: 'Ver tudo',
                onAction: widget.onOpenAgenda,
              ),
              const SizedBox(height: 12),
              if (today.isEmpty)
                const _DashboardMessage(
                  icon: Icons.event_available_rounded,
                  title: 'Dia livre por enquanto',
                  message:
                      'Os novos agendamentos aparecerão aqui automaticamente.',
                )
              else
                ...today.map(
                  (appointment) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TodayAppointmentCard(
                      appointment: appointment,
                      canComplete: appointment.isActive &&
                          appointment.scheduledAt.isBefore(
                            now.add(const Duration(minutes: 30)),
                          ),
                      completing: _completingAppointment,
                      onComplete: () => _completeAppointment(appointment),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              const _SectionTitle(
                title: 'Atividade recente',
                subtitle: 'Agendamentos e cancelamentos',
              ),
              const SizedBox(height: 12),
              if (recentEvents.isEmpty)
                const _DashboardMessage(
                  icon: Icons.notifications_none_rounded,
                  title: 'Sem novidades recentes',
                  message: 'As atualizações da sua agenda aparecerão aqui.',
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: recentEvents.asMap().entries.map((entry) {
                        return Column(
                          children: [
                            _RecentActivityTile(event: entry.value),
                            if (entry.key < recentEvents.length - 1)
                              const Divider(height: 1, indent: 62),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_RoutineEvent> _buildRecentEvents(
    List<_RoutineAppointment> appointments,
  ) {
    final events = <_RoutineEvent>[];
    for (final appointment in appointments) {
      if (appointment.createdAt != null) {
        events.add(
          _RoutineEvent(
            type: _RoutineEventType.booked,
            occurredAt: appointment.createdAt!,
            appointment: appointment,
          ),
        );
      }
      if (appointment.isCancelled && appointment.cancelledAt != null) {
        events.add(
          _RoutineEvent(
            type: _RoutineEventType.cancelled,
            occurredAt: appointment.cancelledAt!,
            appointment: appointment,
          ),
        );
      }
      if (appointment.isCompleted && appointment.completedAt != null) {
        events.add(
          _RoutineEvent(
            type: _RoutineEventType.completed,
            occurredAt: appointment.completedAt!,
            appointment: appointment,
          ),
        );
      }
    }
    events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return events;
  }
}

class _NextAppointmentHero extends StatelessWidget {
  final _RoutineAppointment? appointment;
  final String? timingLabel;
  final VoidCallback? onOpenAgenda;

  const _NextAppointmentHero({
    required this.appointment,
    required this.timingLabel,
    required this.onOpenAgenda,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 236,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33072F27),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/barber_luxury_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF20A332B),
                  Color(0xC70A332B),
                  Color(0x4D071A17),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: appointment == null
                ? _EmptyNextAppointment(onOpenAgenda: onOpenAgenda)
                : _NextAppointmentContent(
                    appointment: appointment!,
                    timingLabel: timingLabel!,
                    onOpenAgenda: onOpenAgenda,
                  ),
          ),
        ],
      ),
    );
  }
}

class _NextAppointmentContent extends StatelessWidget {
  final _RoutineAppointment appointment;
  final String timingLabel;
  final VoidCallback? onOpenAgenda;

  const _NextAppointmentContent({
    required this.appointment,
    required this.timingLabel,
    required this.onOpenAgenda,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE76F51),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'PRÓXIMO ATENDIMENTO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const Spacer(),
            Text(
              timingLabel,
              style: const TextStyle(
                color: Color(0xFFFFD18B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          appointment.hourLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 44,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          appointment.clientName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          appointment.serviceName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            if (appointment.paid)
              const _HeroBadge(
                icon: Icons.verified_rounded,
                label: 'Pago',
              )
            else if (appointment.isCashPayment)
              const _HeroBadge(
                icon: Icons.payments_rounded,
                label: 'Dinheiro no local',
              ),
            const Spacer(),
            TextButton.icon(
              onPressed: onOpenAgenda,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Abrir agenda'),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyNextAppointment extends StatelessWidget {
  final VoidCallback? onOpenAgenda;

  const _EmptyNextAppointment({required this.onOpenAgenda});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeroBadge(
          icon: Icons.auto_awesome_rounded,
          label: 'ROTINA ORGANIZADA',
        ),
        const Spacer(),
        const Text(
          'Nenhum próximo horário',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Quando alguém agendar, os detalhes aparecerão aqui em tempo real.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 15),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onOpenAgenda,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text('Ver agenda'),
          ),
        ),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFFD18B), size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutinePulse extends StatelessWidget {
  final int newAppointments;
  final int clientCancellations;

  const _RoutinePulse({
    required this.newAppointments,
    required this.clientCancellations,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final noChanges = newAppointments == 0 && clientCancellations == 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: noChanges
            ? colors.primaryContainer.withValues(alpha: 0.65)
            : colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: noChanges ? colors.primary : colors.secondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              noChanges
                  ? Icons.check_circle_outline_rounded
                  : Icons.notifications_active_outlined,
              color: noChanges ? colors.onPrimary : colors.onSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: noChanges
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tudo tranquilo nas últimas 24h',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'Nenhum novo agendamento ou cancelamento.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _PulseValue(
                        value: newAppointments,
                        label: newAppointments == 1
                            ? 'novo agendamento'
                            : 'novos agendamentos',
                        color: colors.primary,
                      ),
                      _PulseValue(
                        value: clientCancellations,
                        label: clientCancellations == 1
                            ? 'cliente desmarcou'
                            : 'clientes desmarcaram',
                        color: colors.error,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PulseValue extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _PulseValue({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$value ',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          TextSpan(text: label),
        ],
      ),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final int scheduled;
  final int remaining;
  final int completed;
  final int cancelled;

  const _MetricsGrid({
    required this.scheduled,
    required this.remaining,
    required this.completed,
    required this.cancelled,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              width: width,
              icon: Icons.today_rounded,
              value: scheduled,
              label: 'Agenda do dia',
              color: colors.primary,
            ),
            _MetricCard(
              width: width,
              icon: Icons.schedule_rounded,
              value: remaining,
              label: 'Ainda faltam',
              color: colors.tertiary,
            ),
            _MetricCard(
              width: width,
              icon: Icons.task_alt_rounded,
              value: completed,
              label: 'Concluídos',
              color: const Color(0xFF2E8B70),
            ),
            _MetricCard(
              width: width,
              icon: Icons.event_busy_rounded,
              value: cancelled,
              label: 'Cancelados',
              color: colors.error,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  const _MetricCard({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayAppointmentCard extends StatelessWidget {
  final _RoutineAppointment appointment;
  final bool canComplete;
  final bool completing;
  final VoidCallback onComplete;

  const _TodayAppointmentCard({
    required this.appointment,
    required this.canComplete,
    required this.completing,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = appointment.isCancelled
        ? colors.error
        : appointment.isCompleted
            ? const Color(0xFF2E8B70)
            : colors.primary;
    final statusLabel = appointment.isCancelled
        ? appointment.cancelledBy == 'client'
            ? 'Cliente desmarcou'
            : appointment.cancelledBy == 'barber'
                ? 'Cancelado por você'
                : 'Cancelado'
        : appointment.isCompleted
            ? 'Concluído'
            : 'Confirmado';

    return Card(
      color: appointment.isCancelled
          ? colors.errorContainer.withValues(alpha: 0.34)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.schedule_rounded, color: statusColor, size: 18),
                  const SizedBox(height: 4),
                  Text(
                    appointment.hourLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          appointment.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    appointment.serviceName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (appointment.isCashPayment &&
                      !appointment.isCancelled) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.payments_rounded,
                          size: 15,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Receber em dinheiro no local',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ],
                  if (appointment.isCancelled &&
                      appointment.cancelReason.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      appointment.cancelReason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.error,
                          ),
                    ),
                  ],
                  if (canComplete && !appointment.isCancelled) ...[
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: completing ? null : onComplete,
                      icon: const Icon(Icons.task_alt_rounded, size: 17),
                      label: const Text('Concluir atendimento'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityTile extends StatelessWidget {
  final _RoutineEvent event;

  const _RecentActivityTile({required this.event});

  String _timeLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(value.year, value.month, value.day);
    if (eventDay == today) return DateFormat('HH:mm').format(value);
    if (eventDay == today.subtract(const Duration(days: 1))) {
      return 'Ontem, ${DateFormat('HH:mm').format(value)}';
    }
    return DateFormat('dd/MM, HH:mm').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appointment = event.appointment;
    final (icon, color, title) = switch (event.type) {
      _RoutineEventType.booked => (
          Icons.event_available_rounded,
          colors.primary,
          '${appointment.clientName} agendou',
        ),
      _RoutineEventType.cancelled => (
          Icons.event_busy_rounded,
          colors.error,
          appointment.cancelledBy == 'client'
              ? '${appointment.clientName} desmarcou'
              : 'Você cancelou um horário',
        ),
      _RoutineEventType.completed => (
          Icons.task_alt_rounded,
          const Color(0xFF2E8B70),
          'Atendimento concluído',
        ),
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        '${appointment.serviceName} • ${appointment.dateLabel} às ${appointment.hourLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _timeLabel(event.occurredAt),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _DashboardMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.primary, size: 30),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RoutineAppointment {
  final String id;
  final String clientName;
  final String serviceName;
  final String date;
  final String hour;
  final String status;
  final String cancelledBy;
  final String cancelReason;
  final String paymentMethod;
  final bool paid;
  final DateTime scheduledAt;
  final DateTime? createdAt;
  final DateTime? cancelledAt;
  final DateTime? completedAt;

  const _RoutineAppointment({
    required this.id,
    required this.clientName,
    required this.serviceName,
    required this.date,
    required this.hour,
    required this.status,
    required this.cancelledBy,
    required this.cancelReason,
    required this.paymentMethod,
    required this.paid,
    required this.scheduledAt,
    required this.createdAt,
    required this.cancelledAt,
    required this.completedAt,
  });

  factory _RoutineAppointment.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final date = data['date']?.toString() ?? '';
    final rawHour = data['hour']?.toString() ?? '';
    final hour = rawHour.padLeft(2, '0');
    final timestamp = data['scheduledAt'];
    final fallback = DateTime.tryParse('${date}T$hour:00:00');
    return _RoutineAppointment(
      id: document.id,
      clientName: data['clientName']?.toString().trim().isNotEmpty == true
          ? data['clientName'].toString().trim()
          : 'Cliente',
      serviceName: data['serviceName']?.toString().trim().isNotEmpty == true
          ? data['serviceName'].toString().trim()
          : 'Serviço',
      date: date,
      hour: hour,
      status: data['status']?.toString() ?? 'active',
      cancelledBy: switch (resolveCancellationActor(data)) {
        CancellationActor.client => 'client',
        CancellationActor.barber => 'barber',
        CancellationActor.unknown => '',
      },
      cancelReason: data['cancelReason']?.toString() ?? '',
      paymentMethod: data['paymentMethod']?.toString() ?? '',
      paid: data['paid'] == true,
      scheduledAt: timestamp is Timestamp
          ? timestamp.toDate()
          : fallback ?? DateTime.fromMillisecondsSinceEpoch(0),
      createdAt: _dateFromTimestamp(data['createdAt']),
      cancelledAt: _dateFromTimestamp(data['cancelledAt']),
      completedAt: _dateFromTimestamp(data['completedAt']),
    );
  }

  bool get isActive => status == 'active';
  bool get isCancelled => status == 'cancelled' || status == 'cancelado';
  bool get isCompleted =>
      status == 'completed' || status == 'done' || status == 'concluído';
  bool get isCashPayment => paymentMethod == 'cash';
  String get hourLabel => '$hour:00';

  String get dateLabel {
    final parsed = DateTime.tryParse(date);
    return parsed == null ? date : DateFormat('dd/MM').format(parsed);
  }

  static DateTime? _dateFromTimestamp(dynamic value) {
    return value is Timestamp ? value.toDate() : null;
  }
}

enum _RoutineEventType { booked, cancelled, completed }

class _RoutineEvent {
  final _RoutineEventType type;
  final DateTime occurredAt;
  final _RoutineAppointment appointment;

  const _RoutineEvent({
    required this.type,
    required this.occurredAt,
    required this.appointment,
  });
}
