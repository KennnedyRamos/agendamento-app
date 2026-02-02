import 'package:agendamento_app/app/services/appointment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BarberDashboardTab extends StatefulWidget {
  const BarberDashboardTab({super.key});

  @override
  State<BarberDashboardTab> createState() => _BarberDashboardTabState();
}

class _BarberDashboardTabState extends State<BarberDashboardTab> {
  final AppointmentService _service = AppointmentService();
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  final DateFormat _shortFormatter = DateFormat('dd/MM');
  final DateFormat _monthFormatter = DateFormat('MMMM yyyy', 'pt_BR');
  final DateFormat _weekdayFormatter = DateFormat('EEE', 'pt_BR');
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _weekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: weekday - 1));
  }

  bool _isCompletedStatus(String status) {
    final s = status.toLowerCase().trim();
    return s == 'completed' ||
        s == 'done' ||
        s == 'finished' ||
        s == 'concluido' ||
        s == 'concluído';
  }

  bool _isCancelledStatus(String status) {
    final s = status.toLowerCase().trim();
    return s == 'cancelled' || s == 'cancelado';
  }

  double _priceFromData(Map<String, dynamic> data) {
    final value = data['servicePrice'];
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Usuário não autenticado'));
    }

    final selectedDay = _selectedDay;
    final weekStart = _weekStart(selectedDay);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final monthStart = DateTime(selectedDay.year, selectedDay.month, 1);
    final monthEnd = DateTime(selectedDay.year, selectedDay.month + 1, 1);

    return StreamBuilder(
      stream: _service.watchAppointmentsForBarber(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Erro: ${snapshot.error}');
        }

        final docs = (snapshot.data?.docs ?? []).toList();
        int dayTotal = 0;
        int dayCompleted = 0;
        int dayCancelled = 0;
        int weekTotal = 0;
        int weekCompleted = 0;
        int weekCancelled = 0;
        int monthTotal = 0;
        int monthCompleted = 0;
        int monthCancelled = 0;
        double dayRevenue = 0.0;
        double weekRevenue = 0.0;
        double monthRevenue = 0.0;

        final revenueByDay = <DateTime, double>{};

        for (final doc in docs) {
          final data = doc.data();
          final status = data['status'] ?? 'active';
          final dateStr = data['date']?.toString() ?? '';
          if (dateStr.isEmpty) continue;
          DateTime? date;
          try {
            date = DateTime.parse(dateStr);
          } catch (_) {
            continue;
          }
          final dateOnly = DateTime(date.year, date.month, date.day);
          final isCompleted = _isCompletedStatus(status);
          final isCancelled = _isCancelledStatus(status);
          final price = _priceFromData(data);

          if (_isSameDay(dateOnly, selectedDay)) {
            dayTotal++;
            if (isCancelled) {
              dayCancelled++;
            } else if (isCompleted) {
              dayCompleted++;
              dayRevenue += price;
            }
          }
          if (dateOnly.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
              dateOnly.isBefore(weekEnd)) {
            weekTotal++;
            if (isCancelled) {
              weekCancelled++;
            } else if (isCompleted) {
              weekCompleted++;
              weekRevenue += price;
            }
          }
          if (dateOnly.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              dateOnly.isBefore(monthEnd)) {
            monthTotal++;
            if (isCancelled) {
              monthCancelled++;
            } else if (isCompleted) {
              monthCompleted++;
              monthRevenue += price;
              revenueByDay.update(
                dateOnly,
                (value) => value + price,
                ifAbsent: () => price,
              );
            }
          }
        }

        final currency =
            NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

        final topDays = revenueByDay.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top5 = topDays.take(5).toList();
        final maxRevenue =
            top5.isEmpty ? 0.0 : top5.first.value;
        final dayOpen = (dayTotal - dayCompleted - dayCancelled).clamp(0, 9999);
        final weekOpen =
            (weekTotal - weekCompleted - weekCancelled).clamp(0, 9999);
        final monthOpen =
            (monthTotal - monthCompleted - monthCancelled).clamp(0, 9999);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Text(
                'Resumo',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () {
                    setState(() {
                      final prev =
                          DateTime(selectedDay.year, selectedDay.month - 1, 1);
                      final lastDay =
                          DateTime(prev.year, prev.month + 1, 0).day;
                      final clampedDay =
                          selectedDay.day > lastDay ? lastDay : selectedDay.day;
                      _selectedDay =
                          DateTime(prev.year, prev.month, clampedDay);
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDay,
                      firstDate: monthStart,
                      lastDate: monthEnd.subtract(const Duration(days: 1)),
                      locale: const Locale('pt', 'BR'),
                    );
                    if (picked == null) return;
                    setState(() {
                      _selectedDay =
                          DateTime(picked.year, picked.month, picked.day);
                    });
                  },
                  child: Text(
                    _dateFormatter.format(selectedDay),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo mês',
                  onPressed: () {
                    setState(() {
                      final next =
                          DateTime(selectedDay.year, selectedDay.month + 1, 1);
                      final lastDay =
                          DateTime(next.year, next.month + 1, 0).day;
                      final clampedDay =
                          selectedDay.day > lastDay ? lastDay : selectedDay.day;
                      _selectedDay =
                          DateTime(next.year, next.month, clampedDay);
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 12),
            _SummaryCard(
              title: 'Hoje',
              subtitle: _dateFormatter.format(selectedDay),
              value: dayTotal,
              completed: dayCompleted,
              cancelled: dayCancelled,
              open: dayOpen,
              icon: Icons.today,
            ),
            _SummaryCard(
              title: 'Semana',
              subtitle:
                  '${_shortFormatter.format(weekStart)} - ${_shortFormatter.format(weekEnd.subtract(const Duration(days: 1)))}',
              value: weekTotal,
              completed: weekCompleted,
              cancelled: weekCancelled,
              open: weekOpen,
              icon: Icons.date_range,
            ),
            _SummaryCard(
              title: 'Mês',
              subtitle: _monthFormatter.format(monthStart),
              value: monthTotal,
              completed: monthCompleted,
              cancelled: monthCancelled,
              open: monthOpen,
              icon: Icons.calendar_month,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Faturamento',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            _RevenueCard(
              title: 'Hoje',
              subtitle: _dateFormatter.format(selectedDay),
              value: dayRevenue,
              icon: Icons.attach_money,
              currency: currency,
            ),
            _RevenueCard(
              title: 'Semana',
              subtitle:
                  '${_shortFormatter.format(weekStart)} - ${_shortFormatter.format(weekEnd.subtract(const Duration(days: 1)))}',
              value: weekRevenue,
              icon: Icons.trending_up,
              currency: currency,
            ),
            _RevenueCard(
              title: 'Mês',
              subtitle: _monthFormatter.format(monthStart),
              value: monthRevenue,
              icon: Icons.calendar_month,
              currency: currency,
            ),
            const SizedBox(height: 16),
            Text(
              'Maiores faturamentos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (top5.isEmpty)
              const Text('Sem dados de faturamento.'),
            ...top5.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final percent =
                  maxRevenue <= 0 ? 0.0 : (item.value / maxRevenue);
              final colors = [
                Theme.of(context).colorScheme.primary,
                Colors.teal,
                Colors.orange,
                Colors.purple,
                Colors.blue,
              ];
              final barColor = colors[index % colors.length];
              final legendLabel = _weekdayFormatter.format(item.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 90, child: Text(legendLabel)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: percent,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.6),
                          color: barColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(currency.format(item.value)),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final int completed;
  final int cancelled;
  final int open;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.completed,
    required this.cancelled,
    required this.open,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
          foregroundColor: colorScheme.primary,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            Text('Concluídos: $completed'),
            Text('Cancelados: $cancelled'),
            Text('Em aberto: $open'),
          ],
        ),
        trailing: Text(
          value.toString(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final IconData icon;
  final NumberFormat currency;

  const _RevenueCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
          foregroundColor: colorScheme.primary,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Text(
          currency.format(value),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
