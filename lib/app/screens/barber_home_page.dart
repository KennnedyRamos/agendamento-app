import 'package:agendamento_app/app/screens/barber_appointments_tab.dart';
import 'package:agendamento_app/app/screens/barber_dashboard_tab.dart';
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

class _BarberHomePageState extends State<BarberHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_syncSelectedTab);
  }

  void _syncSelectedTab() {
    if (!mounted || _currentIndex == _tabController.index) return;
    setState(() => _currentIndex = _tabController.index);
  }

  @override
  void dispose() {
    _tabController.removeListener(_syncSelectedTab);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await MessagingService().clearForUser(userId);
    }
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final sectionTitle = switch (_currentIndex) {
      0 => 'Visão geral',
      1 => 'Agendamentos',
      2 => 'Histórico',
      _ => 'Minha barbearia',
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
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          BarberDashboardTab(
            onOpenAgenda: () => _tabController.animateTo(1),
          ),
          const BarberAppointmentsTab(),
          const BarberAppointmentsTab(view: BarberAppointmentsView.history),
          const BarberProfileContent(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _tabController.animateTo,
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
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'Histórico',
              ),
              NavigationDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store_rounded),
                label: 'Barbearia',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
