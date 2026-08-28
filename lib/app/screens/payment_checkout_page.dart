import 'dart:async';

import 'package:agendamento_app/app/models/barbershop.dart';
import 'package:agendamento_app/app/models/service_item.dart';
import 'package:agendamento_app/app/screens/client_home_page.dart';
import 'package:agendamento_app/app/services/app_firestore_service.dart';
import 'package:agendamento_app/app/services/appointment_service.dart';
import 'package:agendamento_app/app/services/mercado_pago_service.dart';
import 'package:agendamento_app/app/widgets/barbershop_image.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentCheckoutPage extends StatefulWidget {
  final Barbershop barbershop;
  final ServiceItem service;
  final DateTime date;
  final String hour;

  const PaymentCheckoutPage({
    super.key,
    required this.barbershop,
    required this.service,
    required this.date,
    required this.hour,
  });

  @override
  State<PaymentCheckoutPage> createState() => _PaymentCheckoutPageState();
}

class _PaymentCheckoutPageState extends State<PaymentCheckoutPage>
    with WidgetsBindingObserver {
  final MercadoPagoService _paymentService = MercadoPagoService();
  final AppointmentService _appointmentService = AppointmentService();
  final AppFirestoreService _firestoreService = AppFirestoreService();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  Timer? _pollTimer;
  String? _paymentIntentId;
  String _status = 'ready';
  late String _selectedPaymentMethod;
  bool _loading = false;

  bool get _isFinished =>
      _status == 'paid' ||
      _status == 'cash_booked' ||
      _status == 'payment_failed' ||
      _status == 'manual_review';

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod =
        widget.barbershop.paymentConnected ? 'mercado_pago' : 'cash';
    WidgetsBinding.instance.addObserver(this);
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'barberkr' && uri.host == 'payments') {
        _refreshStatus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _paymentIntentId != null) {
      _refreshStatus();
    }
  }

  Future<void> _bookWithCash() async {
    if (_loading) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Entre na sua conta para concluir o agendamento.');
      return;
    }

    setState(() => _loading = true);
    try {
      final profile = await _firestoreService.getUserProfile(user.uid);
      final clientName = profile == null
          ? user.email ?? 'Cliente'
          : '${profile.nome} ${profile.sobrenome}'.trim();
      await _appointmentService.bookAppointment(
        barberId: widget.barbershop.ownerId,
        barbershopId: widget.barbershop.id,
        barbershopName: widget.barbershop.nome,
        clientId: user.uid,
        clientName: clientName,
        date: DateFormat('yyyy-MM-dd').format(widget.date),
        hour: widget.hour,
        serviceName: widget.service.nome,
        servicePrice: widget.service.preco,
        paymentMethod: 'cash',
        paymentStatus: 'pay_at_shop',
      );
      if (!mounted) return;
      setState(() => _status = 'cash_booked');
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startCheckout() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final checkout = await _paymentService.createCheckout(
        barbershopId: widget.barbershop.id,
        serviceName: widget.service.nome,
        date: DateFormat('yyyy-MM-dd').format(widget.date),
        hour: widget.hour,
      );
      if (!mounted) return;
      setState(() {
        _paymentIntentId = checkout.paymentIntentId;
        _status = 'checkout_created';
      });
      _startPolling();
      final opened = await launchUrl(
        checkout.checkoutUrl,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!opened) {
        throw Exception('Não foi possível abrir o checkout.');
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted &&
          (error.code == 'not-found' || error.code == 'unavailable')) {
        setState(() => _selectedPaymentMethod = 'cash');
      }
      _showError(_functionsErrorMessage(error));
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _functionsErrorMessage(FirebaseFunctionsException error) {
    if (error.code == 'not-found' || error.code == 'unavailable') {
      return 'Pix e Mercado Pago ainda não estão disponíveis. Selecione Dinheiro para pagar no local.';
    }
    return error.message ?? 'Não foi possível iniciar o pagamento.';
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _refreshStatus();
    });
  }

  Future<void> _refreshStatus() async {
    final intentId = _paymentIntentId;
    if (intentId == null) return;
    try {
      final result = await _paymentService.paymentStatus(intentId);
      if (!mounted) return;
      setState(() => _status = result.status);
      if (_isFinished) _pollTimer?.cancel();
    } catch (_) {
      // A próxima atualização automática tenta novamente.
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openAppointments() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const ClientHomePage(initialTab: 1),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final formattedDate = DateFormat("EEE, dd 'de' MMM", 'pt_BR')
        .format(widget.date)
        .replaceFirstMapped(RegExp(r'^.'), (value) => value[0]!.toUpperCase());

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar agendamento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _CheckoutHero(
              barbershopName: widget.barbershop.nome,
              logoData: widget.barbershop.logoData,
              imageUrl: widget.barbershop.imageUrl,
              serviceName: widget.service.nome,
              dateAndTime: '$formattedDate às ${widget.hour}:00',
              total: currency.format(widget.service.preco),
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _SummaryRow(
                      icon: Icons.storefront_rounded,
                      label: 'Barbearia',
                      value: widget.barbershop.nome,
                    ),
                    const Divider(height: 30),
                    _SummaryRow(
                      icon: Icons.content_cut_rounded,
                      label: 'Serviço',
                      value: widget.service.nome,
                    ),
                    const Divider(height: 30),
                    _SummaryRow(
                      icon: Icons.calendar_month_rounded,
                      label: 'Quando',
                      value: '$formattedDate às ${widget.hour}:00',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_status != 'paid' && _status != 'cash_booked') ...[
              Text(
                'Como deseja pagar?',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              Text(
                'Escolha a opção mais conveniente para você.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _PaymentMethodCard(
                selected: _selectedPaymentMethod == 'cash',
                icon: Icons.payments_rounded,
                title: 'Dinheiro',
                subtitle: 'Pague diretamente na barbearia',
                badge: 'NO LOCAL',
                onTap: _loading || _paymentIntentId != null
                    ? null
                    : () => setState(() {
                          _selectedPaymentMethod = 'cash';
                          _status = 'ready';
                        }),
              ),
              if (widget.barbershop.paymentConnected) ...[
                const SizedBox(height: 10),
                _PaymentMethodCard(
                  selected: _selectedPaymentMethod == 'mercado_pago',
                  icon: Icons.pix_rounded,
                  title: 'Pix ou Mercado Pago',
                  subtitle: 'Pix ou saldo da sua conta Mercado Pago',
                  badge: 'ONLINE',
                  onTap: _loading
                      ? null
                      : () => setState(
                            () => _selectedPaymentMethod = 'mercado_pago',
                          ),
                ),
              ],
              const SizedBox(height: 18),
            ],
            if (_selectedPaymentMethod == 'cash' && _status != 'cash_booked')
              _CashPaymentPanel(total: currency.format(widget.service.preco))
            else
              _PaymentStatusPanel(status: _status),
            const SizedBox(height: 18),
            if (_status == 'paid' || _status == 'cash_booked')
              FilledButton.icon(
                onPressed: _openAppointments,
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Ver meus agendamentos'),
              )
            else if (_status == 'manual_review')
              OutlinedButton.icon(
                onPressed: _refreshStatus,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Atualizar situação'),
              )
            else if (_selectedPaymentMethod == 'cash')
              FilledButton.icon(
                onPressed: _loading ? null : _bookWithCash,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.event_available_rounded),
                label: Text(
                  _loading ? 'Confirmando...' : 'Agendar e pagar no local',
                ),
              )
            else ...[
              FilledButton.icon(
                onPressed: _loading ? null : _startCheckout,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.pix_rounded),
                label: Text(
                  _paymentIntentId == null
                      ? 'Pagar com Pix ou Mercado Pago'
                      : 'Abrir Mercado Pago novamente',
                ),
              ),
              if (_paymentIntentId != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _refreshStatus,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Já paguei, atualizar'),
                ),
              ],
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 17, color: colors.outline),
                const SizedBox(width: 6),
                Text(
                  _selectedPaymentMethod == 'cash'
                      ? 'Pagamento combinado diretamente com a barbearia'
                      : 'Pagamento processado pelo Mercado Pago',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutHero extends StatelessWidget {
  final String barbershopName;
  final String? logoData;
  final String? imageUrl;
  final String serviceName;
  final String dateAndTime;
  final String total;

  const _CheckoutHero({
    required this.barbershopName,
    this.logoData,
    this.imageUrl,
    required this.serviceName,
    required this.dateAndTime,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33082E27),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          BarbershopImage(
            logoData: logoData,
            imageUrl: imageUrl,
            alignment: Alignment.center,
            fallbackAsset: 'assets/images/barber_luxury_bg.png',
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xF20A3029),
                  Color(0xA80A3029),
                  Color(0x52000000)
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0x99FFD18B),
                        ),
                      ),
                      child: const Icon(
                        Icons.event_available_rounded,
                        color: Color(0xFFFFD18B),
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESUMO DO AGENDAMENTO',
                          style: TextStyle(
                            color: Color(0xFFFFD18B),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                        Text(
                          'Tudo certo para confirmar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  barbershopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateAndTime,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'VALOR TOTAL',
                      style: TextStyle(
                        color: Color(0xFFFFD18B),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      total,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;

  const _PaymentMethodCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.72)
          : colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: colors.secondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colors.primary : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashPaymentPanel extends StatelessWidget {
  final String total;

  const _CashPaymentPanel({required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.storefront_rounded, color: colors.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pagamento no local',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Seu horário será confirmado agora. Pague $total em dinheiro na barbearia.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusPanel extends StatelessWidget {
  final String status;

  const _PaymentStatusPanel({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, title, message, color) = switch (status) {
      'cash_booked' => (
          Icons.event_available_rounded,
          'Horário confirmado',
          'Seu agendamento foi realizado. O pagamento será feito em dinheiro na barbearia.',
          colors.primary,
        ),
      'paid' => (
          Icons.check_circle_rounded,
          'Pagamento aprovado',
          'Seu horário está confirmado.',
          colors.primary,
        ),
      'payment_pending' => (
          Icons.schedule_rounded,
          'Aguardando confirmação',
          'A confirmação do Pix ou Mercado Pago pode levar alguns instantes.',
          colors.secondary,
        ),
      'payment_failed' => (
          Icons.error_outline_rounded,
          'Pagamento não aprovado',
          'Você pode tentar novamente com outra forma de pagamento.',
          colors.error,
        ),
      'manual_review' => (
          Icons.support_agent_rounded,
          'Pagamento em análise',
          'Recebemos o pagamento e estamos validando o horário.',
          colors.secondary,
        ),
      'checkout_created' => (
          Icons.open_in_new_rounded,
          'Checkout criado',
          'Conclua o pagamento na janela segura do Mercado Pago.',
          colors.primary,
        ),
      _ => (
          Icons.payments_outlined,
          'Pix ou Mercado Pago',
          'Escolha a forma de pagamento no ambiente do Mercado Pago.',
          colors.primary,
        ),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
