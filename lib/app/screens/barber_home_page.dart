import 'package:agendamento_app/app/screens/barber_appointments_tab.dart';
import 'package:agendamento_app/app/screens/barber_dashboard_tab.dart';
import 'package:agendamento_app/app/screens/barber_financial_tab.dart';
import 'package:agendamento_app/app/screens/barber_more_tab.dart';
import 'package:agendamento_app/app/screens/barber_profile_content.dart';
import 'package:agendamento_app/app/services/messaging_service.dart';
import 'package:agendamento_app/app/widgets/notification_bell_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BarberHomePage extends StatefulWidget {
  const BarberHomePage({super.key});

  @override
  State<BarberHomePage> createState() => _BarberHomePageState();
}

class _BarberHomePageState extends State<BarberHomePage> {
  int _currentIndex = 0;

  Future<void> _logout() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await MessagingService().clearForUser(userId);
    }
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _openSection({
    required String title,
    required Widget child,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: child,
        ),
      ),
    );
  }

  Future<void> _openHistory() => _openSection(
        title: 'Histórico',
        child: const BarberAppointmentsTab(
          view: BarberAppointmentsView.history,
        ),
      );

  Future<void> _openFinancial() => _openSection(
        title: 'Financeiro',
        child: BarberFinancialTab(onOpenBarbershop: _openBarbershop),
      );

  Future<void> _openBarbershop() => _openSection(
        title: 'Minha barbearia',
        child: const BarberProfileContent(),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final sectionTitle = switch (_currentIndex) {
      0 => 'Visão geral',
      1 => 'Agendamentos',
      _ => 'Mais',
    };

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leadingWidth: 62,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14, top: 7, bottom: 7),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.content_cut_rounded,
              color: colors.onPrimary,
              size: 20,
            ),
          ),
        ),
        title: Column(
          children: [
            const Text('BarberKR'),
            Text(
              sectionTitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (userId != null) NotificationBellButton(userId: userId),
          const SizedBox(width: 6),
        ],
      ),
      body: switch (_currentIndex) {
        0 => BarberDashboardTab(
            onOpenAgenda: () => setState(() => _currentIndex = 1),
          ),
        1 => const BarberAppointmentsTab(),
        _ => BarberMoreTab(
            onOpenFinancial: _openFinancial,
            onOpenHistory: _openHistory,
            onOpenBarbershop: _openBarbershop,
            onLogout: _logout,
          ),
      },
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded),
                label: 'Resumo',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note_rounded),
                label: 'Agenda',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Mais',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
