import 'package:agendamento_app/app/services/appointment_service.dart';
import 'package:agendamento_app/app/services/notification_service.dart';
import 'package:agendamento_app/app/utils/cancellation_utils.dart';
import 'package:agendamento_app/app/widgets/confirm_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum BarberAppointmentsView { agenda, history }

class BarberAppointmentsTab extends StatefulWidget {
  final BarberAppointmentsView view;

  const BarberAppointmentsTab({
    super.key,
    this.view = BarberAppointmentsView.agenda,
  });

  @override
  State<BarberAppointmentsTab> createState() => _BarberAppointmentsTabState();
}

class _BarberAppointmentsTabState extends State<BarberAppointmentsTab> {
  final AppointmentService _appointmentService = AppointmentService();
  final TextEditingController _clientSearchController = TextEditingController();
  DateTime? _historyPeriod;
  _HistoryPeriodType _historyPeriodType = _HistoryPeriodType.day;
  String _clientQuery = '';
  _HistoryFilterType _historyType = _HistoryFilterType.all;

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }

  Future<void> _cancelAsBarber(_BarberAppointmentRecord appointment) async {
    final reasonController = TextEditingController(
      text:
          'Agendamento cancelado pelo barbeiro. Entre em contato para remarcar.',
    );

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Cancelar agendamento',
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Mensagem ao cliente'),
          maxLines: 3,
        ),
        cancelLabel: 'Voltar',
        confirmLabel: 'Confirmar',
      ),
    );

    if (shouldCancel != true) {
      reasonController.dispose();
      return;
    }

    try {
      await _appointmentService.cancelAppointment(
        appointmentId: appointment.id,
        cancelledBy: 'barber',
        reason: reasonController.text.trim(),
      );
      await NotificationService().showNotification(
        title: 'Agendamento cancelado',
        body: 'Você cancelou um agendamento.',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cancelar: $error')),
      );
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _selectHistoryPeriod() async {
    final now = DateTime.now();
    final initial = _historyPeriod ?? now;
    final Future<DateTime?> selection;
    switch (_historyPeriodType) {
      case _HistoryPeriodType.day:
        selection = showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2020),
          lastDate: DateTime(now.year + 5, 12, 31),
          helpText: 'Filtrar pelo dia do atendimento',
          cancelText: 'Cancelar',
          confirmText: 'Aplicar',
        );
      case _HistoryPeriodType.month:
        selection = _showMonthPicker(initial);
      case _HistoryPeriodType.year:
        selection = _showYearPicker(initial);
    }
    final selected = await selection;
    if (selected == null || !mounted) return;
    setState(() => _historyPeriod = DateUtils.dateOnly(selected));
  }

  Future<DateTime?> _showMonthPicker(DateTime initial) {
    final maxYear = DateTime.now().year + 5;
    var displayedYear = initial.year.clamp(2020, maxYear);
    return showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                IconButton(
                  tooltip: 'Ano anterior',
                  onPressed: displayedYear <= 2020
                      ? null
                      : () => setDialogState(() => displayedYear--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '$displayedYear',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo ano',
                  onPressed: displayedYear >= maxYear
                      ? null
                      : () => setDialogState(() => displayedYear++),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            content: SizedBox(
              width: 340,
              height: 260,
              child: GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 1.7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: List.generate(12, (index) {
                  final monthNumber = index + 1;
                  final rawLabel = DateFormat.MMMM('pt_BR')
                      .format(DateTime(2020, monthNumber));
                  final label = rawLabel.isEmpty
                      ? monthNumber.toString().padLeft(2, '0')
                      : '${rawLabel[0].toUpperCase()}${rawLabel.substring(1)}';
                  final selected = _historyPeriod?.year == displayedYear &&
                      _historyPeriod?.month == monthNumber;
                  return FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      DateTime(displayedYear, monthNumber),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<DateTime?> _showYearPicker(DateTime initial) {
    final maxYear = DateTime.now().year + 5;
    final years = List.generate(maxYear - 2019, (index) => maxYear - index);
    return showDialog<DateTime>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Escolha o ano'),
        children: years.map((year) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, DateTime(year)),
            child: Row(
              children: [
                Icon(
                  year == initial.year
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                const SizedBox(width: 12),
                Text('$year'),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  bool _matchesHistoryPeriod(DateTime scheduledAt) {
    final period = _historyPeriod;
    if (period == null) return true;
    return switch (_historyPeriodType) {
      _HistoryPeriodType.day => DateUtils.isSameDay(scheduledAt, period),
      _HistoryPeriodType.month =>
        scheduledAt.year == period.year && scheduledAt.month == period.month,
      _HistoryPeriodType.year => scheduledAt.year == period.year,
    };
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
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _AppointmentsEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Não foi possível carregar a agenda',
            message: 'Confira sua conexão e tente novamente.',
          );
        }

        final appointments = (snapshot.data?.docs ?? const [])
            .map(_BarberAppointmentRecord.fromDocument)
            .toList(growable: false);

        return widget.view == BarberAppointmentsView.history
            ? _buildHistory(appointments)
            : _buildAgenda(appointments);
      },
    );
  }

  Widget _buildAgenda(List<_BarberAppointmentRecord> appointments) {
    final visible = appointments
        .where((appointment) => !appointment.isCancelled)
        .toList()
      ..sort(
          (first, second) => first.scheduledAt.compareTo(second.scheduledAt));

    if (visible.isEmpty) {
      return const _AppointmentsEmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nenhum agendamento na agenda',
        message: 'Os novos horários aparecerão aqui automaticamente.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final appointment = visible[index];
        return _AppointmentCard(
          appointment: appointment,
          onCancel:
              appointment.isActive ? () => _cancelAsBarber(appointment) : null,
        );
      },
    );
  }

  Widget _buildHistory(List<_BarberAppointmentRecord> appointments) {
    final allEvents = _buildHistoryEvents(appointments);
    final filteredEvents = allEvents.where((event) {
      if (!_matchesHistoryPeriod(event.appointment.scheduledAt)) {
        return false;
      }
      if (_clientQuery.isNotEmpty &&
          !event.appointment.clientName.toLowerCase().contains(_clientQuery)) {
        return false;
      }
      return switch (_historyType) {
        _HistoryFilterType.all => true,
        _HistoryFilterType.booked => event.type == _HistoryEventType.booked,
        _HistoryFilterType.cancelledByBarber =>
          event.type == _HistoryEventType.cancelledByBarber,
        _HistoryFilterType.cancelledByClient =>
          event.type == _HistoryEventType.cancelledByClient,
      };
    }).toList(growable: false);

    return Column(
      children: [
        _HistoryFilters(
          clientSearchController: _clientSearchController,
          selectedPeriod: _historyPeriod,
          periodType: _historyPeriodType,
          selectedType: _historyType,
          onClientChanged: (value) {
            setState(() => _clientQuery = value.trim().toLowerCase());
          },
          onClearClient: () {
            _clientSearchController.clear();
            setState(() => _clientQuery = '');
          },
          onSelectPeriod: _selectHistoryPeriod,
          onClearPeriod: () => setState(() => _historyPeriod = null),
          onPeriodTypeChanged: (value) {
            setState(() => _historyPeriodType = value);
          },
          onTypeChanged: (value) => setState(() => _historyType = value),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Atividades encontradas',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${filteredEvents.length}'),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredEvents.isEmpty
              ? const _AppointmentsEmptyState(
                  icon: Icons.manage_search_rounded,
                  title: 'Nenhuma atividade encontrada',
                  message: 'Altere a data, o nome ou o tipo do filtro.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: filteredEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _HistoryEventCard(event: filteredEvents[index]),
                ),
        ),
      ],
    );
  }

  List<_HistoryEvent> _buildHistoryEvents(
    List<_BarberAppointmentRecord> appointments,
  ) {
    final events = <_HistoryEvent>[];
    for (final appointment in appointments) {
      if (!appointment.isCancelled) {
        events.add(
          _HistoryEvent(
            type: _HistoryEventType.booked,
            occurredAt: appointment.createdAt ?? appointment.scheduledAt,
            appointment: appointment,
          ),
        );
      } else {
        final type = switch (appointment.cancelledBy) {
          CancellationActor.barber => _HistoryEventType.cancelledByBarber,
          CancellationActor.client => _HistoryEventType.cancelledByClient,
          CancellationActor.unknown => _HistoryEventType.cancelledUnknown,
        };
        events.add(
          _HistoryEvent(
            type: type,
            occurredAt: appointment.cancelledAt ??
                appointment.createdAt ??
                appointment.scheduledAt,
            appointment: appointment,
          ),
        );
      }
    }
    events.sort(
      (first, second) => second.occurredAt.compareTo(first.occurredAt),
    );
    return events;
  }
}

class _HistoryFilters extends StatelessWidget {
  final TextEditingController clientSearchController;
  final DateTime? selectedPeriod;
  final _HistoryPeriodType periodType;
  final _HistoryFilterType selectedType;
  final ValueChanged<String> onClientChanged;
  final VoidCallback onClearClient;
  final VoidCallback onSelectPeriod;
  final VoidCallback onClearPeriod;
  final ValueChanged<_HistoryPeriodType> onPeriodTypeChanged;
  final ValueChanged<_HistoryFilterType> onTypeChanged;

  const _HistoryFilters({
    required this.clientSearchController,
    required this.selectedPeriod,
    required this.periodType,
    required this.selectedType,
    required this.onClientChanged,
    required this.onClearClient,
    required this.onSelectPeriod,
    required this.onClearPeriod,
    required this.onPeriodTypeChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtrar período',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              children: _HistoryPeriodType.values.map((type) {
                return ChoiceChip(
                  selected: periodType == type,
                  label: Text(type.label),
                  onSelected: (_) => onPeriodTypeChanged(type),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSelectPeriod,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(
                      selectedPeriod == null
                          ? 'Escolher ${periodType.label.toLowerCase()}'
                          : _periodLabel(selectedPeriod!, periodType),
                    ),
                  ),
                ),
                if (selectedPeriod != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Remover filtro de período',
                    onPressed: onClearPeriod,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: clientSearchController,
              onChanged: onClientChanged,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Pesquisar cliente',
                hintText: 'Digite o nome do cliente',
                prefixIcon: const Icon(Icons.person_search_rounded),
                suffixIcon: clientSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        onPressed: onClearClient,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: colors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tipo de atividade',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _HistoryFilterType.values.map((type) {
                return FilterChip(
                  selected: selectedType == type,
                  label: Text(type.label),
                  onSelected: (_) => onTypeChanged(type),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(DateTime value, _HistoryPeriodType type) {
    return switch (type) {
      _HistoryPeriodType.day => DateFormat('dd/MM/yyyy').format(value),
      _HistoryPeriodType.month =>
        DateFormat('MMMM/yyyy', 'pt_BR').format(value),
      _HistoryPeriodType.year => DateFormat('yyyy').format(value),
    };
  }
}

class _AppointmentCard extends StatelessWidget {
  final _BarberAppointmentRecord appointment;
  final VoidCallback? onCancel;

  const _AppointmentCard({
    required this.appointment,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor =
        appointment.isCompleted ? colors.tertiary : colors.primary;
    final statusLabel = appointment.isCompleted ? 'Concluído' : 'Ativo';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.13),
                  child: Icon(Icons.person_rounded, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.clientName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(appointment.serviceName),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 17,
                  color: colors.secondary,
                ),
                const SizedBox(width: 6),
                Text(appointment.dateLabel),
                const SizedBox(width: 16),
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: colors.secondary,
                ),
                const SizedBox(width: 5),
                Text(appointment.hourLabel),
              ],
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancelar agendamento'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: colors.error,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryEventCard extends StatelessWidget {
  final _HistoryEvent event;

  const _HistoryEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appointment = event.appointment;
    final (icon, color, title) = switch (event.type) {
      _HistoryEventType.booked => (
          Icons.event_available_rounded,
          colors.primary,
          '${appointment.clientName} agendou',
        ),
      _HistoryEventType.cancelledByBarber => (
          Icons.event_busy_rounded,
          colors.error,
          'Você cancelou o horário de ${appointment.clientName}',
        ),
      _HistoryEventType.cancelledByClient => (
          Icons.person_off_rounded,
          colors.error,
          '${appointment.clientName} cancelou',
        ),
      _HistoryEventType.cancelledUnknown => (
          Icons.event_busy_outlined,
          colors.error,
          'Agendamento de ${appointment.clientName} cancelado',
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(appointment.serviceName),
                  const SizedBox(height: 3),
                  Text(
                    '${appointment.dateLabel} às ${appointment.hourLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (event.type != _HistoryEventType.booked &&
                      appointment.cancelReason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Motivo: ${appointment.cancelReason}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 7),
                  Text(
                    _eventTimeLabel(event.occurredAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _eventTimeLabel(DateTime value) {
    return 'Registrado em ${DateFormat("dd/MM/yyyy 'às' HH:mm").format(value)}';
  }
}

class _AppointmentsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _AppointmentsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: colors.primaryContainer,
              child: Icon(icon, size: 30, color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _BarberAppointmentRecord {
  final String id;
  final String clientName;
  final String serviceName;
  final String status;
  final String cancelReason;
  final CancellationActor cancelledBy;
  final DateTime scheduledAt;
  final DateTime? createdAt;
  final DateTime? cancelledAt;

  const _BarberAppointmentRecord({
    required this.id,
    required this.clientName,
    required this.serviceName,
    required this.status,
    required this.cancelReason,
    required this.cancelledBy,
    required this.scheduledAt,
    required this.createdAt,
    required this.cancelledAt,
  });

  factory _BarberAppointmentRecord.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final date = data['date']?.toString() ?? '';
    final rawHour = data['hour']?.toString() ?? '';
    final normalizedHour = rawHour.contains(':') ? rawHour : '$rawHour:00';
    final timestamp = data['scheduledAt'];
    final scheduledAt = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.tryParse('${date}T$normalizedHour') ??
            DateTime.fromMillisecondsSinceEpoch(0);
    final rawClientName = data['clientName']?.toString().trim() ?? '';
    final rawServiceName = data['serviceName']?.toString().trim() ?? '';
    return _BarberAppointmentRecord(
      id: document.id,
      clientName: rawClientName.isEmpty ? 'Cliente' : rawClientName,
      serviceName: rawServiceName.isEmpty ? 'Serviço' : rawServiceName,
      status: data['status']?.toString() ?? 'active',
      cancelReason: data['cancelReason']?.toString().trim() ?? '',
      cancelledBy: resolveCancellationActor(data),
      scheduledAt: scheduledAt,
      createdAt: _dateFromTimestamp(data['createdAt']),
      cancelledAt: _dateFromTimestamp(data['cancelledAt']),
    );
  }

  bool get isActive => status == 'active';
  bool get isCancelled => status == 'cancelled' || status == 'cancelado';
  bool get isCompleted =>
      status == 'completed' || status == 'done' || status == 'concluído';
  String get dateLabel => DateFormat('dd/MM/yyyy').format(scheduledAt);
  String get hourLabel => DateFormat('HH:mm').format(scheduledAt);

  static DateTime? _dateFromTimestamp(dynamic value) {
    return value is Timestamp ? value.toDate() : null;
  }
}

enum _HistoryPeriodType {
  day('Dia'),
  month('Mês'),
  year('Ano');

  final String label;
  const _HistoryPeriodType(this.label);
}

enum _HistoryFilterType {
  all('Todos'),
  booked('Agendamento'),
  cancelledByBarber('Cancelado por você'),
  cancelledByClient('Cancelado pelo cliente');

  final String label;
  const _HistoryFilterType(this.label);
}

enum _HistoryEventType {
  booked,
  cancelledByBarber,
  cancelledByClient,
  cancelledUnknown,
}

class _HistoryEvent {
  final _HistoryEventType type;
  final DateTime occurredAt;
  final _BarberAppointmentRecord appointment;

  const _HistoryEvent({
    required this.type,
    required this.occurredAt,
    required this.appointment,
  });
}
