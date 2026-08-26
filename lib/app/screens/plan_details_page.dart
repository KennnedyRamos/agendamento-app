import 'package:agendamento_app/app/models/barbershop.dart';
import 'package:agendamento_app/app/models/monthly_plan.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/appointment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlanDetailsPage extends StatefulWidget {
  final Barbershop barbershop;
  final MonthlyPlan plan;

  const PlanDetailsPage({
    super.key,
    required this.barbershop,
    required this.plan,
  });

  @override
  State<PlanDetailsPage> createState() => _PlanDetailsPageState();
}

class _PlanDetailsPageState extends State<PlanDetailsPage> {
  int _weekday = DateTime.monday;
  String? _hour;

  @override
  void initState() {
    super.initState();
    final availableDays = _availableDays();
    if (availableDays.isNotEmpty) {
      _weekday = availableDays.first;
      final hours = _hoursForDay(_weekday);
      if (hours.isNotEmpty) {
        _hour = hours.first;
      }
    }
  }

  List<int> _availableDays() {
    final days = <int>[];
    for (var day = 1; day <= 7; day++) {
      final hours = widget.barbershop.availability[day.toString()] ?? [];
      if (hours.isNotEmpty) {
        days.add(day);
      }
    }
    return days;
  }

  List<String> _hoursForDay(int day) {
    return widget.barbershop.availability[day.toString()] ?? [];
  }

  String _weekdayLabel(int weekday) {
    const labels = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];
    if (weekday < 1 || weekday > 7) return '';
    return labels[weekday - 1];
  }

  Future<void> _confirmPlan({
    required int weekday,
    required String hour,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestoreService = AppFirestoreService();
    final profile = await firestoreService.getUserProfile(user.uid);
    final clientName = profile == null
        ? user.email ?? 'Cliente'
        : '${profile.nome} ${profile.sobrenome}'.trim();

    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final created = await AppointmentService().createMonthlyPlanAppointments(
      barberId: widget.barbershop.ownerId,
      barbershopId: widget.barbershop.id,
      barbershopName: widget.barbershop.nome,
      clientId: user.uid,
      clientName: clientName,
      weekday: weekday,
      hour: hour,
      planId: widget.plan.id,
      planName: widget.plan.name,
      servicePrice: widget.plan.price,
      monthStart: monthStart,
    );

    await firestoreService.createMonthlyPlan(
      clientId: user.uid,
      barberId: widget.barbershop.ownerId,
      barbershopId: widget.barbershop.id,
      weekday: weekday,
      hour: hour,
      price: widget.plan.price,
      planId: widget.plan.id,
      planName: widget.plan.name,
      planServices: widget.plan.services,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Plano criado. Agendamentos: $created'),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _showPlanSelectionDialog({
    required List<int> availableDays,
  }) async {
    var selectedDay = _weekday;
    if (!availableDays.contains(selectedDay)) {
      selectedDay = availableDays.first;
    }
    var selectedHour = _hour;
    final initialHours = _hoursForDay(selectedDay);
    if (initialHours.isNotEmpty && !initialHours.contains(selectedHour)) {
      selectedHour = initialHours.first;
    }

    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final hours = _hoursForDay(selectedDay);
            if (hours.isNotEmpty && !hours.contains(selectedHour)) {
              selectedHour = hours.first;
            }
            final hasHours = hours.isNotEmpty;
            return AlertDialog(
              title: const Text('Escolher dia e horário'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedDay,
                    decoration:
                        const InputDecoration(labelText: 'Dia da semana'),
                    items: availableDays
                        .map(
                          (day) => DropdownMenuItem(
                            value: day,
                            child: Text(_weekdayLabel(day)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        selectedDay = value;
                        final newHours = _hoursForDay(value);
                        selectedHour =
                            newHours.isNotEmpty ? newHours.first : '';
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedDay),
                    initialValue:
                        (selectedHour != null && selectedHour!.isNotEmpty)
                            ? selectedHour
                            : null,
                    decoration: const InputDecoration(labelText: 'Horário'),
                    items: hours
                        .map(
                          (hour) => DropdownMenuItem(
                            value: hour,
                            child: Text('$hour:00'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        selectedHour = value;
                      });
                    },
                  ),
                  if (!hasHours)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('Sem horários disponíveis para esse dia.'),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: !hasHours || (selectedHour ?? '').isEmpty
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldConfirm == true) {
      final hourValue = selectedHour ?? '';
      if (hourValue.isEmpty) return;
      setState(() {
        _weekday = selectedDay;
        _hour = hourValue;
      });
      await _confirmPlan(weekday: selectedDay, hour: hourValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final availableDays = _availableDays();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano mensal'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.primary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.plan.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text('Valor: ${currency.format(widget.plan.price)}'),
            const SizedBox(height: 8),
            const Text(
              'Serviços incluídos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...widget.plan.services.map(
              (service) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16),
                    const SizedBox(width: 6),
                    Text(service),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (availableDays.isEmpty)
              const Text('Sem horários disponíveis nesta semana.'),
            ElevatedButton(
              onPressed: availableDays.isEmpty
                  ? null
                  : () => _showPlanSelectionDialog(
                        availableDays: availableDays,
                      ),
              child: const Text('Assinar plano mensal'),
            ),
          ],
        ),
      ),
    );
  }
}
