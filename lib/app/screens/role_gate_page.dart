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
  String? _error;

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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _goTo(const LoginPage());
        return;
      }

      final profile = await _firestoreService.getUserProfile(user.uid);
      if (!mounted) return;

      if (profile == null) {
        await FirebaseAuth.instance.signOut();
        _goTo(const LoginPage());
        return;
      }

      // Token synchronization must not delay access to the home screen.
      MessagingService().initForUser(user.uid).catchError((Object error) {
        debugPrint('Falha ao preparar notificações: $error');
      });

      if (profile.role == 'barber') {
        _goTo(const BarberHomePage());
      } else {
        _goTo(const ClientHomePage());
      }
    } on FirebaseException {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar sua conta. Verifique a conexão.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível iniciar o aplicativo.';
      });
    }
  }

  void _retry() {
    setState(() => _error = null);
    _redirect();
  }

  @override
  Widget build(BuildContext context) {
    if (_error == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
