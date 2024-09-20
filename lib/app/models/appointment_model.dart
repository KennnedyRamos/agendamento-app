import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final DateTime date;
  final String clientName;

  Appointment({
    required this.id,
    required this.date,
    required this.clientName,
  });

  factory Appointment.fromFirestore(Map<String, dynamic> data, String id) {
    return Appointment(
      id: id,
      date: (data['date'] as Timestamp).toDate(),
      clientName: data['clientName'],
    );
  }
}
