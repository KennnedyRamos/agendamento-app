import 'package:flutter/material.dart';

class AppointmentListTile extends StatelessWidget {
  final String date;
  final String hour;
  final VoidCallback onCancel;

  const AppointmentListTile({
    super.key,
    required this.date,
    required this.hour,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        title: Text(
          'Data: $date - Hora: $hour:00',
          style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.cancel, color: Colors.red),
          onPressed: () {
            onCancel();
          },
        ),
      ),
    );
  }
}
