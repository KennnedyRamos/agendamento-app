import 'package:agendamento_app/app/models/financial_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FinancialHeading extends StatelessWidget {
  const FinancialHeading({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ANALISAR',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
        ),
        const SizedBox(height: 4),
        Text('Faturamento', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 5),
        Text(
          'Organize suas entradas e acompanhe o desempenho da barbearia.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class FinancialMonthSelector extends StatelessWidget {
  final List<DateTime> months;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  const FinancialMonthSelector({
    super.key,
    required this.months,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    String label(DateTime month) => DateFormat('MMM', 'pt_BR')
        .format(month)
        .replaceAll('.', '')
        .toUpperCase();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: months.map((month) {
          final isSelected =
              month.year == selected.year && month.month == selected.month;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label(month)),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelected(month),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class RevenueOverviewCard extends StatelessWidget {
  static const _background = Color(0xFF171C24);
  static const _accent = Color(0xFFD79A73);

  final DateTime selectedMonth;
  final String netRevenue;
  final String grossRevenue;
  final int completedCount;
  final List<FinancialDailyRevenue> dailyRevenue;
  final NumberFormat currency;
  final bool isEstimated;

  const RevenueOverviewCard({
    super.key,
    required this.selectedMonth,
    required this.netRevenue,
    required this.grossRevenue,
    required this.completedCount,
    required this.dailyRevenue,
    required this.currency,
    required this.isEstimated,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'BALANÇO DE SERVIÇOS',
                  style: TextStyle(
                    color: Color(0xFF9299A6),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(
                monthLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            netRevenue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${isEstimated ? 'Líquido estimado' : 'Valor líquido'} • bruto $grossRevenue',
            style: const TextStyle(color: Color(0xFFB7BDC7), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '$completedCount atendimento${completedCount == 1 ? '' : 's'} concluído${completedCount == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          _DailyRevenueChart(
            selectedMonth: selectedMonth,
            values: dailyRevenue,
            currency: currency,
            accent: _accent,
          ),
        ],
      ),
    );
  }
}

class _DailyRevenueChart extends StatelessWidget {
  final DateTime selectedMonth;
  final List<FinancialDailyRevenue> values;
  final NumberFormat currency;
  final Color accent;

  const _DailyRevenueChart({
    required this.selectedMonth,
    required this.values,
    required this.currency,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final byDay = {for (final value in values) value.day: value};
    final maximum = values.fold<double>(
      0,
      (current, value) => value.netAmount > current ? value.netAmount : current,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'RECEITA POR DIA',
                style: TextStyle(
                  color: Color(0xFF9299A6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Text(
              values.isEmpty ? 'Sem entradas' : 'Toque para detalhes',
              style: const TextStyle(color: Color(0xFF9299A6), fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 164,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(daysInMonth, (index) {
                final day = index + 1;
                final value = byDay[day];
                final ratio = maximum <= 0 || value == null
                    ? 0.0
                    : value.netAmount / maximum;
                final barHeight = value == null ? 6.0 : 18 + ratio * 102;
                final tooltip = value == null
                    ? 'Dia $day • sem entradas'
                    : 'Dia $day\n${value.appointmentCount} atendimento(s)\nBruto: ${currency.format(value.grossAmount)}\nLíquido: ${currency.format(value.netAmount)}';
                return SizedBox(
                  width: 38,
                  child: Tooltip(
                    message: tooltip,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          width: 24,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: value == null
                                ? const Color(0xFF343A45)
                                : accent.withValues(alpha: 0.42 + ratio * 0.58),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '$day',
                          style: const TextStyle(
                            color: Color(0xFFB7BDC7),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class FeePolicyBanner extends StatelessWidget {
  final FinancialFeePolicy policy;

  const FeePolicyBanner({super.key, required this.policy});

  String _percent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final trialDate = policy.trialEndsAt == null
        ? null
        : DateFormat('dd/MM/yyyy').format(policy.trialEndsAt!.toLocal());
    final title = policy.isTrialActive
        ? 'Primeiro mês sem comissão'
        : 'Comissão BarberKR';
    final description = policy.isTrialActive
        ? '0% até $trialDate. Depois, ${_percent(policy.configuredPercent)}% por pagamento online.'
        : '${_percent(policy.appliedPercent)}% por pagamento online aprovado.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            policy.isTrialActive
                ? Icons.celebration_rounded
                : Icons.percent_rounded,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FinancialSectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? detail;
  final Widget? trailing;

  const FinancialSectionTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    this.detail,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
              ),
              const SizedBox(height: 3),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        if (detail != null)
          Text(detail!, style: Theme.of(context).textTheme.bodySmall),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class ServiceBreakdownList extends StatelessWidget {
  final List<FinancialServiceSummary> services;
  final NumberFormat currency;

  const ServiceBreakdownList({
    super.key,
    required this.services,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const _EmptyCompact(
        icon: Icons.content_cut_rounded,
        message: 'Nenhum serviço concluído neste mês.',
      );
    }
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final service = services[index];
          return _ServiceSummaryCard(service: service, currency: currency);
        },
      ),
    );
  }
}

class _ServiceSummaryCard extends StatelessWidget {
  final FinancialServiceSummary service;
  final NumberFormat currency;

  const _ServiceSummaryCard({required this.service, required this.currency});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 154,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${service.appointmentCount}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colors.secondary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          Text(
            service.serviceName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 5),
          Text(
            currency.format(service.grossAmount),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class FinancialMetricData {
  final IconData icon;
  final String label;
  final String value;
  final String detail;

  const FinancialMetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });
}

class FinancialMetricsGrid extends StatelessWidget {
  final List<FinancialMetricData> cards;

  const FinancialMetricsGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.18,
      ),
      itemBuilder: (context, index) {
        final data = cards[index];
        final colors = Theme.of(context).colorScheme;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(data.icon, color: colors.primary),
                const Spacer(),
                Text(data.label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.detail,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FeeBreakdownCard extends StatelessWidget {
  final double onlineGross;
  final double onlineNet;
  final double marketplaceFees;
  final double mercadoPagoFees;
  final NumberFormat currency;
  final bool isEstimated;

  const FeeBreakdownCard({
    super.key,
    required this.onlineGross,
    required this.onlineNet,
    required this.marketplaceFees,
    required this.mercadoPagoFees,
    required this.currency,
    required this.isEstimated,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalhamento online',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 15),
            _BreakdownRow(
              label: 'Valor bruto',
              value: currency.format(onlineGross),
            ),
            _BreakdownRow(
              label: 'Comissão BarberKR',
              value: '- ${currency.format(marketplaceFees)}',
            ),
            _BreakdownRow(
              label: 'Taxas Mercado Pago${isEstimated ? ' *' : ''}',
              value: isEstimated
                  ? 'A confirmar'
                  : '- ${currency.format(mercadoPagoFees)}',
            ),
            const Divider(height: 24),
            _BreakdownRow(
              label: 'Líquido online${isEstimated ? ' estimado' : ''}',
              value: currency.format(onlineNet),
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _BreakdownRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class MercadoPagoBalanceCard extends StatelessWidget {
  final bool connected;
  final String onlineNet;
  final VoidCallback onOpenMercadoPago;
  final VoidCallback? onConnect;

  const MercadoPagoBalanceCard({
    super.key,
    required this.connected,
    required this.onlineNet,
    required this.onOpenMercadoPago,
    this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_rounded,
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  connected
                      ? 'Conta Mercado Pago conectada'
                      : 'Conecte o Mercado Pago',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            connected
                ? '$onlineNet líquidos registrados no mês. Consulte o saldo disponível e transfira via Pix no Mercado Pago.'
                : 'Conecte sua conta para receber Pix e saldo Mercado Pago diretamente.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (connected)
            OutlinedButton.icon(
              onPressed: onOpenMercadoPago,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Gerenciar no Mercado Pago'),
            )
          else if (onConnect != null)
            FilledButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.link_rounded),
              label: const Text('Conectar conta'),
            ),
        ],
      ),
    );
  }
}

class FinancialTransactionCard extends StatelessWidget {
  final FinancialTransaction transaction;
  final NumberFormat currency;

  const FinancialTransactionCard({
    super.key,
    required this.transaction,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = switch (transaction.status) {
      'paid' => ('Recebido', colors.primary, Icons.check_circle_rounded),
      'pending' => ('Pendente', colors.tertiary, Icons.schedule_rounded),
      'review' => ('Em análise', colors.tertiary, Icons.manage_search_rounded),
      'expired' => ('Expirado', colors.outline, Icons.timer_off_rounded),
      _ => ('Não concluído', colors.error, Icons.error_outline_rounded),
    };
    final date = transaction.occurredAt == null
        ? 'Data indisponível'
        : DateFormat("dd/MM/yyyy 'às' HH:mm")
            .format(transaction.occurredAt!.toLocal());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: status.$2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(status.$3, color: status.$2, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${transaction.clientName} • ${transaction.methodLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(date, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(transaction.amount),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.$1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: status.$2,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FinancialInlineWarning extends StatelessWidget {
  final String message;

  const FinancialInlineWarning({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCompact extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCompact({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class EmptyFinancialTransactions extends StatelessWidget {
  const EmptyFinancialTransactions({super.key});

  @override
  Widget build(BuildContext context) {
    return const _EmptyCompact(
      icon: Icons.receipt_long_outlined,
      message: 'Nenhuma movimentação no mês.',
    );
  }
}

class FinancialUnavailable extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const FinancialUnavailable({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
