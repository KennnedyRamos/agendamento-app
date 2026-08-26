import 'dart:async';

import 'package:agendamento_app/app/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  String? _activeUserId;

  Future<void> initForUser(String userId) async {
    if (_activeUserId == userId &&
        _messageSubscription != null &&
        _tokenSubscription != null) {
      return;
    }

    await _cancelSubscriptions();
    _activeUserId = userId;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(userId, token);
      }
    } on FirebaseException catch (error) {
      debugPrint(
        'Não foi possível registrar as notificações: ${error.code}',
      );
    }

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      unawaited(
        _saveToken(userId, token).catchError((Object error) {
          debugPrint('Falha ao atualizar o token de notificação: $error');
        }),
      );
    });

    _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      unawaited(
        NotificationService().showNotification(
          title: notification.title ?? 'Notificação',
          body: notification.body ?? '',
        ),
      );
    });
  }

  Future<void> clearForUser(String userId) async {
    if (_activeUserId == userId) {
      await _cancelSubscriptions();
      _activeUserId = null;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _db.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      debugPrint(
        'Não foi possível remover o token de notificação: ${error.code}',
      );
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    _tokenSubscription = null;
    _messageSubscription = null;
  }

  Future<void> _saveToken(String userId, String token) async {
    await _db.collection('users').doc(userId).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
