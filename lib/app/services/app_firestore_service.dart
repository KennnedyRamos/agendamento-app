import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/barbershop.dart';
import '../models/monthly_plan.dart';
import '../models/service_item.dart';
import '../models/user_profile.dart';

class AppFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUserProfile(UserProfile profile) async {
    await _db.collection('users').doc(profile.uid).set({
      ...profile.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  Future<void> updateUserProfile({
    required String uid,
    required String nome,
    required String sobrenome,
    required String telefone,
  }) async {
    await _db.collection('users').doc(uid).update({
      'nome': nome,
      'sobrenome': sobrenome,
      'telefone': telefone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createBarbershop({
    required String ownerId,
    required String nome,
    required String telefone,
    required Map<String, String> endereco,
    required List<ServiceItem> services,
    required Map<String, List<String>> availability,
    Map<String, double>? location,
    String? locationLabel,
    String? imageUrl,
    String? imageThumbUrl,
    String? logoData,
    double? monthlyPlanPrice,
    String? pixKey,
    String? pixKeyType,
    String? pixBankName,
    List<MonthlyPlan>? monthlyPlans,
  }) async {
    final nomeLower = nome.trim().toLowerCase();
    final cidadeLower = (endereco['cidade'] ?? '').trim().toLowerCase();
    final bairroLower = (endereco['bairro'] ?? '').trim().toLowerCase();

    await _db.collection('barbershops').doc(ownerId).set({
      'ownerId': ownerId,
      'nome': nome,
      'telefone': telefone,
      'endereco': endereco,
      'imageUrl': imageUrl,
      'imageThumbUrl': imageThumbUrl,
      if (logoData != null) 'logoData': logoData,
      'services': services.map((s) => s.toMap()).toList(),
      'availability': availability,
      'nomeLower': nomeLower,
      'cidadeLower': cidadeLower,
      'bairroLower': bairroLower,
      'monthlyPlanPrice': monthlyPlanPrice,
      'pixKey': pixKey,
      'pixKeyType': pixKeyType,
      'pixBankName': pixBankName,
      'monthlyPlans': (monthlyPlans ?? []).map((plan) => plan.toMap()).toList(),
      if (location != null) 'location': location,
      if (locationLabel != null && locationLabel.trim().isNotEmpty)
        'locationLabel': locationLabel,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Barbershop?> getBarbershopByOwner(String ownerId) async {
    final doc = await _db.collection('barbershops').doc(ownerId).get();
    if (!doc.exists) return null;
    return Barbershop.fromMap(doc.id, doc.data()!);
  }

  Future<Barbershop?> getBarbershopById(String barbershopId) async {
    final doc = await _db.collection('barbershops').doc(barbershopId).get();
    if (!doc.exists) return null;
    return Barbershop.fromMap(doc.id, doc.data()!);
  }

  Stream<List<Barbershop>> watchBarbershops({
    String? city,
    String? bairro,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('barbershops');
    if (city != null && city.trim().isNotEmpty) {
      query = query.where('cidadeLower', isEqualTo: city.trim().toLowerCase());
    }
    if (bairro != null && bairro.trim().isNotEmpty) {
      query =
          query.where('bairroLower', isEqualTo: bairro.trim().toLowerCase());
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Barbershop.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> updateBarbershop({
    required String ownerId,
    String? nome,
    String? telefone,
    Map<String, String>? endereco,
    Map<String, double>? location,
    String? locationLabel,
    String? imageUrl,
    String? imageThumbUrl,
    String? logoData,
    List<ServiceItem>? services,
    Map<String, List<String>>? availability,
    double? monthlyPlanPrice,
    String? pixKey,
    String? pixKeyType,
    String? pixBankName,
    List<MonthlyPlan>? monthlyPlans,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (nome != null) {
      data['nome'] = nome;
      data['nomeLower'] = nome.trim().toLowerCase();
    }
    if (telefone != null) {
      data['telefone'] = telefone;
    }
    if (endereco != null) {
      data['endereco'] = endereco;
      data['cidadeLower'] = (endereco['cidade'] ?? '').trim().toLowerCase();
      data['bairroLower'] = (endereco['bairro'] ?? '').trim().toLowerCase();
    }
    if (imageUrl != null) {
      data['imageUrl'] = imageUrl;
    }
    if (imageThumbUrl != null) {
      data['imageThumbUrl'] = imageThumbUrl;
    }
    if (logoData != null) {
      data['logoData'] = logoData;
    }
    if (services != null) {
      data['services'] = services.map((s) => s.toMap()).toList();
    }
    if (availability != null) {
      data['availability'] = availability;
    }
    if (monthlyPlanPrice != null) {
      data['monthlyPlanPrice'] = monthlyPlanPrice;
    }
    if (pixKey != null) {
      data['pixKey'] = pixKey;
    }
    if (pixKeyType != null) {
      data['pixKeyType'] = pixKeyType;
    }
    if (pixBankName != null) {
      data['pixBankName'] = pixBankName;
    }
    if (monthlyPlans != null) {
      data['monthlyPlans'] = monthlyPlans.map((plan) => plan.toMap()).toList();
    }
    if (location != null) {
      data['location'] = location;
    }
    if (locationLabel != null) {
      final trimmed = locationLabel.trim();
      data['locationLabel'] = trimmed.isEmpty ? null : trimmed;
    }

    await _db.collection('barbershops').doc(ownerId).update(data);
  }

  Future<void> createMonthlyPlan({
    required String clientId,
    required String barberId,
    required String barbershopId,
    required int weekday,
    required String hour,
    required double price,
    required String planId,
    required String planName,
    required List<String> planServices,
  }) async {
    final id = '${clientId}_$barberId';
    await _db.collection('monthly_plans').doc(id).set({
      'clientId': clientId,
      'barberId': barberId,
      'barbershopId': barbershopId,
      'weekday': weekday,
      'hour': hour,
      'price': price,
      'planId': planId,
      'planName': planName,
      'planServices': planServices,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getMonthlyPlan({
    required String clientId,
    required String barberId,
  }) async {
    final id = '${clientId}_$barberId';
    final doc = await _db.collection('monthly_plans').doc(id).get();
    if (!doc.exists) return null;
    return doc.data();
  }
}
