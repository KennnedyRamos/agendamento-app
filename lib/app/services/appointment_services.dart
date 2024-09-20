import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Função para mostrar o diálogo de confirmação
Future<bool?> showCancelConfirmationDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirmar Cancelamento'),
        content: const Text(
            'Você tem certeza que deseja cancelar este agendamento?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sim'),
          ),
        ],
      );
    },
  );
}

// Função para cancelar o agendamento
Future<void> cancelAppointment(String appointmentId) async {
  final firestore = FirebaseFirestore.instance;

  // Remove o agendamento da coleção 'app_agenda'
  await firestore.collection('app_agenda').doc(appointmentId).delete();

  // Adiciona o horário de volta à coleção 'unavailable_hours'
  final appointmentDoc =
      await firestore.collection('app_agenda').doc(appointmentId).get();
  final appointmentData = appointmentDoc.data();
  if (appointmentData != null) {
    final unavailableHourRef =
        firestore.collection('unavailable_hours').doc(appointmentData['data']);
    final unavailableHourDoc = await unavailableHourRef.get();

    if (unavailableHourDoc.exists) {
      await unavailableHourRef.update({
        'horarios': FieldValue.arrayUnion([appointmentData['hora agendada']])
      });
    } else {
      await unavailableHourRef.set({
        'horarios': [appointmentData['hora agendada']]
      });
    }
  }
}
