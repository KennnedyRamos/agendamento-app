import 'package:agendamento_app/app/screens/barber_appointments_tab.dart';
import 'package:agendamento_app/app/screens/barber_dashboard_tab.dart';
import 'package:agendamento_app/app/screens/barber_profile_content.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Center(child: Text('Área do Barbeiro')),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            BarberDashboardTab(),
            BarberAppointmentsTab(),
            BarberProfileContent(),
          ],
        ),
        bottomNavigationBar: Material(
          elevation: 8,
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            indicatorColor: Colors.transparent,
            labelStyle: const TextStyle(fontSize: 0),
            unselectedLabelStyle: const TextStyle(fontSize: 0),
            labelPadding: const EdgeInsets.only(bottom: 6, top: 6),
            tabs: const [
              Tab(icon: Icon(Icons.home, size: 26)),
              Tab(icon: Icon(Icons.event_note, size: 26)),
              Tab(icon: Icon(Icons.store, size: 26)),
            ],
          ),
        ),
      );
  }
}

