import 'monthly_plan.dart';
import 'service_item.dart';

class Barbershop {
  final String id;
  final String ownerId;
  final String nome;
  final String telefone;
  final Map<String, String> endereco;
  final String? imageUrl;
  final String? imageThumbUrl;
  final List<ServiceItem> services;
  final Map<String, List<String>> availability;
  final String nomeLower;
  final String cidadeLower;
  final String bairroLower;
  final double? monthlyPlanPrice;
  final String? pixKey;
  final String? pixKeyType;
  final String? pixBankName;
  final List<MonthlyPlan> monthlyPlans;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;

  Barbershop({
    required this.id,
    required this.ownerId,
    required this.nome,
    required this.telefone,
    required this.endereco,
    required this.services,
    required this.availability,
    required this.nomeLower,
    required this.cidadeLower,
    required this.bairroLower,
    this.imageUrl,
    this.imageThumbUrl,
    this.monthlyPlanPrice,
    this.pixKey,
    this.pixKeyType,
    this.pixBankName,
    required this.monthlyPlans,
    this.latitude,
    this.longitude,
    this.locationLabel,
  });

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'nome': nome,
      'endereco': endereco,
      'imageUrl': imageUrl,
      'imageThumbUrl': imageThumbUrl,
      'services': services.map((s) => s.toMap()).toList(),
      'availability': availability,
      'nomeLower': nomeLower,
      'cidadeLower': cidadeLower,
      'bairroLower': bairroLower,
      'monthlyPlanPrice': monthlyPlanPrice,
      'pixKey': pixKey,
      'pixKeyType': pixKeyType,
      'pixBankName': pixBankName,
      'monthlyPlans': monthlyPlans.map((plan) => plan.toMap()).toList(),
      if (latitude != null && longitude != null)
        'location': {
          'lat': latitude,
          'lng': longitude,
        },
      if (locationLabel != null && locationLabel!.trim().isNotEmpty)
        'locationLabel': locationLabel,
    };
  }

  static Barbershop fromMap(String id, Map<String, dynamic> map) {
    final servicesRaw = (map['services'] as List<dynamic>? ?? []);
    final availabilityRaw = map['availability'] as Map<String, dynamic>? ?? {};
    final plansRaw = (map['monthlyPlans'] as List<dynamic>? ?? []);

    final availability = <String, List<String>>{};
    for (final entry in availabilityRaw.entries) {
      final valueList = entry.value as List<dynamic>? ?? [];
      availability[entry.key] = valueList.map((e) => e.toString()).toList();
    }

    final monthlyPlans = plansRaw
        .whereType<Map<String, dynamic>>()
        .map(MonthlyPlan.fromMap)
        .toList();

    final legacyPlanPrice = (map['monthlyPlanPrice'] is num)
        ? (map['monthlyPlanPrice'] as num).toDouble()
        : null;

    if (monthlyPlans.isEmpty && legacyPlanPrice != null && legacyPlanPrice > 0) {
      final fallbackServices = servicesRaw
          .whereType<Map<String, dynamic>>()
          .map(ServiceItem.fromMap)
          .map((service) => service.nome)
          .toList();
      monthlyPlans.add(
        MonthlyPlan(
          id: 'default',
          name: 'Plano mensal',
          price: legacyPlanPrice,
          services: fallbackServices,
        ),
      );
    }

    final locationRaw = map['location'] as Map<String, dynamic>?;
    final latRaw = locationRaw?['lat'];
    final lngRaw = locationRaw?['lng'];
    final latitude = (latRaw is num) ? latRaw.toDouble() : null;
    final longitude = (lngRaw is num) ? lngRaw.toDouble() : null;
    final locationLabel = map['locationLabel']?.toString();

    return Barbershop(
      id: id,
      ownerId: map['ownerId'] ?? '',
      nome: map['nome'] ?? '',
      telefone: map['telefone']?.toString() ?? '',
      endereco: (map['endereco'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, value?.toString() ?? '')),
      imageUrl: map['imageUrl'],
      imageThumbUrl: map['imageThumbUrl'],
      services: servicesRaw
          .map((s) => ServiceItem.fromMap(s as Map<String, dynamic>))
          .toList(),
      availability: availability,
      nomeLower: map['nomeLower'] ?? '',
      cidadeLower: map['cidadeLower'] ?? '',
      bairroLower: map['bairroLower'] ?? '',
      monthlyPlanPrice: legacyPlanPrice,
      pixKey: map['pixKey'],
      pixKeyType: map['pixKeyType'],
      pixBankName: map['pixBankName'],
      monthlyPlans: monthlyPlans,
      latitude: latitude,
      longitude: longitude,
      locationLabel: locationLabel,
    );
  }
}
