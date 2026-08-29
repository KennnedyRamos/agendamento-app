import 'package:agendamento_app/app/models/financial_dashboard.dart';
import 'package:agendamento_app/app/services/mercado_pago_service.dart';
import 'package:agendamento_app/app/widgets/financial_dashboard_widgets.dart';
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
  late DateTime _selectedMonth;
  bool _loading = true;
  bool _showAllTransactions = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _load();
  }

  List<DateTime> get _availableMonths {
    final now = DateTime.now();
    return List.generate(
      6,
      (index) => DateTime(now.year, now.month - (5 - index)),
      growable: false,
    );
  }

  Future<void> _load() async {
    if (!_loading) setState(() => _loading = true);
    try {
      final dashboard = await _service.financialDashboard(
        month: _selectedMonth,
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

  Future<void> _changeMonth(DateTime month) async {
    if (_selectedMonth.year == month.year &&
        _selectedMonth.month == month.month) {
      return;
    }
    setState(() {
      _selectedMonth = month;
      _showAllTransactions = false;
    });
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
      return FinancialUnavailable(
        message: _error ?? 'Painel indisponível.',
        onRetry: _load,
      );
    }

    final dashboard = _dashboard!;
    final summary = dashboard.summary;
    final completedCount = summary.paidOnlineCount + summary.completedCashCount;
    final visibleTransactions = _showAllTransactions
        ? dashboard.transactions
        : dashboard.transactions.take(6);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        children: [
          const FinancialHeading(),
          const SizedBox(height: 18),
          FinancialMonthSelector(
            months: _availableMonths,
            selected: _selectedMonth,
            onSelected: _changeMonth,
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            FinancialInlineWarning(message: _error!),
          ],
          const SizedBox(height: 16),
          RevenueOverviewCard(
            selectedMonth: _selectedMonth,
            netRevenue: _currency.format(summary.netRevenue),
            grossRevenue: _currency.format(summary.grossRevenue),
            completedCount: completedCount,
            dailyRevenue: dashboard.dailyRevenue,
            currency: _currency,
            isEstimated: summary.hasEstimatedOnlineValues,
          ),
          const SizedBox(height: 16),
          FeePolicyBanner(policy: dashboard.feePolicy),
          const SizedBox(height: 24),
          FinancialSectionTitle(
            eyebrow: 'DESEMPENHO',
            title: 'Serviços realizados',
            detail: '$completedCount no mês',
          ),
          const SizedBox(height: 12),
          ServiceBreakdownList(
            services: dashboard.serviceBreakdown,
            currency: _currency,
          ),
          const SizedBox(height: 24),
          const FinancialSectionTitle(
            eyebrow: 'VISÃO GERAL',
            title: 'Entradas e previsões',
          ),
          const SizedBox(height: 12),
          FinancialMetricsGrid(
            cards: [
              FinancialMetricData(
                icon: Icons.pix_rounded,
                label: 'Online recebido',
                value: _currency.format(summary.onlineGross),
                detail: '${summary.paidOnlineCount} pagamentos',
              ),
              FinancialMetricData(
                icon: Icons.payments_rounded,
                label: 'Dinheiro recebido',
                value: _currency.format(summary.cashReceived),
                detail: '${summary.completedCashCount} atendimentos',
              ),
              FinancialMetricData(
                icon: Icons.schedule_rounded,
                label: 'A receber no local',
                value: _currency.format(summary.cashScheduled),
                detail: '${summary.scheduledCashCount} agendamentos',
              ),
              FinancialMetricData(
                icon: Icons.hourglass_top_rounded,
                label: 'Online pendente',
                value: _currency.format(summary.pendingOnline),
                detail: '${summary.pendingOnlineCount} pagamentos',
              ),
            ],
          ),
          const SizedBox(height: 16),
          FeeBreakdownCard(
            onlineGross: summary.onlineGross,
            onlineNet: summary.onlineNet,
            marketplaceFees: summary.marketplaceFees,
            mercadoPagoFees: summary.mercadoPagoFees,
            currency: _currency,
            isEstimated: summary.hasEstimatedOnlineValues,
          ),
          const SizedBox(height: 16),
          MercadoPagoBalanceCard(
            connected: dashboard.paymentConnected,
            onlineNet: _currency.format(summary.onlineNet),
            onOpenMercadoPago: _openMercadoPago,
            onConnect: widget.onOpenBarbershop,
          ),
          const SizedBox(height: 24),
          FinancialSectionTitle(
            eyebrow: 'HISTÓRICO FINANCEIRO',
            title: 'Movimentações recentes',
            trailing: IconButton(
              tooltip: 'Atualizar',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 10),
          if (dashboard.transactions.isEmpty)
            const EmptyFinancialTransactions()
          else ...[
            ...visibleTransactions.map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FinancialTransactionCard(
                  transaction: transaction,
                  currency: _currency,
                ),
              ),
            ),
            if (dashboard.transactions.length > 6)
              TextButton.icon(
                onPressed: () {
                  setState(() => _showAllTransactions = !_showAllTransactions);
                },
                icon: Icon(
                  _showAllTransactions
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(
                  _showAllTransactions
                      ? 'Mostrar menos'
                      : 'Ver todas as movimentações',
                ),
              ),
          ],
          if (dashboard.dataLimited) ...[
            const SizedBox(height: 12),
            const FinancialInlineWarning(
              message:
                  'Este mês possui muitas movimentações. O painel mostra as 2.000 mais recentes.',
            ),
          ],
          if (summary.hasEstimatedOnlineValues) ...[
            const SizedBox(height: 12),
            Text(
              'Valores estimados serão atualizados quando o Mercado Pago informar o líquido real.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
