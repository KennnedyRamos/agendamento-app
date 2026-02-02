import 'dart:async';

import 'package:agendamento_app/app/models/barbershop.dart';
import 'package:agendamento_app/app/screens/barbershop_profile_page.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/review_service.dart';
import 'package:flutter/material.dart';

class ClientBarbershopsTab extends StatefulWidget {
  const ClientBarbershopsTab({super.key});

  @override
  State<ClientBarbershopsTab> createState() => _ClientBarbershopsTabState();
}

class _ClientBarbershopsTabState extends State<ClientBarbershopsTab> {
  final AppFirestoreService _firestoreService = AppFirestoreService();
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _lastSignature = '';
  String _lastQuery = '';
  List<Barbershop> _filtered = [];
  List<String> _suggestions = [];
  final Map<String, double> _ratingsCache = {};
  final Map<String, int> _ratingsCountCache = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim().toLowerCase();
      });
    });
  }

  void _recomputeFilters(List<Barbershop> shops) {
    final signature = shops.map((shop) => shop.id).join('|');
    if (signature == _lastSignature && _query == _lastQuery) {
      return;
    }
    _lastSignature = signature;
    _lastQuery = _query;

    if (_query.isEmpty) {
      _filtered = shops;
      _suggestions = [];
      return;
    }

    _filtered = shops
        .where((shop) =>
            shop.nomeLower.contains(_query) ||
            shop.nome.toLowerCase().contains(_query) ||
            shop.bairroLower.contains(_query) ||
            shop.cidadeLower.contains(_query))
        .toList();

    final suggestions = <String>{};
    for (final shop in shops) {
      if (shop.nomeLower.contains(_query)) {
        suggestions.add(shop.nome);
      }
      if (shop.bairroLower.contains(_query)) {
        final bairro = shop.endereco['bairro'] ?? '';
        if (bairro.isNotEmpty) suggestions.add(bairro);
      }
      if (shop.cidadeLower.contains(_query)) {
        final cidade = shop.endereco['cidade'] ?? '';
        if (cidade.isNotEmpty) suggestions.add(cidade);
      }
      if (suggestions.length >= 10) break;
    }
    _suggestions = suggestions.toList();
  }

  Future<void> _ensureRatings(List<Barbershop> shops) async {
    final targets = shops
        .where((shop) => !_ratingsCache.containsKey(shop.ownerId))
        .map((shop) => shop.ownerId)
        .toSet();
    if (targets.isEmpty) return;
    for (final barberId in targets) {
      _reviewService
          .watchReviewsForBarber(barberId)
          .take(1)
          .listen((snapshot) {
        final ratingByClient = <String, double>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final clientId = data['clientId']?.toString() ?? doc.id;
          final rating = data['rating'] ?? 0;
          ratingByClient[clientId] =
              (rating is int) ? rating.toDouble() : 0.0;
        }
        if (!mounted) return;
        setState(() {
          if (ratingByClient.isEmpty) {
            _ratingsCache[barberId] = 0.0;
            _ratingsCountCache[barberId] = 0;
          } else {
            final values = ratingByClient.values.toList();
            final total =
                values.fold<double>(0.0, (totalSoFar, v) => totalSoFar + v);
            _ratingsCache[barberId] = total / values.length;
            _ratingsCountCache[barberId] = values.length;
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar por nome, bairro ou cidade',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Barbershop>>(
            stream: _firestoreService.watchBarbershops(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erro: ${snapshot.error}'));
              }

              final shops = snapshot.data ?? [];
              _recomputeFilters(shops);
              _ensureRatings(_filtered);

              return Column(
                children: [
                  if (_suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final value = _suggestions[index];
                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                title: Text(value),
                                onTap: () {
                                  _searchController.text = value;
                                  _searchController.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(offset: value.length),
                                  );
                                  _onSearchChanged(value);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? const Center(
                            child: Text('Nenhuma barbearia encontrada.'),
                          )
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final shop = _filtered[index];
                              final endereco = shop.endereco;
                              final subtitle =
                                  '${endereco['bairro'] ?? ''} - ${endereco['cidade'] ?? ''}';
                              final rating =
                                  _ratingsCache[shop.ownerId] ?? 0.0;
                              final ratingCount =
                                  _ratingsCountCache[shop.ownerId] ?? 0;

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 16.0),
                                child: ListTile(
                                  leading: (shop.imageThumbUrl != null &&
                                              shop.imageThumbUrl!.isNotEmpty) ||
                                          (shop.imageUrl != null &&
                                              shop.imageUrl!.isNotEmpty)
                                      ? CircleAvatar(
                                          backgroundImage: NetworkImage(
                                            (shop.imageThumbUrl != null &&
                                                    shop.imageThumbUrl!
                                                        .isNotEmpty)
                                                ? shop.imageThumbUrl!
                                                : shop.imageUrl!,
                                          ),
                                        )
                                      : const CircleAvatar(
                                          child: Icon(Icons.storefront)),
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(shop.nome)),
                                      if (rating > 0)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 16,
                                              color: Colors.amber,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              ratingCount > 0
                                                  ? '${rating.toStringAsFixed(1)} ($ratingCount)'
                                                  : rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(subtitle.trim().isNotEmpty
                                      ? subtitle
                                      : 'Endereço não informado'),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            BarbershopProfilePage(
                                                barbershop: shop),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

