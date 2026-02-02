import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _slotId(String barberId, String date, String hour) {
    return '${barberId}_${date}_$hour';
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
  }) async {
    final slotId = _slotId(barberId, date, hour);
    final slotRef = _db.collection('slots').doc(slotId);
    final appointmentRef = _db.collection('appointments').doc();
    final scheduledAt = DateTime.parse('$date' 'T' '$hour:00:00');

    await _db.runTransaction((tx) async {
      final slotSnap = await tx.get(slotRef);
      if (slotSnap.exists) {
        throw Exception('Horário indisponível.');
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
        'monthlyPlanId': monthlyPlanId,
        'isMonthlyPlan': isMonthlyPlan,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelAppointment({
    required String appointmentId,
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

      if (data['status'] == 'cancelled') {
        return;
      }

      if (isClient) {
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
        final cancelDeadline =
            scheduledAt.subtract(const Duration(hours: 6));
        if (DateTime.now().isAfter(cancelDeadline)) {
          throw Exception(
              'Prazo de cancelamento expirado (6h antes do horário).');
        }
      }

      final cancelReason = (reason != null && reason.trim().isNotEmpty)
          ? reason.trim()
          : (isBarber
              ? 'Agendamento cancelado pelo barbeiro. Entre em contato para remarcar.'
              : 'Cancelado pelo cliente');

      final slotId = '${data['barberId']}_${data['date']}_${data['hour']}';
      final slotRef = _db.collection('slots').doc(slotId);

      tx.delete(slotRef);
      tx.update(appointmentRef, {
        'status': 'cancelled',
        'cancelledBy': isBarber ? 'barber' : 'client',
        'cancelReason': cancelReason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
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

    return snapshot.docs
        .map((doc) => doc.data()['hour'].toString())
        .toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAppointmentsForClient(
      String clientId) {
    return _db
        .collection('appointments')
        .where('clientId', isEqualTo: clientId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAppointmentsForBarber(
      String barberId) {
    return _db
        .collection('appointments')
        .where('barberId', isEqualTo: barberId)
        .snapshots();
  }

  Future<void> markAppointmentPaid(String appointmentId) async {
    await _db.collection('appointments').doc(appointmentId).update({
      'paid': true,
      'paidAt': FieldValue.serverTimestamp(),
    });
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
      } catch (_) {
        // Skip conflicting slots
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
      } catch (_) {
        // Skip conflicting slots
      }
    }

    return created;
  }
}
