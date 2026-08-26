import 'package:agendamento_app/app/models/chat_conversation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((document) {
              final data = document.data();
              final createdAt = data['createdAt'];
              return ChatMessage(
                id: document.id,
                senderId: data['senderId']?.toString() ?? '',
                text: data['text']?.toString() ?? '',
                createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
              );
            }).toList(growable: false));
  }

  Future<void> sendMessage({
    required ChatConversation conversation,
    required String text,
  }) async {
    final senderId = _auth.currentUser?.uid;
    final trimmedText = text.trim();
    if (senderId == null) {
      throw StateError('Usuário não autenticado.');
    }
    if (senderId != conversation.clientId &&
        senderId != conversation.barberId) {
      throw StateError('Usuário sem acesso a esta conversa.');
    }
    if (trimmedText.isEmpty || trimmedText.length > 1000) {
      throw ArgumentError('A mensagem deve ter entre 1 e 1000 caracteres.');
    }

    final recipientId = senderId == conversation.clientId
        ? conversation.barberId
        : conversation.clientId;
    final barbershopName = _limit(conversation.barbershopName.trim(), 120);
    final clientName = _limit(conversation.clientName.trim(), 120);
    final conversationRef =
        _db.collection('conversations').doc(conversation.id);
    final messageRef = conversationRef.collection('messages').doc();
    final notificationRef = _db
        .collection('users')
        .doc(recipientId)
        .collection('notifications')
        .doc('${conversation.id}_${messageRef.id}_message');

    await _db.runTransaction((transaction) async {
      final conversationSnapshot = await transaction.get(conversationRef);
      final conversationData = <String, dynamic>{
        'lastMessage': trimmedText,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!conversationSnapshot.exists) {
        conversationData.addAll({
          'barberId': conversation.barberId,
          'clientId': conversation.clientId,
          'barbershopId': conversation.barbershopId,
          'barbershopName': barbershopName,
          'clientName': clientName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(
        conversationRef,
        conversationData,
        SetOptions(merge: true),
      );
      transaction.set(messageRef, {
        'senderId': senderId,
        'text': trimmedText,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationRef, {
        'userId': recipientId,
        'actorId': senderId,
        'conversationId': conversation.id,
        'messageId': messageRef.id,
        'barberId': conversation.barberId,
        'clientId': conversation.clientId,
        'barbershopId': conversation.barbershopId,
        'barbershopName': barbershopName,
        'clientName': clientName,
        'type': 'message_received',
        'title': _limit(
          senderId == conversation.clientId
              ? 'Mensagem de $clientName'
              : 'Resposta de $barbershopName',
          100,
        ),
        'body': trimmedText,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> markConversationNotificationsAsRead({
    required String userId,
    required String conversationId,
  }) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('conversationId', isEqualTo: conversationId)
        .get();
    final unreadDocuments = snapshot.docs
        .where((document) => document.data()['isRead'] != true)
        .toList(growable: false);
    if (unreadDocuments.isEmpty) return;

    final batch = _db.batch();
    for (final document in unreadDocuments) {
      batch.update(document.reference, {'isRead': true});
    }
    await batch.commit();
  }

  String _limit(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}
