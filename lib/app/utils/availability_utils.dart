Map<String, List<String>> buildAvailability({
  required List<int> days,
  required int startHour,
  required int endHour,
}) {
  final availability = <String, List<String>>{};
  for (final day in days) {
    final hours = <String>[];
    for (int h = startHour; h <= endHour; h++) {
      hours.add(h.toString().padLeft(2, '0'));
    }
    availability[day.toString()] = hours;
  }
  return availability;
}