class MonthlyPlan {
  final String id;
  final String name;
  final double price;
  final List<String> services;

  MonthlyPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.services,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'services': services,
    };
  }

  static MonthlyPlan fromMap(Map<String, dynamic> map) {
    final priceValue = map['price'];
    final price = priceValue is int ? priceValue.toDouble() : (priceValue ?? 0.0);
    return MonthlyPlan(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: price,
      services: (map['services'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
