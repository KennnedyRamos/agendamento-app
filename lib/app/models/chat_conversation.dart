class ChatConversation {
  final String id;
  final String barberId;
  final String clientId;
  final String barbershopId;
  final String barbershopName;
  final String clientName;

  const ChatConversation({
    required this.id,
    required this.barberId,
    required this.clientId,
    required this.barbershopId,
    required this.barbershopName,
    required this.clientName,
  });

  factory ChatConversation.between({
    required String barberId,
    required String clientId,
    required String barbershopId,
    required String barbershopName,
    required String clientName,
  }) {
    return ChatConversation(
      id: '${barberId}_$clientId',
      barberId: barberId,
      clientId: clientId,
      barbershopId: barbershopId,
      barbershopName: barbershopName,
      clientName: clientName,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });
}
