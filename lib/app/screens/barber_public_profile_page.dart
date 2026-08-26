import 'package:agendamento_app/app/models/barbershop.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/review_service.dart';
import 'package:agendamento_app/app/widgets/barbershop_image.dart';
import 'package:flutter/material.dart';

class BarberPublicProfilePage extends StatelessWidget {
  final Barbershop barbershop;

  const BarberPublicProfilePage({super.key, required this.barbershop});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final service = AppFirestoreService();
    final reviewService = ReviewService();

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do barbeiro'),
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
            Text(
              barbershop.nome,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${barbershop.endereco['rua'] ?? ''}, ${barbershop.endereco['numero'] ?? ''} - ${barbershop.endereco['bairro'] ?? ''}, ${barbershop.endereco['cidade'] ?? ''}',
            ),
            const SizedBox(height: 16),
            FutureBuilder(
              future: service.getUserProfile(barbershop.ownerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (!snapshot.hasData) {
                  return const Text('Dados do barbeiro não encontrado.');
                }
                final profile = snapshot.data!;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          colorScheme.primary.withValues(alpha: 0.15),
                      child: const Icon(Icons.person),
                    ),
                    title: Text(
                      '${profile.nome} ${profile.sobrenome}'.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Telefone: ${profile.telefone}'),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
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
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sem avaliações ainda.'),
                      const SizedBox(height: 6),
                      FutureBuilder<bool>(
                        future: reviewService.hasReview(barbershop.ownerId),
                        builder: (context, ratingSnapshot) {
                          final hasReview = ratingSnapshot.data ?? false;
                          return TextButton.icon(
                            onPressed: () async {
                              if (hasReview) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Você já avaliou esse barbeiro.'),
                                  ),
                                );
                                return;
                              }
                              await showReviewDialog();
                            },
                            icon: Icon(
                              hasReview ? Icons.edit : Icons.star,
                              size: 18,
                            ),
                            label: Text(
                              hasReview ? 'Editar avaliação' : 'Avaliar',
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }
                final values = ratingByClient.values.toList();
                final total =
                    values.fold<double>(0.0, (totalSoFar, v) => totalSoFar + v);
                final avg = total / values.length;
                return Card(
                  child: ListTile(
                    title: const Text('Avaliações'),
                    subtitle: _StarsRow(rating: avg),
                    trailing: Text(
                      avg.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            FutureBuilder<bool>(
              future: reviewService.hasReview(barbershop.ownerId),
              builder: (context, ratingSnapshot) {
                final hasReview = ratingSnapshot.data ?? false;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      if (hasReview) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Você já avaliou esse barbeiro.'),
                          ),
                        );
                        return;
                      }
                      await showReviewDialog();
                    },
                    icon: Icon(hasReview ? Icons.edit : Icons.star, size: 18),
                    label: Text(hasReview ? 'Editar avaliação' : 'Avaliar'),
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
