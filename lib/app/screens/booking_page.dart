import 'package:agendamento_app/app/models/barbershop.dart';
import 'package:agendamento_app/app/models/service_item.dart';
import 'package:agendamento_app/app/screens/payment_checkout_page.dart';
import 'package:agendamento_app/app/services/appointment_service.dart';
import 'package:agendamento_app/app/widgets/barbershop_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
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

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _loadingHours = false;
  List<String> _availableHours = [];
  String? _selectedHour;
  ServiceItem? _selectedService;

  List<ServiceItem> get _services =>
      widget.service == null ? widget.barbershop.services : [widget.service!];

  @override
  void initState() {
    super.initState();
    _selectedService = widget.service;
    initializeDateFormatting('pt_BR', null);
    _loadHours();
  }

  Future<void> _loadHours() async {
    setState(() {
      _loadingHours = true;
      _selectedHour = null;
    });

    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final weekdayKey = _selectedDay.weekday.toString();
    final openHours = widget.barbershop.availability[weekdayKey] ?? [];
    final bookedHours = await _appointmentService.getBookedHours(
      barberId: widget.barbershop.ownerId,
      date: dateKey,
    );
    if (!mounted) return;

    final now = DateTime.now();
    final available = openHours.where((hour) {
      if (bookedHours.contains(hour)) return false;
      if (DateUtils.isSameDay(_selectedDay, now)) {
        return (int.tryParse(hour) ?? 0) > now.hour;
      }
      return true;
    }).toList()
      ..sort();

    setState(() {
      _availableHours = available;
      _loadingHours = false;
    });
  }

  void _continueToPayment() {
    final hour = _selectedHour;
    final service = _selectedService;
    if (hour == null || service == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentCheckoutPage(
          barbershop: widget.barbershop,
          service: service,
          date: _selectedDay,
          hour: hour,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final canContinue = _selectedHour != null && _selectedService != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Novo agendamento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
          children: [
            _BookingHero(barbershop: widget.barbershop),
            const SizedBox(height: 22),
            const _SectionHeader(
              number: '1',
              title: 'Escolha a data',
            ),
            const SizedBox(height: 10),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
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
                    leftChevronMargin: EdgeInsets.zero,
                    rightChevronMargin: EdgeInsets.zero,
                  ),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(color: colors.onPrimaryContainer),
                  ),
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    if (isSameDay(_selectedDay, selectedDay)) return;
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _loadHours();
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(number: '2', title: 'Escolha o horário'),
            const SizedBox(height: 12),
            if (_loadingHours)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_availableHours.isEmpty)
              const _EmptyMessage(
                icon: Icons.event_busy_rounded,
                text: 'Não há horários disponíveis neste dia.',
              )
            else
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: _availableHours.map((hour) {
                  final selected = _selectedHour == hour;
                  return ChoiceChip(
                    avatar: Icon(
                      Icons.schedule_rounded,
                      size: 17,
                      color: selected ? colors.onPrimary : colors.primary,
                    ),
                    label: Text(
                      '$hour:00',
                      style: TextStyle(
                        color: selected ? colors.onPrimary : colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: selected,
                    backgroundColor: colors.surfaceContainerLowest,
                    selectedColor: colors.primary,
                    side: BorderSide(
                      color: selected ? colors.primary : colors.outlineVariant,
                      width: selected ? 1.5 : 1,
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _selectedHour = hour),
                  );
                }).toList(),
              ),
            const SizedBox(height: 26),
            const _SectionHeader(number: '3', title: 'Escolha o serviço'),
            const SizedBox(height: 10),
            ..._services.map((service) {
              final selected = identical(_selectedService, service) ||
                  _selectedService?.nome == service.nome;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  color: selected ? colors.primaryContainer : null,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _selectedService = service),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.content_cut_rounded,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              service.nome,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            currency.format(service.preco),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected ? colors.primary : colors.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: FilledButton.icon(
          onPressed: canContinue ? _continueToPayment : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Escolher forma de pagamento'),
        ),
      ),
    );
  }
}

class _BookingHero extends StatelessWidget {
  final Barbershop barbershop;

  const _BookingHero({required this.barbershop});

  @override
  Widget build(BuildContext context) {
    final imageUrl = barbershop.imageUrl?.isNotEmpty == true
        ? barbershop.imageUrl
        : barbershop.imageThumbUrl;
    return Container(
      height: 172,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260A3D34),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          BarbershopImage(
            logoData: barbershop.logoData,
            imageUrl: imageUrl,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  Color(0xED092F29),
                  Color(0x7A092F29),
                  Color(0x16000000),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'VAMOS AGENDAR?',
                  style: TextStyle(
                    color: Color(0xFFFFCF83),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  barbershop.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Escolha a melhor data, horário e serviço.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String number;
  final String title;

  const _SectionHeader({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          child: Text(number, style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 9),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.outline),
          const SizedBox(width: 11),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
