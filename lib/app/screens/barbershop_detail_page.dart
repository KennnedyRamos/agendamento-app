import 'package:agendamento_app/app/models/barbershop.dart';
import 'package:agendamento_app/app/models/service_item.dart';
import 'package:agendamento_app/app/screens/plan_details_page.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/appointment_service.dart';
import 'package:agendamento_app/app/services/review_service.dart';
import 'package:agendamento_app/app/utils/map_utils.dart';
import 'package:agendamento_app/app/widgets/barbershop_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class BarbershopDetailPage extends StatefulWidget {
  final Barbershop barbershop;

  const BarbershopDetailPage({super.key, required this.barbershop});

  @override
  State<BarbershopDetailPage> createState() => _BarbershopDetailPageState();
}

class _BarbershopDetailPageState extends State<BarbershopDetailPage> {
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

    final bookedHours = await AppointmentService().getBookedHours(
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
      if (!_availableHours.contains(_selectedHour)) {
        _selectedHour = null;
      }
    });
  }

  Future<void> _book(ServiceItem service) async {
    if (_selectedHour == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestoreService = AppFirestoreService();
    final profile = await firestoreService.getUserProfile(user.uid);
    final clientName = profile == null
        ? user.email ?? 'Cliente'
        : '${profile.nome} ${profile.sobrenome}'.trim();

    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay);

    try {
      await AppointmentService().bookAppointment(
        barberId: widget.barbershop.ownerId,
        barbershopId: widget.barbershop.id,
        barbershopName: widget.barbershop.nome,
        clientId: user.uid,
        clientName: clientName,
        date: dateKey,
        hour: _selectedHour!,
        serviceName: service.nome,
        servicePrice: service.preco,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agendamento realizado com sucesso!')),
      );
      await _loadHours();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao agendar: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.barbershop;
    final colorScheme = Theme.of(context).colorScheme;
    final reviewService = ReviewService();
    final addressText = MapUtils.buildAddress(shop.endereco);
    final hasLocation = shop.latitude != null && shop.longitude != null;
    final canOpenMap = addressText.isNotEmpty || hasLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text(shop.nome),
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
          padding: const EdgeInsets.all(16.0),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BarbershopImage(
                logoData: shop.logoData,
                imageUrl: shop.imageUrl,
                height: 180,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    shop.nome,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                StreamBuilder(
                  stream: reviewService.watchReviewsForBarber(shop.ownerId),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    final ratingByClient = <String, double>{};
                    for (final doc in docs) {
                      final data = doc.data();
                      final clientId = data['clientId']?.toString() ?? doc.id;
                      final rating = data['rating'] ?? 0;
                      ratingByClient[clientId] =
                          (rating is int) ? rating.toDouble() : 0.0;
                    }
                    if (ratingByClient.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final values = ratingByClient.values.toList();
                    final total = values.fold<double>(
                        0.0, (totalSoFar, v) => totalSoFar + v);
                    final avg = total / values.length;
                    final count = values.length;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          count == 0
                              ? avg.toStringAsFixed(1)
                              : '${avg.toStringAsFixed(1)} ($count)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              addressText.isEmpty
                  ? 'Endereço: não informado.'
                  : 'Endereço: $addressText',
            ),
            const SizedBox(height: 6),
            if (shop.telefone.trim().isNotEmpty)
              Text('Telefone: ${shop.telefone}')
            else if ((shop.pixKeyType ?? '') == 'telefone' &&
                (shop.pixKey ?? '').trim().isNotEmpty)
              Text('Telefone: ${shop.pixKey}')
            else
              FutureBuilder(
                future: AppFirestoreService().getUserProfile(shop.ownerId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Telefone: carregando...');
                  }
                  final profile = snapshot.data;
                  final phone =
                      profile == null || profile.telefone.trim().isEmpty
                          ? 'Telefone não encontrado.'
                          : profile.telefone;
                  return Text('Telefone: $phone');
                },
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canOpenMap
                        ? () async {
                            if (!MapUtils.hasValidAddress(shop.endereco) &&
                                !MapUtils.hasCoordinates(
                                  shop.latitude,
                                  shop.longitude,
                                )) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Endereço não informado para abrir o mapa.'),
                                ),
                              );
                              return;
                            }
                            final ok = await MapUtils.openMapSearch(
                              endereco: shop.endereco,
                              name: shop.nome,
                              latitude: shop.latitude,
                              longitude: shop.longitude,
                            );
                            if (!context.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Não foi possível abrir o mapa.'),
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ver no mapa'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canOpenMap
                        ? () async {
                            if (!MapUtils.hasValidAddress(shop.endereco) &&
                                !MapUtils.hasCoordinates(
                                  shop.latitude,
                                  shop.longitude,
                                )) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Endereço não informado para abrir o mapa.'),
                                ),
                              );
                              return;
                            }
                            final ok = await MapUtils.openDirections(
                              endereco: shop.endereco,
                              name: shop.nome,
                              latitude: shop.latitude,
                              longitude: shop.longitude,
                            );
                            if (!context.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Não foi possível abrir o mapa.'),
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.directions),
                    label: const Text('Como chegar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder(
              stream: reviewService.watchReviewsForBarber(shop.ownerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final docs = snapshot.data?.docs ?? [];
                final ratingByClient = <String, double>{};
                for (final doc in docs) {
                  final data = doc.data();
                  final clientId = data['clientId']?.toString() ?? doc.id;
                  final rating = data['rating'] ?? 0;
                  ratingByClient[clientId] =
                      (rating is int) ? rating.toDouble() : 0.0;
                }
                if (ratingByClient.isEmpty) {
                  return const Text('Sem avaliações ainda.');
                }
                final values = ratingByClient.values.toList();
                final total =
                    values.fold<double>(0.0, (totalSoFar, v) => totalSoFar + v);
                final avg = total / values.length;
                final count = values.length;
                return Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(5, (index) {
                        final filled = index < avg.round();
                        return Icon(
                          filled ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 18,
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        avg.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text('($count)'),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Escolha o dia e horário',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TableCalendar(
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
            const SizedBox(height: 8),
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
                children: _availableHours.map((hour) {
                  final selected = _selectedHour == hour;
                  return ChoiceChip(
                    avatar: Icon(
                      Icons.schedule_rounded,
                      size: 17,
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.primary,
                    ),
                    label: Text(
                      '$hour:00',
                      style: TextStyle(
                        color: selected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: selected,
                    backgroundColor: colorScheme.surfaceContainerLowest,
                    selectedColor: colorScheme.primary,
                    side: BorderSide(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: selected ? 1.5 : 1,
                    ),
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _selectedHour = hour;
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            if (_selectedHour == null)
              const Text('Selecione um horário para agendar.'),
            Text(
              'Serviços',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (shop.services.isEmpty)
              const Text('Nenhum serviço cadastrado.')
            else
              ...shop.services.map((service) {
                final price =
                    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                        .format(service.preco);
                return Card(
                  child: ListTile(
                    title: Text(service.nome),
                    subtitle: Text(price),
                    trailing: ElevatedButton(
                      onPressed:
                          _selectedHour == null ? null : () => _book(service),
                      child: const Text('Agendar'),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text(
              'Planos mensais',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (shop.monthlyPlans.isEmpty)
              const Text('Nenhum plano disponível.')
            else
              ...shop.monthlyPlans.map((plan) {
                final price =
                    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                        .format(plan.price);
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.18),
                          colorScheme.primary.withValues(alpha: 0.06),
                        ],
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.2),
                        child: Icon(
                          Icons.star,
                          color: colorScheme.primary,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'BENEFÍCIO',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Plano mensal • Valor: $price',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlanDetailsPage(
                              barbershop: shop,
                              plan: plan,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
