import 'package:agendamento_app/app/models/barbershop.dart';
import 'package:agendamento_app/app/models/service_item.dart';
import 'package:agendamento_app/app/services/appointment_service.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

class BookingPage extends StatefulWidget {
  final Barbershop barbershop;
  final ServiceItem? service;

  const BookingPage({super.key, required this.barbershop, this.service});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final AppointmentService _appointmentService = AppointmentService();
  final AppFirestoreService _firestoreService = AppFirestoreService();

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _loadingHours = false;
  List<String> _availableHours = [];
  String? _selectedHour;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null);
    _loadHours();
  }

  Future<void> _loadHours() async {
    setState(() {
      _loadingHours = true;
    });

    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final weekdayKey = _selectedDay.weekday.toString();
    final openHours = widget.barbershop.availability[weekdayKey] ?? [];

    final bookedHours = await _appointmentService.getBookedHours(
      barberId: widget.barbershop.ownerId,
      date: dateKey,
    );

    final now = DateTime.now();
    final available = openHours.where((hour) {
      if (bookedHours.contains(hour)) return false;
      if (DateUtils.isSameDay(_selectedDay, now)) {
        final hourInt = int.tryParse(hour) ?? 0;
        return hourInt > now.hour;
      }
      return true;
    }).toList()
      ..sort();

    setState(() {
      _availableHours = available;
      _loadingHours = false;
    });
  }

  Future<void> _book(String hour, ServiceItem service) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profile = await _firestoreService.getUserProfile(user.uid);
    final clientName = profile == null
        ? user.email ?? 'Cliente'
        : '${profile.nome} ${profile.sobrenome}'.trim();

    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay);

    try {
      await _appointmentService.bookAppointment(
        barberId: widget.barbershop.ownerId,
        barbershopId: widget.barbershop.id,
        barbershopName: widget.barbershop.nome,
        clientId: user.uid,
        clientName: clientName,
        date: dateKey,
        hour: hour,
        serviceName: service.nome,
        servicePrice: service.preco,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agendamento realizado com sucesso!')),
      );
      await NotificationService().showNotification(
        title: 'Agendamento confirmado',
        body: 'Você agendou ${service.nome} às $hour:00.',
      );
      await _loadHours();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao agendar: ${e.toString()}')),
      );
    }
  }

  Future<bool?> _showConfirmation(String hour, ServiceItem service) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Agendamento'),
          content: Text('Deseja agendar ${service.nome} às $hour:00?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolha o horário'),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TableCalendar(
                locale: 'pt_BR',
                focusedDay: _focusedDay,
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 90)),
                calendarFormat: CalendarFormat.week,
                availableCalendarFormats: const {
                  CalendarFormat.week: 'Semana',
                },
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _loadHours();
                  }
                },
              ),
            ),
            if (_loadingHours)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else if (_availableHours.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Nenhum horário disponível para este dia.'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableHours.map((hour) {
                  final selected = _selectedHour == hour;
                  return ChoiceChip(
                    label: Text('$hour:00'),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedHour = hour;
                      });
                    },
                  );
                }).toList(),
              ),
            if (_selectedHour != null) ...[
              const SizedBox(height: 16),
              Text(
                'Serviços disponíveis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.barbershop.services.length,
                  itemBuilder: (context, index) {
                    final serviceItem = widget.barbershop.services[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 6.0, horizontal: 16.0),
                      child: ListTile(
                        title: Text(serviceItem.nome),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final confirmed =
                                await _showConfirmation(
                                    _selectedHour!, serviceItem);
                            if (confirmed == true) {
                              await _book(_selectedHour!, serviceItem);
                            }
                          },
                          child: const Text('Agendar'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
