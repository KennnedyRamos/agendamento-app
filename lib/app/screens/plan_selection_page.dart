import 'package:agendamento_app/app/models/barbershop.dart';
import 'package:agendamento_app/app/screens/plan_details_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlanSelectionPage extends StatelessWidget {
  final Barbershop barbershop;

  const PlanSelectionPage({super.key, required this.barbershop});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planos mensais'),
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
            if (barbershop.monthlyPlans.isEmpty)
              const Text('Nenhum plano disponível.'),
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
                          builder: (context) =>
                              PlanDetailsPage(barbershop: barbershop, plan: plan),
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
