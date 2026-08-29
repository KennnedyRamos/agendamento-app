import 'package:agendamento_app/app/models/financial_dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converte o resumo financeiro retornado pelo backend', () {
    final dashboard = FinancialDashboard.fromMap({
      'periodDays': 30,
      'selectedYear': 2026,
      'selectedMonth': 8,
      'periodStart': '2026-08-01',
      'paymentConnected': true,
      'summary': {
        'grossRevenue': 150,
        'netRevenue': 145.5,
        'onlineGross': 100,
        'onlineNet': 95.5,
        'marketplaceFees': 3,
        'mercadoPagoFees': 1.5,
        'cashReceived': 50,
        'cashScheduled': 40,
        'pendingOnline': 70,
        'paidOnlineCount': 2,
        'pendingOnlineCount': 1,
        'completedCashCount': 1,
        'scheduledCashCount': 1,
        'hasEstimatedOnlineValues': false,
      },
      'feePolicy': {
        'configuredPercent': 3,
        'appliedPercent': 0,
        'isTrialActive': true,
        'trialEndsAt': '2026-09-26T12:00:00.000Z',
      },
      'dailyRevenue': [
        {
          'date': '2026-08-27',
          'day': 27,
          'appointmentCount': 2,
          'grossAmount': 100,
          'netAmount': 95.5,
        },
      ],
      'serviceBreakdown': [
        {
          'serviceName': 'Corte',
          'appointmentCount': 2,
          'grossAmount': 100,
          'netAmount': 95.5,
        },
      ],
      'transactions': [
        {
          'id': 'payment-1',
          'type': 'online',
          'status': 'paid',
          'amount': 100,
          'marketplaceFee': 3,
          'mercadoPagoFee': 1.5,
          'netAmount': 95.5,
          'isNetEstimated': false,
          'serviceName': 'Corte',
          'clientName': 'Cliente',
          'methodLabel': 'Pix',
          'occurredAt': '2026-08-27T12:00:00.000Z',
        },
      ],
      'dataLimited': false,
      'generatedAt': '2026-08-27T12:05:00.000Z',
    });

    expect(dashboard.paymentConnected, isTrue);
    expect(dashboard.summary.netRevenue, 145.5);
    expect(dashboard.selectedMonth, 8);
    expect(dashboard.periodStart, DateTime(2026, 8));
    expect(dashboard.feePolicy.isTrialActive, isTrue);
    expect(dashboard.dailyRevenue.single.day, 27);
    expect(dashboard.serviceBreakdown.single.appointmentCount, 2);
    expect(dashboard.transactions.single.methodLabel, 'Pix');
    expect(dashboard.transactions.single.occurredAt, isNotNull);
  });

  test('usa valores seguros quando campos opcionais nao existem', () {
    final dashboard = FinancialDashboard.fromMap(const {});

    expect(dashboard.periodDays, 30);
    expect(dashboard.paymentConnected, isFalse);
    expect(dashboard.summary.grossRevenue, 0);
    expect(dashboard.feePolicy.configuredPercent, 3);
    expect(dashboard.transactions, isEmpty);
    expect(dashboard.dailyRevenue, isEmpty);
    expect(dashboard.serviceBreakdown, isEmpty);
    expect(dashboard.dataLimited, isFalse);
  });
}
