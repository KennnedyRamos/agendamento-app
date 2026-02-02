import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:agendamento_app/app/services/notification_service.dart';

class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<String>? _tokenSub;

  Future<void> initForUser(String uid) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(uid, token);
    }

    _tokenSub?.cancel();
    _tokenSub = _messaging.onTokenRefresh.listen((token) {
      _saveToken(uid, token);
    });

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      NotificationService().showNotification(
        title: notification.title ?? 'Notificação',
        body: notification.body ?? '',
      );
    });
  }

  Future<void> _saveToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
