import 'package:agendamento_app/app/models/financial_dashboard.dart';
import 'package:agendamento_app/app/services/mercado_pago_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class BarberFinancialTab extends StatefulWidget {
  final VoidCallback? onOpenBarbershop;

  const BarberFinancialTab({super.key, this.onOpenBarbershop});

  @override
  State<BarberFinancialTab> createState() => _BarberFinancialTabState();
}

class _BarberFinancialTabState extends State<BarberFinancialTab> {
  final MercadoPagoService _service = MercadoPagoService();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  FinancialDashboard? _dashboard;
  int _periodDays = 30;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading) setState(() => _loading = true);
    try {
      final dashboard = await _service.financialDashboard(
        periodDays: _periodDays,
      );
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _error = null;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == 'not-found' || error.code == 'unavailable'
            ? 'O painel financeiro será liberado quando o servidor de pagamentos for ativado.'
            : error.message ?? 'Não foi possível carregar o painel financeiro.';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar o painel financeiro.';
        _loading = false;
      });
    }
  }

  Future<void> _changePeriod(int periodDays) async {
    if (_periodDays == periodDays) return;
    setState(() => _periodDays = periodDays);
    await _load();
  }

  Future<void> _openMercadoPago() async {
    final opened = await launchUrl(
      Uri.parse('https://www.mercadopago.com.br/activities'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Mercado Pago.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_dashboard == null) {
      return _FinancialUnavailable(
        message: _error ?? 'Painel indisponível.',
        onRetry: _load,
      );
    }

    final dashboard = _dashboard!;
    final summary = dashboard.summary;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        children: [
          _FinancialHero(
            netRevenue: _currency.format(summary.netRevenue),
            grossRevenue: _currency.format(summary.grossRevenue),
            periodDays: dashboard.periodDays,
            isEstimated: summary.hasEstimatedOnlineValues,
          ),
          const SizedBox(height: 16),
          _PeriodSelector(
            selected: _periodDays,
            onSelected: _changePeriod,
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          _FeePolicyBanner(policy: dashboard.feePolicy),
          const SizedBox(height: 16),
          _MetricsGrid(
            cards: [
              _MetricData(
                icon: Icons.pix_rounded,
                label: 'Recebido online',
                value: _currency.format(summary.onlineGross),
                detail: '${summary.paidOnlineCount} pagamentos',
              ),
              _MetricData(
                icon: Icons.payments_rounded,
                label: 'Dinheiro recebido',
                value: _currency.format(summary.cashReceived),
                detail: '${summary.completedCashCount} atendimentos',
              ),
              _MetricData(
                icon: Icons.schedule_rounded,
                label: 'A receber no local',
                value: _currency.format(summary.cashScheduled),
                detail: '${summary.scheduledCashCount} agendamentos',
              ),
              _MetricData(
                icon: Icons.hourglass_top_rounded,
                label: 'Online pendente',
                value: _currency.format(summary.pendingOnline),
                detail: '${summary.pendingOnlineCount} pagamentos',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FeeBreakdownCard(
            onlineGross: summary.onlineGross,
            onlineNet: summary.onlineNet,
            marketplaceFees: summary.marketplaceFees,
            mercadoPagoFees: summary.mercadoPagoFees,
            currency: _currency,
            isEstimated: summary.hasEstimatedOnlineValues,
          ),
          const SizedBox(height: 16),
          _MercadoPagoBalanceCard(
            connected: dashboard.paymentConnected,
            onlineNet: _currency.format(summary.onlineNet),
            onOpenMercadoPago: _openMercadoPago,
            onConnect: widget.onOpenBarbershop,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Movimentações recentes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Atualizar',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (dashboard.transactions.isEmpty)
            const _EmptyTransactions()
          else
            ...dashboard.transactions.map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionCard(
                  transaction: transaction,
                  currency: _currency,
                ),
              ),
            ),
          if (summary.hasEstimatedOnlineValues) ...[
            const SizedBox(height: 8),
            Text(
              'Valores marcados como estimados serão atualizados após o Mercado Pago informar o líquido real.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _FinancialHero extends StatelessWidget {
  final String netRevenue;
  final String grossRevenue;
  final int periodDays;
  final bool isEstimated;

  const _FinancialHero({
    required this.netRevenue,
    required this.grossRevenue,
    required this.periodDays,
    required this.isEstimated,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [colors.primary, colors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.24),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: colors.onPrimary),
              const SizedBox(width: 9),
              Text(
                'Receita líquida${isEstimated ? ' estimada' : ''}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.onPrimary.withValues(alpha: 0.88),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            netRevenue,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bruto $grossRevenue • últimos $periodDays dias',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimary.withValues(alpha: 0.82),
                ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _PeriodSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const periods = {7: '7 dias', 30: '30 dias', 90: '90 dias', 365: '1 ano'};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected == entry.key,
              onSelected: (_) => onSelected(entry.key),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _FeePolicyBanner extends StatelessWidget {
  final FinancialFeePolicy policy;

  const _FeePolicyBanner({required this.policy});

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

class _MetricData {
  final IconData icon;
  final String label;
  final String value;
  final String detail;

  const _MetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });
}

class _MetricsGrid extends StatelessWidget {
  final List<_MetricData> cards;

  const _MetricsGrid({required this.cards});

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
          margin: EdgeInsets.zero,
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
                Text(data.detail,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeeBreakdownCard extends StatelessWidget {
  final double onlineGross;
  final double onlineNet;
  final double marketplaceFees;
  final double mercadoPagoFees;
  final NumberFormat currency;
  final bool isEstimated;

  const _FeeBreakdownCard({
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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalhamento online',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 15),
            _BreakdownRow(
                label: 'Valor bruto', value: currency.format(onlineGross)),
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

class _MercadoPagoBalanceCard extends StatelessWidget {
  final bool connected;
  final String onlineNet;
  final VoidCallback onOpenMercadoPago;
  final VoidCallback? onConnect;

  const _MercadoPagoBalanceCard({
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
              Icon(Icons.account_balance_rounded,
                  color: colors.onPrimaryContainer),
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
                ? '$onlineNet líquidos registrados no período. Consulte o saldo disponível e transfira via Pix no Mercado Pago.'
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

class _TransactionCard extends StatelessWidget {
  final FinancialTransaction transaction;
  final NumberFormat currency;

  const _TransactionCard({required this.transaction, required this.currency});

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
      margin: EdgeInsets.zero,
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

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 42, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 10),
            Text('Nenhuma movimentação no período.',
                style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _FinancialUnavailable extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FinancialUnavailable({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 54, color: Theme.of(context).colorScheme.outline),
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
