import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/widgets/legal_links_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({super.key});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  final AppFirestoreService _firestoreService = AppFirestoreService();

  Future<void> _editProfile(Map<String, dynamic> user) async {
    final nomeController = TextEditingController(text: user['nome']);
    final sobrenomeController = TextEditingController(text: user['sobrenome']);
    final telefoneController = TextEditingController(text: user['telefone']);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Perfil'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: sobrenomeController,
                  decoration: const InputDecoration(labelText: 'Sobrenome'),
                ),
                TextField(
                  controller: telefoneController,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      await _firestoreService.updateUserProfile(
        uid: userId,
        nome: nomeController.text.trim(),
        sobrenome: sobrenomeController.text.trim(),
        telefone: telefoneController.text.trim(),
      );
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Usuário não autenticado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            FutureBuilder(
              future: _firestoreService.getUserProfile(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return const Text('Dados do usuário não encontrados.');
                }
                final profile = snapshot.data!;
                return ListTile(
                  title: Text(
                    '${profile.nome} ${profile.sobrenome}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(profile.email),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editProfile(profile.toMap()),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const LegalLinksCard(),
          ],
        ),
      ),
    );
  }
}
