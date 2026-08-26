import 'package:agendamento_app/app/models/barbershop.dart';
import 'package:agendamento_app/app/models/chat_conversation.dart';
import 'package:agendamento_app/app/screens/booking_page.dart';
import 'package:agendamento_app/app/screens/chat_page.dart';
import 'package:agendamento_app/app/screens/plan_details_page.dart';
import 'package:agendamento_app/app/screens/plan_selection_page.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/review_service.dart';
import 'package:agendamento_app/app/utils/map_utils.dart';
import 'package:agendamento_app/app/widgets/barbershop_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

class BarbershopProfilePage extends StatelessWidget {
  final Barbershop barbershop;

  const BarbershopProfilePage({super.key, required this.barbershop});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reviewService = ReviewService();
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final addressText = MapUtils.buildAddress(barbershop.endereco);
    final hasLocation =
        barbershop.latitude != null && barbershop.longitude != null;
    final canOpenMap = addressText.isNotEmpty || hasLocation;
    final locationLabel = (barbershop.locationLabel ?? '').trim();
    final mapCenter = hasLocation
        ? LatLng(barbershop.latitude!, barbershop.longitude!)
        : const LatLng(-15.793889, -47.882778);

    Future<void> showReviewDialog({int? initialRating}) async {
      int rating = initialRating ?? 5;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                title: const Text('Avaliar atendimento'),
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final isFilled = index < rating;
                    return IconButton(
                      onPressed: () {
                        setModalState(() {
                          rating = index + 1;
                        });
                      },
                      icon: Icon(
                        isFilled ? Icons.star : Icons.star_border,
                      ),
                    );
                  }),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Enviar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true) {
        try {
          await reviewService.createReview(
            barberId: barbershop.ownerId,
            rating: rating,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avaliação enviada.')),
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao avaliar: ${e.toString()}')),
          );
        }
      }
    }

    Future<void> openReviewFlow() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado.')),
        );
        return;
      }

      final existingRating =
          await reviewService.getReviewRating(barbershop.ownerId);
      if (!context.mounted) return;
      await showReviewDialog(initialRating: existingRating);
    }

    Future<void> openChat() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado.')),
        );
        return;
      }

      try {
        final profile = await AppFirestoreService().getUserProfile(user.uid);
        if (!context.mounted) return;
        final profileName = [profile?.nome, profile?.sobrenome]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .join(' ');
        final fallbackName = (user.displayName ?? '').trim().isNotEmpty
            ? user.displayName!.trim()
            : (user.email?.split('@').first ?? 'Cliente');
        final conversation = ChatConversation.between(
          barberId: barbershop.ownerId,
          clientId: user.uid,
          barbershopId: barbershop.id,
          barbershopName: barbershop.nome,
          clientName: profileName.isEmpty ? fallbackName : profileName,
        );
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(conversation: conversation),
          ),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o chat: $error')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil da barbearia'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.primary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BarbershopImage(
                logoData: barbershop.logoData,
                imageUrl: barbershop.imageUrl,
                height: 180,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    barbershop.nome,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                StreamBuilder(
                  stream:
                      reviewService.watchReviewsForBarber(barbershop.ownerId),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    final ratingByClient = <String, double>{};
                    for (final doc in docs) {
                      final data = doc.data();
                      final clientId = data['clientId']?.toString() ?? doc.id;
                      final rating = data['rating'] ?? 0;
                      ratingByClient[clientId] =
                          (rating is int) ? rating.toDouble() : 0.0;
                    }
                    if (ratingByClient.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final values = ratingByClient.values.toList();
                    final total = values.fold<double>(
                        0.0, (totalSoFar, v) => totalSoFar + v);
                    final avg = total / values.length;
                    final count = values.length;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${avg.toStringAsFixed(1)} ($count)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              addressText.isEmpty
                  ? 'Endereço: não informado.'
                  : 'Endereço: $addressText',
            ),
            if (locationLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Referência: $locationLabel'),
            ],
            const SizedBox(height: 6),
            if (barbershop.telefone.trim().isNotEmpty)
              Text('Telefone: ${barbershop.telefone}')
            else if ((barbershop.pixKeyType ?? '') == 'telefone' &&
                (barbershop.pixKey ?? '').trim().isNotEmpty)
              Text('Telefone: ${barbershop.pixKey}')
            else
              FutureBuilder(
                future:
                    AppFirestoreService().getUserProfile(barbershop.ownerId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Telefone: carregando...');
                  }
                  final profile = snapshot.data;
                  final phone =
                      profile == null || profile.telefone.trim().isEmpty
                          ? 'Telefone não encontrado.'
                          : profile.telefone;
                  return Text('Telefone: $phone');
                },
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: openChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Enviar mensagem'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canOpenMap
                        ? () async {
                            if (!MapUtils.hasValidAddress(
                                  barbershop.endereco,
                                ) &&
                                !MapUtils.hasCoordinates(
                                  barbershop.latitude,
                                  barbershop.longitude,
                                )) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Endereço não informado para abrir o mapa.'),
                                ),
                              );
                              return;
                            }
                            final ok = await MapUtils.openMapSearch(
                              endereco: barbershop.endereco,
                              name: barbershop.nome,
                              latitude: barbershop.latitude,
                              longitude: barbershop.longitude,
                            );
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Não foi possível abrir o mapa.'),
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ver no mapa'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canOpenMap
                        ? () async {
                            if (!MapUtils.hasValidAddress(
                                  barbershop.endereco,
                                ) &&
                                !MapUtils.hasCoordinates(
                                  barbershop.latitude,
                                  barbershop.longitude,
                                )) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Endereço não informado para abrir o mapa.'),
                                ),
                              );
                              return;
                            }
                            final ok = await MapUtils.openDirections(
                              endereco: barbershop.endereco,
                              name: barbershop.nome,
                              latitude: barbershop.latitude,
                              longitude: barbershop.longitude,
                            );
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Não foi possível abrir o mapa.'),
                                ),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.directions),
                    label: const Text('Como chegar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasLocation)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 160,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.ramos.kennedy.barberapp',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: mapCenter,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            StreamBuilder(
              stream: reviewService.watchReviewsForBarber(barbershop.ownerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final docs = snapshot.data?.docs ?? [];
                final ratingByClient = <String, double>{};
                for (final doc in docs) {
                  final data = doc.data();
                  final clientId = data['clientId']?.toString() ?? doc.id;
                  final rating = data['rating'] ?? 0;
                  ratingByClient[clientId] =
                      (rating is int) ? rating.toDouble() : 0.0;
                }
                if (ratingByClient.isEmpty) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sem avaliações ainda.'),
                    ],
                  );
                }
                final values = ratingByClient.values.toList();
                final total =
                    values.fold<double>(0.0, (totalSoFar, v) => totalSoFar + v);
                final avg = total / values.length;
                final count = values.length;
                return Card(
                  child: ListTile(
                    title: const Text('Avaliações'),
                    subtitle: _StarsRow(rating: avg),
                    trailing: Text(
                      count == 0
                          ? avg.toStringAsFixed(1)
                          : '${avg.toStringAsFixed(1)} ($count)',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 14),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            FutureBuilder<bool>(
              future: reviewService.hasReview(barbershop.ownerId),
              builder: (context, snapshot) {
                final hasReview = snapshot.data ?? false;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: openReviewFlow,
                    icon: Icon(hasReview ? Icons.edit : Icons.star, size: 18),
                    label: Text(
                      hasReview ? 'Editar avaliação' : 'Avaliar',
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Serviços e preços',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (barbershop.services.isEmpty)
              const Text('Nenhum serviço cadastrado.')
            else
              ...barbershop.services.map((serviceItem) {
                final price = currency.format(serviceItem.preco);
                return Card(
                  child: ListTile(
                    title: Text(serviceItem.nome),
                    trailing: Text(price),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text(
              'Planos mensais',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (barbershop.monthlyPlans.isEmpty)
              const Text('Nenhum plano disponível.')
            else
              ...barbershop.monthlyPlans.map((plan) {
                final price = currency.format(plan.price);
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.35),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.18),
                          colorScheme.primary.withValues(alpha: 0.06),
                        ],
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.2),
                        child: Icon(Icons.star, color: colorScheme.primary),
                      ),
                      title: Text(
                        plan.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Valor: $price'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlanDetailsPage(
                                barbershop: barbershop, plan: plan),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PlanSelectionPage(barbershop: barbershop),
                  ),
                );
              },
              icon: const Icon(Icons.local_offer),
              label: const Text('Ver planos mensais'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingPage(barbershop: barbershop),
                  ),
                );
              },
              icon: const Icon(Icons.event_available),
              label: const Text('Agendar horário'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: openReviewFlow,
              icon: const Icon(Icons.star),
              label: const Text('Avaliar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  final double rating;

  const _StarsRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    return Row(
      children: List.generate(5, (index) {
        final filled = index < full;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 18,
        );
      }),
    );
  }
}
