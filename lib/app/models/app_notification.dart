import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String actorId;
  final String? appointmentId;
  final String? conversationId;
  final String? messageId;
  final String? barberId;
  final String? clientId;
  final String? barbershopId;
  final String? barbershopName;
  final String? clientName;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.actorId,
    required this.appointmentId,
    this.conversationId,
    this.messageId,
    this.barberId,
    this.clientId,
    this.barbershopId,
    this.barbershopName,
    this.clientName,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final createdAt = data['createdAt'];
    return AppNotification(
      id: document.id,
      type: data['type']?.toString() ?? 'general',
      title: data['title']?.toString() ?? 'Notificação',
      body: data['body']?.toString() ?? '',
      actorId: data['actorId']?.toString() ?? '',
      appointmentId: data['appointmentId']?.toString(),
      conversationId: data['conversationId']?.toString(),
      messageId: data['messageId']?.toString(),
      barberId: data['barberId']?.toString(),
      clientId: data['clientId']?.toString(),
      barbershopId: data['barbershopId']?.toString(),
      barbershopName: data['barbershopName']?.toString(),
      clientName: data['clientName']?.toString(),
      isRead: data['isRead'] == true,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}
