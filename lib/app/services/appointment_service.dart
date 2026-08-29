import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentService {
  static const int appointmentQueryLimit = 1000;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _slotId(String barberId, String date, String hour) {
    return '${barberId}_${date}_$hour';
  }

  DocumentReference<Map<String, dynamic>> _notificationRef(
    String userId,
    String notificationId,
  ) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId);
  }

  Map<String, dynamic> _notificationData({
    required String userId,
    required String actorId,
    required String appointmentId,
    required String type,
    required String title,
    required String body,
  }) {
    return {
      'userId': userId,
      'actorId': actorId,
      'appointmentId': appointmentId,
      'type': type,
      'title': title,
      'body': body,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> bookAppointment({
    required String barberId,
    required String barbershopId,
    required String barbershopName,
    required String clientId,
    required String clientName,
    required String date,
    required String hour,
    required String serviceName,
    required double servicePrice,
    String? monthlyPlanId,
    bool isMonthlyPlan = false,
    String paymentMethod = 'pay_at_shop',
    String paymentStatus = 'pay_at_shop',
  }) async {
    if (_auth.currentUser?.uid != clientId) {
      throw StateError('O cliente informado não corresponde à sessão atual.');
    }

    final slotId = _slotId(barberId, date, hour);
    final slotRef = _db.collection('slots').doc(slotId);
    final appointmentRef = _db.collection('appointments').doc();
    final scheduledAt = DateTime.parse('$date' 'T' '$hour:00:00');

    await _db.runTransaction((tx) async {
      final slotSnap = await tx.get(slotRef);
      if (slotSnap.exists) {
        throw const SlotUnavailableException();
      }

      tx.set(slotRef, {
        'barberId': barberId,
        'clientId': clientId,
        'date': date,
        'hour': hour,
        'appointmentId': appointmentRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(appointmentRef, {
        'barberId': barberId,
        'barbershopId': barbershopId,
        'barbershopName': barbershopName,
        'clientId': clientId,
        'clientName': clientName,
        'date': date,
        'hour': hour,
        'serviceName': serviceName,
        'servicePrice': servicePrice,
        'status': 'active',
        'paid': false,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'monthlyPlanId': monthlyPlanId,
        'isMonthlyPlan': isMonthlyPlan,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(
        _notificationRef(
          clientId,
          '${appointmentRef.id}_created_client',
        ),
        _notificationData(
          userId: clientId,
          actorId: clientId,
          appointmentId: appointmentRef.id,
          type: 'appointment_created',
          title: 'Agendamento confirmado',
          body: 'Seu horário na $barbershopName foi confirmado para '
              '$date às $hour:00.',
        ),
      );
      tx.set(
        _notificationRef(
          barberId,
          '${appointmentRef.id}_created_barber',
        ),
        _notificationData(
          userId: barberId,
          actorId: clientId,
          appointmentId: appointmentRef.id,
          type: 'appointment_created',
          title: 'Novo agendamento',
          body: '$clientName agendou $serviceName para $date às $hour:00.',
        ),
      );
    });
  }

  Future<void> cancelAppointment({
    required String appointmentId,
    required String cancelledBy,
    String? reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final appointmentRef = _db.collection('appointments').doc(appointmentId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(appointmentRef);
      if (!snap.exists) {
        throw Exception('Agendamento não encontrado.');
      }

      final data = snap.data() as Map<String, dynamic>;
      final userId = user.uid;
      final isClient = data['clientId'] == userId;
      final isBarber = data['barberId'] == userId;
      if (!isClient && !isBarber) {
        throw Exception('Sem permissão para cancelar.');
      }
      if (cancelledBy != 'client' && cancelledBy != 'barber') {
        throw Exception('Origem do cancelamento inválida.');
      }
      if (cancelledBy == 'client' && !isClient) {
        throw Exception('Este usuário não é o cliente do agendamento.');
      }
      if (cancelledBy == 'barber' && !isBarber) {
        throw Exception('Este usuário não é o barbeiro do agendamento.');
      }

      if (data['status'] == 'cancelled') {
        return;
      }

      if (cancelledBy == 'client') {
        DateTime? scheduledAt;
        final ts = data['scheduledAt'];
        if (ts is Timestamp) {
          scheduledAt = ts.toDate();
        }
        if (scheduledAt == null) {
          final date = data['date']?.toString() ?? '';
          final hour = data['hour']?.toString() ?? '';
          if (date.isNotEmpty && hour.isNotEmpty) {
            scheduledAt = DateTime.parse('$date' 'T' '$hour:00:00');
          }
        }
        if (scheduledAt == null) {
          throw Exception('Agendamento sem data válida para cancelamento.');
        }
        final cancelDeadline = scheduledAt.subtract(const Duration(hours: 6));
        if (DateTime.now().isAfter(cancelDeadline)) {
          throw Exception(
              'Prazo de cancelamento expirado (6h antes do horário).');
        }
      }

      final cancelReason = (reason != null && reason.trim().isNotEmpty)
          ? reason.trim()
          : (cancelledBy == 'barber'
              ? 'Agendamento cancelado pelo barbeiro. Entre em contato para remarcar.'
              : 'Cancelado pelo cliente');

      final slotId = '${data['barberId']}_${data['date']}_${data['hour']}';
      final slotRef = _db.collection('slots').doc(slotId);

      tx.delete(slotRef);
      tx.update(appointmentRef, {
        'status': 'cancelled',
        'cancelledBy': cancelledBy,
        'cancelledByUserId': userId,
        'cancelReason': cancelReason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      final clientId = data['clientId']?.toString() ?? '';
      final barberId = data['barberId']?.toString() ?? '';
      final clientName = data['clientName']?.toString() ?? 'O cliente';
      final barbershopName =
          data['barbershopName']?.toString() ?? 'A barbearia';
      final date = data['date']?.toString() ?? '';
      final hour = data['hour']?.toString() ?? '';

      if (clientId.isNotEmpty) {
        tx.set(
          _notificationRef(clientId, '${appointmentRef.id}_cancelled_client'),
          _notificationData(
            userId: clientId,
            actorId: userId,
            appointmentId: appointmentRef.id,
            type: 'appointment_cancelled',
            title: 'Agendamento cancelado',
            body: cancelledBy == 'client'
                ? 'Você cancelou o horário de $date às $hour:00.'
                : '$barbershopName cancelou o horário de $date às $hour:00. '
                    '$cancelReason',
          ),
        );
      }
      if (barberId.isNotEmpty) {
        tx.set(
          _notificationRef(barberId, '${appointmentRef.id}_cancelled_barber'),
          _notificationData(
            userId: barberId,
            actorId: userId,
            appointmentId: appointmentRef.id,
            type: 'appointment_cancelled',
            title: 'Agendamento cancelado',
            body: cancelledBy == 'barber'
                ? 'Você cancelou o horário de $clientName em $date às $hour:00.'
                : '$clientName cancelou o horário de $date às $hour:00.',
          ),
        );
      }
    });
  }

  Future<void> completeAppointment({required String appointmentId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final appointmentRef = _db.collection('appointments').doc(appointmentId);
    await _db.runTransaction((tx) async {
      final snapshot = await tx.get(appointmentRef);
      if (!snapshot.exists) {
        throw Exception('Agendamento não encontrado.');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      if (data['barberId'] != user.uid) {
        throw Exception('Somente o barbeiro pode concluir o atendimento.');
      }
      if (data['status'] != 'active') {
        throw Exception('Este agendamento não está ativo.');
      }

      tx.update(appointmentRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      final clientId = data['clientId']?.toString() ?? '';
      final barberId = data['barberId']?.toString() ?? '';
      final clientName = data['clientName']?.toString() ?? 'Cliente';
      final serviceName = data['serviceName']?.toString() ?? 'Atendimento';
      if (clientId.isNotEmpty) {
        tx.set(
          _notificationRef(clientId, '${appointmentRef.id}_completed_client'),
          _notificationData(
            userId: clientId,
            actorId: user.uid,
            appointmentId: appointmentRef.id,
            type: 'appointment_completed',
            title: 'Atendimento concluído',
            body: 'Seu atendimento de $serviceName foi concluído.',
          ),
        );
      }
      if (barberId.isNotEmpty) {
        tx.set(
          _notificationRef(barberId, '${appointmentRef.id}_completed_barber'),
          _notificationData(
            userId: barberId,
            actorId: user.uid,
            appointmentId: appointmentRef.id,
            type: 'appointment_completed',
            title: 'Atendimento concluído',
            body: 'Você concluiu o atendimento de $clientName.',
          ),
        );
      }
    });
  }

  Future<List<String>> getBookedHours({
    required String barberId,
    required String date,
  }) async {
    final snapshot = await _db
        .collection('slots')
        .where('barberId', isEqualTo: barberId)
        .where('date', isEqualTo: date)
        .get();

    return snapshot.docs.map((doc) => doc.data()['hour'].toString()).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAppointmentsForClient(
      String clientId) {
    return _db
        .collection('appointments')
        .where('clientId', isEqualTo: clientId)
        .orderBy('date', descending: true)
        .limit(appointmentQueryLimit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAppointmentsForBarber(
      String barberId) {
    return _db
        .collection('appointments')
        .where('barberId', isEqualTo: barberId)
        .orderBy('date', descending: true)
        .limit(appointmentQueryLimit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentAppointmentsForBarber({
    required String barberId,
    required String fromDate,
  }) {
    return _db
        .collection('appointments')
        .where('barberId', isEqualTo: barberId)
        .where('date', isGreaterThanOrEqualTo: fromDate)
        .orderBy('date', descending: true)
        .limit(500)
        .snapshots();
  }

  Future<int> createMonthlyPlanAppointments({
    required String barberId,
    required String barbershopId,
    required String barbershopName,
    required String clientId,
    required String clientName,
    required int weekday,
    required String hour,
    required String planId,
    required String planName,
    required double servicePrice,
    required DateTime monthStart,
  }) async {
    final subscriptionId = '${clientId}_$barberId';
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final dates = <DateTime>[];
    var cursor = DateTime(monthStart.year, monthStart.month, 1);
    while (cursor.isBefore(monthEnd)) {
      if (cursor.weekday == weekday) {
        dates.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    var created = 0;
    for (final date in dates) {
      final dateKey = DateTime(date.year, date.month, date.day);
      final dateStr =
          '${dateKey.year.toString().padLeft(4, '0')}-${dateKey.month.toString().padLeft(2, '0')}-${dateKey.day.toString().padLeft(2, '0')}';
      final scheduledAt = DateTime.parse('${dateStr}T$hour:00:00');
      if (!scheduledAt.isAfter(DateTime.now())) continue;
      try {
        await bookAppointment(
          barberId: barberId,
          barbershopId: barbershopId,
          barbershopName: barbershopName,
          clientId: clientId,
          clientName: clientName,
          date: dateStr,
          hour: hour,
          serviceName: planName,
          servicePrice: servicePrice,
          monthlyPlanId: subscriptionId,
          isMonthlyPlan: true,
        );
        created++;
      } on SlotUnavailableException {
        // Outro cliente já reservou este horário.
      }
    }
    return created;
  }

  Future<int> updateMonthlyPlanAppointments({
    required String barberId,
    required String barbershopId,
    required String barbershopName,
    required String clientId,
    required String clientName,
    required int weekday,
    required String hour,
    required String planName,
    required double servicePrice,
    required DateTime monthStart,
  }) async {
    final now = DateTime.now();
    final planId = '${clientId}_$barberId';
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final snapshot = await _db
        .collection('appointments')
        .where('clientId', isEqualTo: clientId)
        .where('barberId', isEqualTo: barberId)
        .where('isMonthlyPlan', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .where(
          'scheduledAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .where(
          'scheduledAt',
          isLessThan: Timestamp.fromDate(monthEnd),
        )
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      DateTime? scheduledAt;
      final ts = data['scheduledAt'];
      if (ts is Timestamp) {
        scheduledAt = ts.toDate();
      }
      if (scheduledAt == null) {
        final date = data['date']?.toString() ?? '';
        final hourValue = data['hour']?.toString() ?? '';
        if (date.isNotEmpty && hourValue.isNotEmpty) {
          scheduledAt = DateTime.parse('$date' 'T' '$hourValue:00:00');
        }
      }
      if (scheduledAt == null) continue;
      if (scheduledAt.isBefore(now.add(const Duration(hours: 6)))) {
        continue;
      }
      await cancelAppointment(
        appointmentId: doc.id,
        cancelledBy: 'client',
        reason: 'Plano mensal editado',
      );
    }

    final dates = <DateTime>[];
    var cursor = DateTime(monthStart.year, monthStart.month, 1);
    while (cursor.isBefore(monthEnd)) {
      if (cursor.weekday == weekday) {
        dates.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    var created = 0;
    for (final date in dates) {
      final dateKey = DateTime(date.year, date.month, date.day);
      final dateStr =
          '${dateKey.year.toString().padLeft(4, '0')}-${dateKey.month.toString().padLeft(2, '0')}-${dateKey.day.toString().padLeft(2, '0')}';
      final scheduledAt = DateTime.parse('${dateStr}T$hour:00:00');
      if (!scheduledAt.isAfter(DateTime.now())) continue;
      try {
        await bookAppointment(
          barberId: barberId,
          barbershopId: barbershopId,
          barbershopName: barbershopName,
          clientId: clientId,
          clientName: clientName,
          date: dateStr,
          hour: hour,
          serviceName: planName,
          servicePrice: servicePrice,
          monthlyPlanId: planId,
          isMonthlyPlan: true,
        );
        created++;
      } on SlotUnavailableException {
        // Outro cliente já reservou este horário.
      }
    }

    return created;
  }
}

class SlotUnavailableException implements Exception {
  const SlotUnavailableException();

  @override
  String toString() => 'Horário indisponível.';
}
