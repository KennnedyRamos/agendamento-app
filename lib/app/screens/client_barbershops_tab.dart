import 'dart:async';

import 'package:agendamento_app/app/models/barbershop.dart';
import 'package:agendamento_app/app/screens/barbershop_profile_page.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/review_service.dart';
import 'package:agendamento_app/app/widgets/barbershop_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
  final Set<String> _ratingLoads = {};
  Position? _currentPosition;
  _LocationAccessStatus _locationStatus = _LocationAccessStatus.loading;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

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
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  Future<void> _loadCurrentLocation() async {
    if (mounted) {
      setState(() => _locationStatus = _LocationAccessStatus.loading);
    }
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _locationStatus = _LocationAccessStatus.serviceOff);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final shouldRequest = await _confirmLocationUse();
        if (!shouldRequest) {
          if (!mounted) return;
          setState(() => _locationStatus = _LocationAccessStatus.denied);
          return;
        }
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locationStatus = _LocationAccessStatus.deniedForever);
        return;
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() => _locationStatus = _LocationAccessStatus.denied);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _locationStatus = _LocationAccessStatus.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationStatus = _LocationAccessStatus.error);
    }
  }

  Future<bool> _confirmLocationUse() async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.near_me_rounded),
            title: const Text('Encontrar barbearias próximas'),
            content: const Text(
              'O BarberKR usa sua localização somente enquanto esta tela está '
              'aberta para ordenar as barbearias por distância. Sua localização '
              'não é salva no seu perfil.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Agora não'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleLocationAction() async {
    switch (_locationStatus) {
      case _LocationAccessStatus.serviceOff:
        await Geolocator.openLocationSettings();
        await _loadCurrentLocation();
        return;
      case _LocationAccessStatus.deniedForever:
        await Geolocator.openAppSettings();
        await _loadCurrentLocation();
        return;
      case _LocationAccessStatus.denied:
      case _LocationAccessStatus.error:
      case _LocationAccessStatus.loading:
      case _LocationAccessStatus.ready:
        await _loadCurrentLocation();
        return;
    }
  }

  double? _distanceTo(Barbershop shop) {
    final position = _currentPosition;
    if (position == null || shop.latitude == null || shop.longitude == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      shop.latitude!,
      shop.longitude!,
    );
  }

  void _recomputeFilters(List<Barbershop> shops) {
    final locationSignature = _currentPosition == null
        ? 'no-location'
        : '${_currentPosition!.latitude}:${_currentPosition!.longitude}';
    final signature =
        '${shops.map((shop) => '${shop.id}:${shop.latitude}:${shop.longitude}').join('|')}@$locationSignature';
    if (signature == _lastSignature && _query == _lastQuery) return;
    _lastSignature = signature;
    _lastQuery = _query;

    if (_query.isEmpty) {
      _filtered = List<Barbershop>.of(shops);
      _suggestions = [];
    } else {
      _filtered = shops
          .where((shop) =>
              shop.nomeLower.contains(_query) ||
              shop.nome.toLowerCase().contains(_query) ||
              shop.bairroLower.contains(_query) ||
              shop.cidadeLower.contains(_query))
          .toList();

      final suggestions = <String>{};
      for (final shop in shops) {
        if (shop.nomeLower.contains(_query)) suggestions.add(shop.nome);
        if (shop.bairroLower.contains(_query)) {
          final bairro = shop.endereco['bairro'] ?? '';
          if (bairro.isNotEmpty) suggestions.add(bairro);
        }
        if (shop.cidadeLower.contains(_query)) {
          final cidade = shop.endereco['cidade'] ?? '';
          if (cidade.isNotEmpty) suggestions.add(cidade);
        }
        if (suggestions.length >= 6) break;
      }
      _suggestions = suggestions.toList();
    }

    if (_currentPosition != null) {
      _filtered.sort((first, second) {
        final firstDistance = _distanceTo(first);
        final secondDistance = _distanceTo(second);
        if (firstDistance == null && secondDistance == null) return 0;
        if (firstDistance == null) return 1;
        if (secondDistance == null) return -1;
        return firstDistance.compareTo(secondDistance);
      });
    }
  }

  Future<void> _ensureRatings(List<Barbershop> shops) async {
    final targets = shops
        .where((shop) =>
            !_ratingsCache.containsKey(shop.ownerId) &&
            !_ratingLoads.contains(shop.ownerId))
        .map((shop) => shop.ownerId)
        .toSet();
    if (targets.isEmpty) return;
    _ratingLoads.addAll(targets);

    for (final barberId in targets) {
      try {
        final snapshot =
            await _reviewService.watchReviewsForBarber(barberId).first;
        final ratingByClient = <String, double>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final clientId = data['clientId']?.toString() ?? doc.id;
          final rating = data['rating'] ?? 0;
          ratingByClient[clientId] = rating is num ? rating.toDouble() : 0.0;
        }
        if (!mounted) continue;
        setState(() {
          if (ratingByClient.isEmpty) {
            _ratingsCache[barberId] = 0;
            _ratingsCountCache[barberId] = 0;
          } else {
            final values = ratingByClient.values.toList();
            final total = values.fold<double>(0, (sum, value) => sum + value);
            _ratingsCache[barberId] = total / values.length;
            _ratingsCountCache[barberId] = values.length;
          }
        });
      } finally {
        _ratingLoads.remove(barberId);
      }
    }
  }

  void _openShop(Barbershop shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarbershopProfilePage(barbershop: shop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Barbershop>>(
      stream: _firestoreService.watchBarbershops(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _MessageState(
            icon: Icons.cloud_off_rounded,
            title: 'Não foi possível carregar',
            message: 'Confira sua conexão e tente novamente.',
          );
        }

        final shops = snapshot.data ?? [];
        _recomputeFilters(shops);
        _ensureRatings(_filtered);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _DiscoverHero(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onClear: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _LocationSuggestionCard(
                status: _locationStatus,
                onAction: _handleLocationAction,
              ),
            ),
            if (_suggestions.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _suggestions.map((value) {
                      return ActionChip(
                        avatar: const Icon(Icons.north_west_rounded, size: 16),
                        label: Text(value),
                        onPressed: () {
                          _searchController.text = value;
                          _searchController.selection =
                              TextSelection.collapsed(offset: value.length);
                          _onSearchChanged(value);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _query.isEmpty
                            ? (_currentPosition == null
                                ? 'Barbearias para você'
                                : 'Mais perto de você')
                            : 'Resultados da busca',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_filtered.length}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(
                  icon: Icons.search_off_rounded,
                  title: 'Nenhuma barbearia encontrada',
                  message: 'Tente buscar por outro nome, bairro ou cidade.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final shop = _filtered[index];
                    return _BarbershopCard(
                      shop: shop,
                      rating: _ratingsCache[shop.ownerId] ?? 0,
                      ratingCount: _ratingsCountCache[shop.ownerId] ?? 0,
                      distanceMeters: _distanceTo(shop),
                      onTap: () => _openShop(shop),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DiscoverHero extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _DiscoverHero({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F3B33),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/barber_home_hero.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF20B4C42),
                  Color(0xC70B4C42),
                  Color(0x220B4C42),
                ],
                stops: [0, 0.54, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE76F51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'NOVO VISUAL, NOVA ENERGIA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const SizedBox(
                  width: 235,
                  child: Text(
                    'Encontre seu próximo estilo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.04,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Agende perto de você, sem complicação.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: 'Nome, bairro ou cidade',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: onClear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: const Color(0xF7FFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarbershopCard extends StatelessWidget {
  final Barbershop shop;
  final double rating;
  final int ratingCount;
  final double? distanceMeters;
  final VoidCallback onTap;

  const _BarbershopCard({
    required this.shop,
    required this.rating,
    required this.ratingCount,
    required this.distanceMeters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bairro = shop.endereco['bairro'] ?? '';
    final cidade = shop.endereco['cidade'] ?? '';
    final location =
        [bairro, cidade].where((value) => value.trim().isNotEmpty).join(' • ');
    final imageUrl = shop.imageThumbUrl?.isNotEmpty == true
        ? shop.imageThumbUrl
        : shop.imageUrl;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 104,
                  height: 112,
                  child: BarbershopImage(
                    logoData: shop.logoData,
                    imageUrl: imageUrl,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 112,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              shop.nome,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (rating > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0CC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 15,
                                    color: Color(0xFFE9A922),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: colors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location.isEmpty
                                  ? 'Localização não informada'
                                  : location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          if (distanceMeters != null) ...[
                            Icon(
                              Icons.near_me_rounded,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDistance(distanceMeters!),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colors.primary),
                            ),
                          ] else if (shop.paymentConnected) ...[
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pix e cartão',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colors.primary),
                            ),
                          ] else
                            Text(
                              ratingCount == 0
                                  ? 'Conheça o espaço'
                                  : '$ratingCount avaliações',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          const Spacer(),
                          Text(
                            'Ver horários',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.primary),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final kilometers = (meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0);
    return '${kilometers.replaceAll('.', ',')} km';
  }
}

enum _LocationAccessStatus {
  loading,
  ready,
  denied,
  deniedForever,
  serviceOff,
  error,
}

class _LocationSuggestionCard extends StatelessWidget {
  final _LocationAccessStatus status;
  final Future<void> Function() onAction;

  const _LocationSuggestionCard({
    required this.status,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isReady = status == _LocationAccessStatus.ready;
    final isLoading = status == _LocationAccessStatus.loading;
    final title = switch (status) {
      _LocationAccessStatus.ready => 'Sugestões pela sua localização',
      _LocationAccessStatus.loading => 'Buscando barbearias próximas...',
      _LocationAccessStatus.serviceOff => 'Ative a localização do aparelho',
      _LocationAccessStatus.deniedForever =>
        'Permita a localização nas configurações',
      _LocationAccessStatus.denied => 'Encontre barbearias perto de você',
      _LocationAccessStatus.error => 'Não conseguimos obter sua localização',
    };
    final subtitle = isReady
        ? 'A lista está ordenada da mais próxima para a mais distante.'
        : isLoading
            ? 'Isso leva só alguns segundos.'
            : 'Você ainda pode pesquisar e agendar sem compartilhar sua localização.';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      color: isReady
          ? colors.primaryContainer.withValues(alpha: 0.62)
          : colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  isReady ? colors.primary : colors.secondaryContainer,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isReady
                          ? Icons.near_me_rounded
                          : Icons.location_on_outlined,
                      color: isReady
                          ? colors.onPrimary
                          : colors.onSecondaryContainer,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (!isReady && !isLoading)
              TextButton(
                onPressed: onAction,
                child: Text(
                  status == _LocationAccessStatus.deniedForever ||
                          status == _LocationAccessStatus.serviceOff
                      ? 'Configurar'
                      : 'Permitir',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colors.onPrimaryContainer, size: 30),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
