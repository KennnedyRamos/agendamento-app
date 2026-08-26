import 'package:agendamento_app/app/models/barbershop.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/appointment_service.dart';
import 'package:agendamento_app/app/services/notification_service.dart';
import 'package:agendamento_app/app/services/review_service.dart';
import 'package:agendamento_app/app/utils/cancellation_utils.dart';
import 'package:agendamento_app/app/widgets/confirm_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ClientAppointmentsTab extends StatefulWidget {
  const ClientAppointmentsTab({super.key});

  @override
  State<ClientAppointmentsTab> createState() => _ClientAppointmentsTabState();
}

class _ClientAppointmentsTabState extends State<ClientAppointmentsTab> {
  final AppointmentService _appointmentService = AppointmentService();
  final ReviewService _reviewService = ReviewService();
  final AppFirestoreService _firestoreService = AppFirestoreService();
  final Map<String, Future<bool>> _reviewCache = {};
  final Map<String, Future<int?>> _reviewRatingCache = {};
  final Map<String, Future<Map<String, dynamic>?>> _planCache = {};
  final Map<String, Future<Barbershop?>> _barbershopCache = {};
  bool _showHistory = false;
  DateTime? _historyMonth;
  String _historyStatus = 'all';
  bool _showCancelled = false;

  DateTime? _tryParseDate(String date, String hour) {
    if (date.isEmpty) return null;
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) return null;
    final hourValue = int.tryParse(hour);
    if (hourValue == null) {
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    }
    return DateTime(
        parsedDate.year, parsedDate.month, parsedDate.day, hourValue);
  }

  bool _isTodayOrFuture(String date) {
    if (date.isEmpty) return false;
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) return false;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final targetDate =
        DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    return !targetDate.isBefore(todayDate);
  }

  bool _canCancel(String date, String hour) {
    if (date.isEmpty || hour.isEmpty) return false;
    final dateTime = DateTime.parse('$date' 'T' '$hour:00:00');
    return dateTime.isAfter(DateTime.now().add(const Duration(hours: 6)));
  }

  Future<void> _cancelAppointment(Map<String, dynamic> data) async {
    final appointmentId = data['id'];
    final date = data['date'] ?? '';
    final hour = data['hour'] ?? '';
    if (!_canCancel(date, hour)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancelamento não pode ser feito após 6h do horário.'),
        ),
      );
      return;
    }

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmDialog(
        title: 'Cancelar agendamento',
        content: Text('Deseja cancelar este agendamento?'),
        cancelLabel: 'Não',
        confirmLabel: 'Sim',
      ),
    );

    if (shouldCancel == true) {
      try {
        await _appointmentService.cancelAppointment(
          appointmentId: appointmentId,
          cancelledBy: 'client',
          reason: 'Cancelado pelo cliente',
        );
        await NotificationService().showNotification(
          title: 'Agendamento cancelado',
          body: 'Seu agendamento foi cancelado com sucesso.',
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cancelar: ${e.toString()}')),
        );
      }
    }
  }

  bool _canReview(String date, String hour, String status) {
    if (date.isEmpty || hour.isEmpty) return false;
    if (status != 'active') return false;
    final dateTime = DateTime.parse('$date' 'T' '$hour:00:00');
    return dateTime.isBefore(DateTime.now());
  }

  bool _canPay(String date, String hour) {
    if (date.isEmpty || hour.isEmpty) return false;
    final dateTime = DateTime.parse('$date' 'T' '$hour:00:00');
    return DateTime.now().isBefore(dateTime.add(const Duration(hours: 1)));
  }

  Future<void> _showReviewDialog({
    required String barberId,
    int? initialRating,
  }) async {
    int rating = initialRating ?? 5;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Avaliar atendimento'),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final isFilled = index < rating;
                  return IconButton(
                    onPressed: () {
                      setModalState(() {
                        rating = index + 1;
                      });
                    },
                    icon: Icon(
                      isFilled ? Icons.star : Icons.star_border,
                    ),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      try {
        await _reviewService.createReview(
          barberId: barberId,
          rating: rating,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avaliação enviada.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao avaliar: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showEditMonthlyPlanDialog({
    required String clientId,
    required String barberId,
    required String barbershopId,
    required String barbershopName,
    required Map<String, List<String>> availability,
    required double planPrice,
    required String planName,
    required String planId,
    required List<String> planServices,
    required String clientName,
    required int initialWeekday,
    required String initialHour,
  }) async {
    var selectedWeekday = initialWeekday;
    var selectedHour = initialHour;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final availableDays = <int>[];
            for (var day = 1; day <= 7; day++) {
              final hasHours =
                  (availability[day.toString()] ?? <String>[]).isNotEmpty;
              if (hasHours) {
                availableDays.add(day);
              }
            }
            final hasAnyDay = availableDays.isNotEmpty;
            if (hasAnyDay && !availableDays.contains(selectedWeekday)) {
              selectedWeekday = availableDays.first;
            }
            final hours =
                availability[selectedWeekday.toString()] ?? <String>[];
            final hasHours = hours.isNotEmpty;
            if (hours.isNotEmpty && !hours.contains(selectedHour)) {
              selectedHour = hours.first;
            }
            return AlertDialog(
              title: const Text('Editar plano mensal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hasAnyDay)
                    const Text(
                      'Sem horários disponíveis nesta semana.',
                    )
                  else ...[
                    DropdownButtonFormField<int>(
                      initialValue: selectedWeekday,
                      items: (() {
                        final weekdayLabels = <int, String>{
                          1: 'Segunda',
                          2: 'Terça',
                          3: 'Quarta',
                          4: 'Quinta',
                          5: 'Sexta',
                          6: 'Sábado',
                          7: 'Domingo',
                        };
                        return availableDays
                            .map(
                              (day) => DropdownMenuItem<int>(
                                value: day,
                                child: Text(weekdayLabels[day] ?? ''),
                              ),
                            )
                            .toList();
                      })(),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          selectedWeekday = value;
                          selectedHour = hours.isNotEmpty ? hours.first : '';
                        });
                      },
                      decoration:
                          const InputDecoration(labelText: 'Dia da semana'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey(selectedWeekday),
                      initialValue:
                          selectedHour.isNotEmpty ? selectedHour : null,
                      items: hours
                          .map((hour) => DropdownMenuItem(
                                value: hour,
                                child: Text('$hour:00'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          selectedHour = value;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Horário'),
                    ),
                    if (!hasHours)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Sem horários disponíveis para esse dia.',
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Alterações respeitam a regra de 6h para cancelamento.',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: !hasAnyDay || selectedHour.isEmpty || !hasHours
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldUpdate == true) {
      final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final created = await _appointmentService.updateMonthlyPlanAppointments(
        barberId: barberId,
        barbershopId: barbershopId,
        barbershopName: barbershopName,
        clientId: clientId,
        clientName: clientName,
        weekday: selectedWeekday,
        hour: selectedHour,
        planName: planName,
        servicePrice: planPrice,
        monthStart: monthStart,
      );
      await _firestoreService.createMonthlyPlan(
        clientId: clientId,
        barberId: barberId,
        barbershopId: barbershopId,
        weekday: selectedWeekday,
        hour: selectedHour,
        price: planPrice,
        planId: planId,
        planName: planName,
        planServices: planServices,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plano atualizado. Novos agendamentos: $created'),
        ),
      );
    }
  }

  Future<void> _showPixDialog({
    required String barberId,
    required String barbershopId,
    required String amountLabel,
  }) async {
    final byShop = barbershopId.trim().isEmpty
        ? null
        : await _firestoreService.getBarbershopById(barbershopId);
    final byOwner = await _firestoreService.getBarbershopByOwner(barberId);
    final pixKey = (byShop?.pixKey ?? byOwner?.pixKey ?? '').trim();
    final pixBank = (byShop?.pixBankName ?? byOwner?.pixBankName ?? '').trim();
    final pixType = (byShop?.pixKeyType ?? byOwner?.pixKeyType ?? '').trim();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pagamento via Pix'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (pixKey.isEmpty)
                  const Text('Chave Pix não cadastrada pelo barbeiro.')
                else ...[
                  QrImageView(
                    data: pixKey,
                    size: 180,
                  ),
                  const SizedBox(height: 12),
                  if (pixBank.isNotEmpty) Text('Banco: $pixBank'),
                  if (pixType.isNotEmpty)
                    Text('Tipo: ${_pixTypeLabel(pixType)}'),
                  const Text('Chave Pix:'),
                  SelectableText(
                    pixKey,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: pixKey));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chave Pix copiada.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar chave Pix'),
                  ),
                  const SizedBox(height: 8),
                  Text('Valor: $amountLabel'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Usuário não autenticado'));
    }

    return StreamBuilder(
      stream: _appointmentService.watchAppointmentsForClient(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Erro: ${snapshot.error}');
        }

        final allDocs = (snapshot.data?.docs ?? []).toList();
        if (_historyMonth == null && _showHistory) {
          final dates = allDocs
              .map((doc) => _tryParseDate(
                    doc.data()['date']?.toString() ?? '',
                    doc.data()['hour']?.toString() ?? '',
                  ))
              .whereType<DateTime>()
              .toList();
          if (dates.isNotEmpty) {
            dates.sort((a, b) => b.compareTo(a));
            final latest = dates.first;
            _historyMonth = DateTime(latest.year, latest.month);
          }
        }
        final docs = allDocs.where((doc) {
          final data = doc.data();
          final status = data['status'] ?? '';
          final date = data['date']?.toString() ?? '';
          if (_showHistory) {
            if (status != 'completed' && status != 'cancelled') return false;
            if (_historyStatus != 'all' && status != _historyStatus) {
              return false;
            }
            final parsedDate = DateTime.tryParse(date);
            if (parsedDate == null || _historyMonth == null) return true;
            return parsedDate.year == _historyMonth!.year &&
                parsedDate.month == _historyMonth!.month;
          }
          if (_showCancelled) {
            return status == 'cancelled';
          }
          if (status == 'cancelled') return false;
          return _isTodayOrFuture(date);
        }).toList();
        docs.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aDate = _tryParseDate(
            aData['date']?.toString() ?? '',
            aData['hour']?.toString() ?? '',
          );
          final bDate = _tryParseDate(
            bData['date']?.toString() ?? '',
            bData['hour']?.toString() ?? '',
          );
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });

        final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

        final listContent = docs.isEmpty
            ? Center(
                child: Text(
                  _showHistory
                      ? 'Nenhum histórico encontrado.'
                      : 'Nenhum agendamento de hoje ou futuro.',
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  data['id'] = doc.id;
                  final date = data['date'] ?? '';
                  final hour = data['hour'] ?? '';
                  final serviceName = data['serviceName'] ?? '';
                  final barbershopName = data['barbershopName'] ?? 'Barbearia';
                  final status = data['status'] ?? 'active';
                  final cancelReason = data['cancelReason'] ?? '';
                  final barberId = data['barberId'] ?? '';
                  final paid = data['paid'] == true;
                  final paymentMethod = data['paymentMethod']?.toString() ?? '';
                  final isCashPayment = paymentMethod == 'cash';
                  final isMonthlyPlan = data['isMonthlyPlan'] == true;
                  final servicePrice = (data['servicePrice'] is num)
                      ? data['servicePrice'] as num
                      : 0;

                  final formattedDate = date.isNotEmpty
                      ? DateFormat('dd/MM/yyyy').format(DateTime.parse(date))
                      : '';
                  final canCancel =
                      status == 'active' && _canCancel(date, hour);
                  final isCancelled = status == 'cancelled';
                  final isCompleted = status == 'completed';
                  final statusLabel = isCancelled
                      ? cancellationLabelForClient(data)
                      : (isCompleted ? 'Concluído' : 'Ativo');
                  final canReview =
                      _canReview(date, hour, status) && barberId != '';
                  final showPay = !paid &&
                      !isCashPayment &&
                      status == 'active' &&
                      _canPay(date, hour);

                  final scheme = Theme.of(context).colorScheme;
                  final statusBg = isCancelled
                      ? scheme.errorContainer
                      : (isCompleted
                          ? scheme.secondaryContainer
                          : scheme.primaryContainer);
                  final statusFg = isCancelled
                      ? scheme.onErrorContainer
                      : (isCompleted
                          ? scheme.onSecondaryContainer
                          : scheme.onPrimaryContainer);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '$barbershopName - $serviceName',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusFg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: statusBg,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Data: $formattedDate às $hour:00'
                            '${isCancelled && cancelReason.toString().isNotEmpty ? '\nMotivo: $cancelReason' : ''}',
                          ),
                          if (isCashPayment && !isCancelled)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.payments_rounded,
                                    size: 17,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pagamento no local: Dinheiro',
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (status == 'active' && !canCancel)
                            const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Cancelamento permitido até 6h antes do horário.',
                              ),
                            ),
                          if (!isCancelled)
                            TextButton.icon(
                              onPressed: canCancel
                                  ? () => _cancelAppointment(data)
                                  : null,
                              icon: const Icon(Icons.cancel_rounded, size: 18),
                              label: const Text('Cancelar'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                foregroundColor: Colors.red.shade400,
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          if (canReview)
                            FutureBuilder<bool>(
                              future: _reviewCache.putIfAbsent(
                                barberId,
                                () => _reviewService.hasReview(barberId),
                              ),
                              builder: (context, reviewSnapshot) {
                                final hasReview = reviewSnapshot.data ?? false;
                                if (hasReview) {
                                  return FutureBuilder<int?>(
                                    future: _reviewRatingCache.putIfAbsent(
                                      barberId,
                                      () => _reviewService
                                          .getReviewRating(barberId),
                                    ),
                                    builder: (context, ratingSnapshot) {
                                      final rating = ratingSnapshot.data;
                                      return TextButton.icon(
                                        onPressed: () => _showReviewDialog(
                                          barberId: barberId,
                                          initialRating: rating,
                                        ),
                                        icon: const Icon(Icons.edit, size: 18),
                                        label: const Text('Editar avaliação'),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                          foregroundColor: Colors.red.shade400,
                                          textStyle: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      );
                                    },
                                  );
                                }
                                return TextButton.icon(
                                  onPressed: () => _showReviewDialog(
                                    barberId: barberId,
                                  ),
                                  icon: const Icon(Icons.star, size: 18),
                                  label: const Text('Avaliar'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: Colors.red.shade400,
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                );
                              },
                            ),
                          if (isMonthlyPlan && status == 'active')
                            FutureBuilder<Map<String, dynamic>?>(
                              future: _planCache.putIfAbsent(
                                barberId,
                                () => _firestoreService.getMonthlyPlan(
                                  clientId: user.uid,
                                  barberId: barberId,
                                ),
                              ),
                              builder: (context, planSnapshot) {
                                final plan = planSnapshot.data;
                                if (plan == null) {
                                  return const SizedBox.shrink();
                                }
                                final barbershopId =
                                    data['barbershopId']?.toString() ?? '';
                                return FutureBuilder<Barbershop?>(
                                  future: _barbershopCache.putIfAbsent(
                                    barbershopId,
                                    () => _firestoreService
                                        .getBarbershopById(barbershopId),
                                  ),
                                  builder: (context, shopSnapshot) {
                                    final shop = shopSnapshot.data;
                                    if (shop == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final planWeekday =
                                        (plan['weekday'] as int?) ?? 1;
                                    final planHour =
                                        plan['hour']?.toString() ?? '';
                                    final planName =
                                        plan['planName']?.toString() ??
                                            data['serviceName']?.toString() ??
                                            'Plano mensal';
                                    final planId =
                                        plan['planId']?.toString() ?? 'default';
                                    final planPrice = (plan['price'] is num)
                                        ? (plan['price'] as num).toDouble()
                                        : 0.0;
                                    final planServices = (plan['planServices']
                                                as List<dynamic>? ??
                                            [])
                                        .map((e) => e.toString())
                                        .toList();
                                    return TextButton.icon(
                                      onPressed: () async {
                                        final profile = await _firestoreService
                                            .getUserProfile(user.uid);
                                        final clientName = profile == null
                                            ? user.email ?? 'Cliente'
                                            : '${profile.nome} ${profile.sobrenome}'
                                                .trim();
                                        if (!mounted) return;
                                        await _showEditMonthlyPlanDialog(
                                          clientId: user.uid,
                                          barberId: barberId,
                                          barbershopId: shop.id,
                                          barbershopName: shop.nome,
                                          availability: shop.availability,
                                          planPrice: planPrice,
                                          planName: planName,
                                          planId: planId,
                                          planServices: planServices,
                                          clientName: clientName,
                                          initialWeekday: planWeekday,
                                          initialHour: planHour,
                                        );
                                      },
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Editar plano mensal'),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: Colors.red.shade400,
                                        textStyle: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          const SizedBox(height: 6),
                          if (showPay)
                            ActionChip(
                              label: Text(
                                'Pagar',
                                style: TextStyle(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: scheme.primaryContainer,
                              onPressed: () => _showPixDialog(
                                barberId: barberId,
                                barbershopId: data['barbershopId'] ?? '',
                                amountLabel: currency.format(servicePrice),
                              ),
                            )
                          else if (paid && isCompleted)
                            Chip(
                              label: Text(
                                'Pago',
                                style: TextStyle(
                                  color: scheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: scheme.secondaryContainer,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );

        final historyMonths = allDocs
            .map((doc) =>
                DateTime.tryParse(doc.data()['date']?.toString() ?? ''))
            .whereType<DateTime>()
            .map((date) => DateTime(date.year, date.month))
            .toSet()
          ..removeWhere((date) => date.isBefore(DateTime(2000)));
        final historyMonthList = historyMonths.toList()
          ..sort((a, b) => b.compareTo(a));
        _historyMonth ??=
            historyMonthList.isNotEmpty ? historyMonthList.first : null;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Ativos',
                    onPressed: () {
                      setState(() {
                        _showHistory = false;
                        _showCancelled = false;
                      });
                    },
                    icon: Icon(
                      Icons.event_available,
                      color: (_showHistory || _showCancelled)
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancelados',
                    onPressed: () {
                      setState(() {
                        _showHistory = false;
                        _showCancelled = true;
                      });
                    },
                    icon: Icon(
                      Icons.block,
                      color: _showCancelled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Histórico',
                    onPressed: () {
                      setState(() {
                        _showHistory = true;
                        _showCancelled = false;
                      });
                    },
                    icon: Icon(
                      Icons.history,
                      color: _showHistory
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (_showHistory)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Mês'),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<DateTime>(
                            value: _historyMonth,
                            items: historyMonthList
                                .map(
                                  (date) => DropdownMenuItem(
                                    value: date,
                                    child: Text(
                                      DateFormat('MMMM/yyyy', 'pt_BR')
                                          .format(date),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _historyMonth = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _historyStatus,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Todos'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Concluídos'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('Cancelados'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _historyStatus = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            Expanded(child: listContent),
          ],
        );
      },
    );
  }
}

String _pixTypeLabel(String value) {
  switch (value) {
    case 'telefone':
      return 'Telefone';
    case 'email':
      return 'E-mail';
    case 'cpf':
      return 'CPF';
    case 'cnpj':
      return 'CNPJ';
    case 'aleatoria':
      return 'Aleatória';
    default:
      return value;
  }
}
