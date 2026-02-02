class Appointment {
  final String id;
  final String barberId;
  final String barbershopId;
  final String barbershopName;
  final String clientId;
  final String clientName;
  final String date; // yyyy-MM-dd
  final String hour; // HH
  final String serviceName;
  final double servicePrice;
  final String status; // active | cancelled
  final String? cancelledBy; // barber | client
  final String? cancelReason;

  Appointment({
    required this.id,
    required this.barberId,
    required this.barbershopId,
    required this.barbershopName,
    required this.clientId,
    required this.clientName,
    required this.date,
    required this.hour,
    required this.serviceName,
    required this.servicePrice,
    required this.status,
    this.cancelledBy,
    this.cancelReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'barberId': barberId,
      'barbershopId': barbershopId,
      'barbershopName': barbershopName,
      'clientId': clientId,
      'clientName': clientName,
      'date': date,
      'hour': hour,
      'serviceName': serviceName,
      'servicePrice': servicePrice,
      'status': status,
      'cancelledBy': cancelledBy,
      'cancelReason': cancelReason,
    };
  }

  static Appointment fromMap(String id, Map<String, dynamic> map) {
    final priceValue = map['servicePrice'];
    final price = priceValue is int
        ? priceValue.toDouble()
        : (priceValue ?? 0.0);
    return Appointment(
      id: id,
      barberId: map['barberId'] ?? '',
      barbershopId: map['barbershopId'] ?? '',
      barbershopName: map['barbershopName'] ?? '',
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      date: map['date'] ?? '',
      hour: map['hour'] ?? '',
      serviceName: map['serviceName'] ?? '',
      servicePrice: price,
      status: map['status'] ?? 'active',
      cancelledBy: map['cancelledBy'],
      cancelReason: map['cancelReason'],
    );
  }
}
