import 'dart:async';

import 'package:agendamento_app/app/app_widget.dart';
import 'package:agendamento_app/app/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const AppWidget());

  // Local notification setup is not required to render the first frame.
  unawaited(
    NotificationService().init().catchError((Object error) {
      debugPrint('Falha ao inicializar notificações locais: $error');
    }),
  );
}
