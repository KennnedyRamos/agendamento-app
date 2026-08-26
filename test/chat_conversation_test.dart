import 'package:agendamento_app/app/models/chat_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses a stable id for a barber and client conversation', () {
    final conversation = ChatConversation.between(
      barberId: 'barber-123',
      clientId: 'client-456',
      barbershopId: 'shop-123',
      barbershopName: 'BarberKR Centro',
      clientName: 'Cliente Teste',
    );

    expect(conversation.id, 'barber-123_client-456');
    expect(conversation.barberId, 'barber-123');
    expect(conversation.clientId, 'client-456');
  });
}
