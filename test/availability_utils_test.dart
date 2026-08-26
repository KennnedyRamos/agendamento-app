import 'package:agendamento_app/app/utils/availability_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAvailability', () {
    test('creates inclusive, zero-padded hours for each selected day', () {
      final availability = buildAvailability(
        days: [1, 6],
        startHour: 9,
        endHour: 11,
      );

      expect(availability, {
        '1': ['09', '10', '11'],
        '6': ['09', '10', '11'],
      });
    });

    test('returns an empty map when no days are selected', () {
      final availability = buildAvailability(
        days: [],
        startHour: 9,
        endHour: 18,
      );

      expect(availability, isEmpty);
    });
  });
}
