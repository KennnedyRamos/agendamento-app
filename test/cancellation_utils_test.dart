import 'package:agendamento_app/app/utils/cancellation_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the cancelling user id as the source of truth', () {
    final data = <String, dynamic>{
      'clientId': 'client-1',
      'barberId': 'barber-1',
      'cancelledByUserId': 'barber-1',
      'cancelledBy': 'client',
    };

    expect(resolveCancellationActor(data), CancellationActor.barber);
    expect(cancellationLabelForBarber(data), 'Cancelado por você');
    expect(cancellationLabelForClient(data), 'Cancelado pela barbearia');
  });

  test('repairs legacy cancellation using the saved reason', () {
    final data = <String, dynamic>{
      'clientId': 'client-1',
      'barberId': 'barber-1',
      'cancelledBy': 'client',
      'cancelReason': 'Agendamento cancelado pelo barbeiro.',
    };

    expect(resolveCancellationActor(data), CancellationActor.barber);
  });
}
