import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:agendamento_app/_colors/my_colors.dart';

class EventsPage extends StatefulWidget {
  final DateTime selectedDate;

  const EventsPage({super.key, required this.selectedDate});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  DateTime get selectedDay => widget.selectedDate;
  List<String> unavailableHours = [];
  List<String> userBookedHours = [];

  @override
  void initState() {
    super.initState();
    loadUnavailableHours();
    loadUserBookedHours();
  }

  // Carrega horários indisponíveis globalmente
  Future<void> loadUnavailableHours() async {
    final firestore = FirebaseFirestore.instance;

    try {
      final querySnapshot = await firestore
          .collection('unavailable_hours')
          .where('data',
              isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDay))
          .get();

      final hours = querySnapshot.docs
          .map((doc) => (doc['hora agendada'] as String))
          .toList();

      setState(() {
        unavailableHours = hours;
      });
    } catch (e) {
      print('Erro ao carregar horários indisponíveis: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar horários indisponíveis: $e')),
      );
    }
  }

  // Carrega os horários agendados pelo usuário
  Future<void> loadUserBookedHours() async {
    final firestore = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      final querySnapshot = await firestore
          .collection('app_agenda')
          .where('userId', isEqualTo: userId)
          .where('data', isEqualTo: selectedDay.toIso8601String())
          .get();

      final hours = querySnapshot.docs
          .map((doc) => (doc['hora agendada'] as String))
          .toList();

      setState(() {
        userBookedHours = hours;
      });
    } catch (e) {
      print('Erro ao carregar horários agendados pelo usuário: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Erro ao carregar horários agendados pelo usuário: $e')),
      );
    }
  }

  // Salva um agendamento
  Future<void> saveAppointment(DateTime selectedDay, String hour) async {
    final firestore = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    // Verificar se o horário já está indisponível para evitar duplicidade
    if (unavailableHours.contains(hour)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horário já agendado. Escolha outro.')),
      );
      return;
    }

    try {
      // Salva o agendamento
      await firestore.collection('app_agenda').add({
        'data': selectedDay.toIso8601String(),
        'hora agendada': hour,
        'userId': userId,
        'horario do agendamento': FieldValue.serverTimestamp(),
      });

      // Adiciona o horário como indisponível globalmente
      await firestore.collection('unavailable_hours').add({
        'data': DateFormat('yyyy-MM-dd').format(selectedDay),
        'hora agendada': hour,
      });

      setState(() {
        unavailableHours.add(hour); // Atualiza a lista local
        userBookedHours
            .add(hour); // Atualiza os horários agendados pelo usuário
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agendamento realizado com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao agendar: $e')),
      );
    }
  }

  // Cancela um agendamento
  Future<void> cancelAppointment(String hour) async {
    final firestore = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      // Remove o agendamento
      final querySnapshot = await firestore
          .collection('app_agenda')
          .where('data', isEqualTo: selectedDay.toIso8601String())
          .where('hora agendada', isEqualTo: hour)
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in querySnapshot.docs) {
        await firestore.collection('app_agenda').doc(doc.id).delete();
      }

      // Remove o horário da lista de indisponíveis
      final unavailableQuery = await firestore
          .collection('unavailable_hours')
          .where('data',
              isEqualTo: DateFormat('yyyy-MM-dd').format(selectedDay))
          .where('hora agendada', isEqualTo: hour)
          .get();

      for (var doc in unavailableQuery.docs) {
        await firestore.collection('unavailable_hours').doc(doc.id).delete();
      }

      setState(() {
        unavailableHours.remove(hour); // Atualiza a lista local
        userBookedHours
            .remove(hour); // Atualiza os horários agendados pelo usuário
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agendamento cancelado com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cancelar o agendamento: $e')),
      );
    }
  }

  // Mostra o diálogo de confirmação
  Future<bool?> showConfirmationDialog(
      BuildContext context, String hour) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Agendamento'),
          content: Text('Você deseja agendar um corte às $hour:00?'),
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

  // Mostra o diálogo de cancelamento
  Future<void> showCancellationDialog(BuildContext context, String hour) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancelar Agendamento'),
          content: Text('Você deseja cancelar o agendamento às $hour:00?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Não'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Sim'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await cancelAppointment(hour);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableHours = <String>[
      '07',
      '08',
      '09',
      '10',
      '11',
      '13',
      '14',
      '15',
      '16',
      '17',
      '18',
      '19'
    ].where((hour) => !unavailableHours.contains(hour)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'Horários disponíveis para \n${DateFormat('dd/MM/yyyy').format(selectedDay)}',
            textAlign: TextAlign.center, // Centraliza o texto
          ),
        ),
        backgroundColor: MyColors.azulClaroTon01,
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
        child: ListView.builder(
          itemCount: availableHours.length,
          itemBuilder: (context, index) {
            final hour = availableHours[index];
            return Card(
              margin:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16.0),
                title: Text(
                  'Hora: $hour:00',
                  style: const TextStyle(fontSize: 18.0),
                ),
                trailing: userBookedHours.contains(hour)
                    ? IconButton(
                        icon: const Icon(Icons.cancel),
                        onPressed: () async {
                          await showCancellationDialog(context, hour);
                        },
                      )
                    : null,
                onTap: () async {
                  final confirmed = await showConfirmationDialog(context, hour);
                  if (confirmed == true) {
                    await saveAppointment(selectedDay, hour);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
