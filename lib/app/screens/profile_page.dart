import 'package:agendamento_app/_colors/my_colors.dart';
import 'package:agendamento_app/app/screens/login_page_cliente.dart';
import 'package:agendamento_app/app/screens/widgets/appointment_list_tile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>> userData;
  late Future<List<Map<String, dynamic>>> appointments;

  @override
  void initState() {
    super.initState();
    userData = _fetchUserData();
    appointments = _fetchUserAppointments();
  }

  Future<Map<String, dynamic>> _fetchUserData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    final firestore = FirebaseFirestore.instance;
    final doc = await firestore.collection('clientes').doc(userId).get();

    if (!doc.exists) {
      throw Exception('Usuário não encontrado');
    }

    return doc.data()!;
  }

  Future<List<Map<String, dynamic>>> _fetchUserAppointments() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    final firestore = FirebaseFirestore.instance;
    final querySnapshot = await firestore
        .collection('app_agenda')
        .where('userId', isEqualTo: userId)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['appointmentId'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> _updateUserData(
      {required String nome,
      required String sobrenome,
      required String telefone}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final firestore = FirebaseFirestore.instance;

    await firestore.collection('clientes').doc(userId).update({
      'nome': nome,
      'sobrenome': sobrenome,
      'telefone': telefone,
    });
  }

  Future<void> _changePassword(String newPassword) async {
    User? user = FirebaseAuth.instance.currentUser;
    await user?.updatePassword(newPassword);
  }

  void _showEditProfileDialog(Map<String, dynamic> user) {
    final nomeController = TextEditingController(text: user['nome']);
    final sobrenomeController = TextEditingController(text: user['sobrenome']);
    final telefoneController = TextEditingController(text: user['telefone']);
    final senhaController = TextEditingController();

    showDialog(
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
                TextField(
                  controller: senhaController,
                  decoration: const InputDecoration(labelText: 'Nova Senha'),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Salvar'),
              onPressed: () async {
                await _updateUserData(
                  nome: nomeController.text,
                  sobrenome: sobrenomeController.text,
                  telefone: telefoneController.text,
                );

                if (senhaController.text.isNotEmpty) {
                  await _changePassword(senhaController.text);
                }

                Navigator.of(context).pop();
                setState(() {
                  userData = _fetchUserData();
                });
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelAppointment(
      String appointmentId, String scheduledHour) async {
    final firestore = FirebaseFirestore.instance;

    await firestore.collection('app_agenda').doc(appointmentId).delete();

    final unavailableHoursQuery = await firestore
        .collection('unavailable_hours')
        .where('hora agendada', isEqualTo: scheduledHour)
        .limit(1)
        .get();

    if (unavailableHoursQuery.docs.isNotEmpty) {
      await unavailableHoursQuery.docs.first.reference.delete();
    }
  }

  Future<bool?> showCancelConfirmationDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancelar Agendamento'),
          content: const Text(
              'Tem certeza de que deseja cancelar este agendamento?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Confirmar'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                MyColors.azulClaroTon03,
                MyColors.azulClaroTon01,
              ],
            ),
          ),
        ),
        title: const Center(
          child: Text(
            'Agenda',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final user = await userData;
              _showEditProfileDialog(user);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MyColors.azulClaroTon01,
              MyColors.azulClaroTon03,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<Map<String, dynamic>>(
                future: userData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text('Erro: ${snapshot.error}');
                  } else if (!snapshot.hasData) {
                    return const Text('Usuário não encontrado');
                  }

                  final user = snapshot.data!;
                  return ListTile(
                    title: Center(
                      child: Text(
                        'Olá, ${user['nome']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Meus Agendamentos:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: appointments,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Text('Erro: ${snapshot.error}');
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('Nenhum agendamento encontrado.');
                    }

                    final appointmentList = snapshot.data!;
                    return ListView.builder(
                      itemCount: appointmentList.length,
                      itemBuilder: (context, index) {
                        final appointment = appointmentList[index];
                        final date = DateTime.parse(appointment['data']);
                        final formattedDate =
                            DateFormat('dd/MM/yyyy').format(date);

                        return AppointmentListTile(
                          date: formattedDate,
                          hour: appointment['hora agendada'],
                          onCancel: () async {
                            final shouldCancel =
                                await showCancelConfirmationDialog(context);
                            if (shouldCancel == true) {
                              await _cancelAppointment(
                                  appointment['appointmentId'],
                                  appointment['hora agendada']);
                              setState(() {
                                appointments = _fetchUserAppointments();
                              });
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _logout,
                  child: const Text(
                    'Sair',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
