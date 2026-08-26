enum CancellationActor { client, barber, unknown }

CancellationActor resolveCancellationActor(Map<String, dynamic> data) {
  final cancelledByUserId = data['cancelledByUserId']?.toString() ?? '';
  final clientId = data['clientId']?.toString() ?? '';
  final barberId = data['barberId']?.toString() ?? '';

  if (cancelledByUserId.isNotEmpty) {
    if (cancelledByUserId == barberId) return CancellationActor.barber;
    if (cancelledByUserId == clientId) return CancellationActor.client;
  }

  final reason = data['cancelReason']?.toString().toLowerCase() ?? '';
  if (reason.contains('cancelado pelo barbeiro') ||
      reason.contains('cancelada pelo barbeiro')) {
    return CancellationActor.barber;
  }
  if (reason.contains('cancelado pelo cliente') ||
      reason.contains('cancelada pelo cliente')) {
    return CancellationActor.client;
  }

  return switch (data['cancelledBy']?.toString()) {
    'barber' => CancellationActor.barber,
    'client' => CancellationActor.client,
    _ => CancellationActor.unknown,
  };
}

String cancellationLabelForBarber(Map<String, dynamic> data) {
  return switch (resolveCancellationActor(data)) {
    CancellationActor.client => 'Cancelado pelo cliente',
    CancellationActor.barber => 'Cancelado por você',
    CancellationActor.unknown => 'Cancelado',
  };
}

String cancellationLabelForClient(Map<String, dynamic> data) {
  return switch (resolveCancellationActor(data)) {
    CancellationActor.client => 'Cancelado por você',
    CancellationActor.barber => 'Cancelado pela barbearia',
    CancellationActor.unknown => 'Cancelado',
  };
}
