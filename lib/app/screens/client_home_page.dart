import 'package:agendamento_app/app/screens/client_appointments_tab.dart';
import 'package:agendamento_app/app/screens/client_barbershops_tab.dart';
import 'package:agendamento_app/app/screens/client_profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClientHomePage extends StatefulWidget {
  final int initialTab;

  const ClientHomePage({super.key, this.initialTab = 0});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
        appBar: AppBar(
          elevation: 0.0,
          title: const Text('Barbearias'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClientProfilePage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                colorScheme.primary.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: TabBarView(
            controller: _tabController,
            children: const [
              ClientBarbershopsTab(),
              ClientAppointmentsTab(),
            ],
          ),
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
              Tab(icon: Icon(Icons.storefront, size: 26)),
              Tab(icon: Icon(Icons.event_available, size: 26)),
            ],
          ),
        ),
      );
  }
}

