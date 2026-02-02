import 'package:agendamento_app/app/services/appointment_service.dart';
import 'package:agendamento_app/app/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:agendamento_app/app/widgets/confirm_dialog.dart';

class BarberAppointmentsTab extends StatefulWidget {
  const BarberAppointmentsTab({super.key});

  @override
  State<BarberAppointmentsTab> createState() => _BarberAppointmentsTabState();
}

class _BarberAppointmentsTabState extends State<BarberAppointmentsTab> {
  final AppointmentService _appointmentService = AppointmentService();
  bool _showCancelled = false;

  Future<void> _cancelAsBarber(Map<String, dynamic> data) async {
    final reasonController = TextEditingController(
      text: 'Agendamento cancelado pelo barbeiro. Entre em contato para remarcar.',
    );

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Cancelar agendamento',
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Mensagem ao cliente'),
          maxLines: 3,
        ),
        cancelLabel: 'Voltar',
        confirmLabel: 'Confirmar',
      ),
    );

    if (shouldCancel == true) {
      try {
        await _appointmentService.cancelAppointment(
          appointmentId: data['id'],
          reason: reasonController.text.trim(),
        );
        await NotificationService().showNotification(
          title: 'Agendamento cancelado',
          body: 'Você cancelou um agendamento.',
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cancelar: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Usuário não autenticado'));
    }

    return StreamBuilder(
      stream: _appointmentService.watchAppointmentsForBarber(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Erro: ${snapshot.error}');
        }

        final allDocs = (snapshot.data?.docs ?? []).toList();
        final docs = allDocs.where((doc) {
          final status = doc.data()['status'] ?? 'active';
          if (_showCancelled) {
            return status == 'cancelled';
          }
          return status != 'cancelled';
        }).toList();
        docs.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aDate = '${aData['date'] ?? ''} ${aData['hour'] ?? ''}';
          final bDate = '${bData['date'] ?? ''} ${bData['hour'] ?? ''}';
          return aDate.compareTo(bDate);
        });

        final content = docs.isEmpty
            ? Center(
                child: Text(
                  _showCancelled
                      ? 'Nenhum agendamento cancelado.'
                      : 'Nenhum agendamento ativo.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16.0),
                children: docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;

            final date = data['date'] ?? '';
            final hour = data['hour'] ?? '';
            final service = data['serviceName'] ?? '';
            final clientName = data['clientName'] ?? 'Cliente';
            final status = data['status'] ?? 'active';
            final cancelReason = data['cancelReason'] ?? '';
            final formattedDate = date.isNotEmpty
                ? DateFormat('dd/MM/yyyy').format(DateTime.parse(date))
                : '';
            final isCancelled = status != 'active';

            final scheme = Theme.of(context).colorScheme;
            final statusBg = isCancelled
                ? scheme.errorContainer
                : scheme.primaryContainer;
            final statusFg = isCancelled
                ? scheme.onErrorContainer
                : scheme.onPrimaryContainer;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '$clientName - $service',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            isCancelled ? 'Cancelado' : 'Ativo',
                            style: TextStyle(
                              color: statusFg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: statusBg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Data: $formattedDate as $hour:00'),
                    if (isCancelled && cancelReason.toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text('Motivo: $cancelReason'),
                      ),
                    if (!isCancelled)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _cancelAsBarber(data),
                          icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18),
                          label: const Text('Cancelar'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            foregroundColor: Colors.red.shade400,
                            textStyle: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
                  );
                }).toList(),
              );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Ativos',
                    onPressed: () {
                      setState(() {
                        _showCancelled = false;
                      });
                    },
                    icon: Icon(
                      Icons.event_available,
                      color: _showCancelled
                          ? colorScheme.onSurface.withValues(alpha: 0.6)
                          : colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancelados',
                    onPressed: () {
                      setState(() {
                        _showCancelled = true;
                      });
                    },
                    icon: Icon(
                      Icons.block,
                      color: _showCancelled
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}




