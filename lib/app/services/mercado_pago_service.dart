import 'package:agendamento_app/app/models/financial_dashboard.dart';
import 'package:cloud_functions/cloud_functions.dart';

class MercadoPagoConnectionStatus {
  final bool connected;
  final DateTime? connectedAt;
  final double marketplaceFeePercent;
  final double appliedFeePercent;
  final bool isFeeTrialActive;
  final DateTime? feeTrialEndsAt;

  const MercadoPagoConnectionStatus({
    required this.connected,
    this.connectedAt,
    required this.marketplaceFeePercent,
    required this.appliedFeePercent,
    required this.isFeeTrialActive,
    this.feeTrialEndsAt,
  });
}

class MercadoPagoCheckout {
  final String paymentIntentId;
  final Uri checkoutUrl;
  final DateTime expiresAt;

  const MercadoPagoCheckout({
    required this.paymentIntentId,
    required this.checkoutUrl,
    required this.expiresAt,
  });
}

class MercadoPagoPaymentStatus {
  final String status;
  final String? appointmentId;
  final String? paymentStatus;
  final String? statusDetail;

  const MercadoPagoPaymentStatus({
    required this.status,
    this.appointmentId,
    this.paymentStatus,
    this.statusDetail,
  });
}

class MercadoPagoService {
  MercadoPagoService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<Uri> createConnectionUrl() async {
    final result = await _functions
        .httpsCallable('createMercadoPagoConnectUrl')
        .call<Map<String, dynamic>>();
    final url = result.data['authorizationUrl']?.toString() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('URL de autorização inválida.');
    }
    return uri;
  }

  Future<MercadoPagoConnectionStatus> connectionStatus() async {
    final result = await _functions
        .httpsCallable('getMercadoPagoConnectionStatus')
        .call<Map<String, dynamic>>();
    final connectedAt = DateTime.tryParse(
      result.data['connectedAt']?.toString() ?? '',
    );
    final feeTrialEndsAt = DateTime.tryParse(
      result.data['feeTrialEndsAt']?.toString() ?? '',
    );
    return MercadoPagoConnectionStatus(
      connected: result.data['connected'] == true,
      connectedAt: connectedAt,
      marketplaceFeePercent:
          (result.data['marketplaceFeePercent'] as num?)?.toDouble() ?? 3,
      appliedFeePercent:
          (result.data['appliedFeePercent'] as num?)?.toDouble() ?? 3,
      isFeeTrialActive: result.data['isFeeTrialActive'] == true,
      feeTrialEndsAt: feeTrialEndsAt,
    );
  }

  Future<MercadoPagoCheckout> createCheckout({
    required String barbershopId,
    required String serviceName,
    required String date,
    required String hour,
  }) async {
    final result = await _functions
        .httpsCallable('createMercadoPagoCheckout')
        .call<Map<String, dynamic>>({
      'barbershopId': barbershopId,
      'serviceName': serviceName,
      'date': date,
      'hour': hour,
    });
    final url = Uri.tryParse(result.data['checkoutUrl']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(
      result.data['expiresAt']?.toString() ?? '',
    );
    final paymentIntentId = result.data['paymentIntentId']?.toString() ?? '';
    if (url == null ||
        !url.hasScheme ||
        expiresAt == null ||
        paymentIntentId.isEmpty) {
      throw const FormatException('Checkout inválido recebido do servidor.');
    }
    return MercadoPagoCheckout(
      paymentIntentId: paymentIntentId,
      checkoutUrl: url,
      expiresAt: expiresAt,
    );
  }

  Future<MercadoPagoPaymentStatus> paymentStatus(
    String paymentIntentId,
  ) async {
    final result = await _functions
        .httpsCallable('getPaymentIntentStatus')
        .call<Map<String, dynamic>>({
      'paymentIntentId': paymentIntentId,
    });
    return MercadoPagoPaymentStatus(
      status: result.data['status']?.toString() ?? 'unknown',
      appointmentId: result.data['appointmentId']?.toString(),
      paymentStatus: result.data['paymentStatus']?.toString(),
      statusDetail: result.data['statusDetail']?.toString(),
    );
  }

  Future<FinancialDashboard> financialDashboard({int periodDays = 30}) async {
    final result = await _functions
        .httpsCallable('getBarberFinancialDashboard')
        .call<Map<String, dynamic>>({'periodDays': periodDays});
    return FinancialDashboard.fromMap(result.data);
  }
}
