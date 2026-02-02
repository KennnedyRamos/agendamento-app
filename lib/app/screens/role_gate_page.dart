import 'package:agendamento_app/app/screens/barber_home_page.dart';
import 'package:agendamento_app/app/screens/client_home_page.dart';
import 'package:agendamento_app/app/screens/login_page_cliente.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/messaging_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RoleGatePage extends StatefulWidget {
  const RoleGatePage({super.key});

  @override
  State<RoleGatePage> createState() => _RoleGatePageState();
}

class _RoleGatePageState extends State<RoleGatePage> {
  final AppFirestoreService _firestoreService = AppFirestoreService();
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _redirect();
    });
  }

  void _goTo(Widget page) {
    if (!mounted || _navigating) return;
    _navigating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    });
  }

  Future<void> _redirect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _goTo(const LoginPage());
      return;
    }

    final profile = await _firestoreService.getUserProfile(user.uid);
    if (!mounted) return;

    if (profile == null) {
      _goTo(const LoginPage());
      return;
    }

    await MessagingService().initForUser(user.uid);
    if (!mounted) return;

    if (profile.role == 'barber') {
      _goTo(const BarberHomePage());
    } else {
      _goTo(const ClientHomePage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
