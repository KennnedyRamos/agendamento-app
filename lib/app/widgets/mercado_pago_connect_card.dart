import 'dart:async';

import 'package:agendamento_app/app/services/mercado_pago_service.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MercadoPagoConnectCard extends StatefulWidget {
  const MercadoPagoConnectCard({super.key});

  @override
  State<MercadoPagoConnectCard> createState() => _MercadoPagoConnectCardState();
}

class _MercadoPagoConnectCardState extends State<MercadoPagoConnectCard>
    with WidgetsBindingObserver {
  final MercadoPagoService _service = MercadoPagoService();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _loading = true;
  bool _connecting = false;
  bool _connected = false;
  bool _integrationUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'barberkr' && uri.host == 'mercadopago') {
        _loadStatus();
      }
    });
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _connecting) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _service.connectionStatus();
      if (!mounted) return;
      setState(() {
        _connected = status.connected;
        _loading = false;
        _connecting = false;
        _integrationUnavailable = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _connecting = false;
        _integrationUnavailable =
            error.code == 'not-found' || error.code == 'unavailable';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _connecting = false;
      });
    }
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      final authorizationUrl = await _service.createConnectionUrl();
      final opened = await launchUrl(
        authorizationUrl,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!opened) {
        throw Exception('Não foi possível abrir o Mercado Pago.');
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted &&
          (error.code == 'not-found' || error.code == 'unavailable')) {
        setState(() => _integrationUnavailable = true);
      }
      _showError(_functionsErrorMessage(error));
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && !_connected) {
        setState(() => _connecting = false);
      }
    }
  }

  String _functionsErrorMessage(FirebaseFunctionsException error) {
    if (error.code == 'not-found' || error.code == 'unavailable') {
      return 'O pagamento online ainda não foi ativado no servidor. O agendamento em dinheiro continua funcionando normalmente.';
    }
    return error.message ?? 'Integração ainda não configurada.';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (_connected ? colors.primary : colors.secondary)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _connected
                    ? Icons.verified_rounded
                    : Icons.account_balance_wallet_rounded,
                color: _connected ? colors.primary : colors.secondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recebimentos Mercado Pago',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _connected
                        ? 'Conta conectada. Pix e cartão serão enviados diretamente para sua barbearia.'
                        : _integrationUnavailable
                            ? 'O pagamento online ainda está sendo configurado. Seus clientes podem agendar e pagar no local normalmente.'
                            : 'Conecte sua conta para aceitar Pix e cartão pelo aplicativo.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const LinearProgressIndicator()
                  else if (_connected)
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 18, color: colors.primary),
                        const SizedBox(width: 6),
                        const Text('Pronto para receber'),
                      ],
                    )
                  else if (_integrationUnavailable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Ativação do servidor pendente',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colors.onSecondaryContainer,
                                ),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _connecting ? null : _connect,
                      icon: _connecting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link_rounded),
                      label: const Text('Conectar conta'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
