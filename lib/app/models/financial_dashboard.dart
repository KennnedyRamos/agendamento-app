class FinancialSummary {
  final double grossRevenue;
  final double netRevenue;
  final double onlineGross;
  final double onlineNet;
  final double marketplaceFees;
  final double mercadoPagoFees;
  final double cashReceived;
  final double cashScheduled;
  final double pendingOnline;
  final int paidOnlineCount;
  final int pendingOnlineCount;
  final int completedCashCount;
  final int scheduledCashCount;
  final bool hasEstimatedOnlineValues;

  const FinancialSummary({
    required this.grossRevenue,
    required this.netRevenue,
    required this.onlineGross,
    required this.onlineNet,
    required this.marketplaceFees,
    required this.mercadoPagoFees,
    required this.cashReceived,
    required this.cashScheduled,
    required this.pendingOnline,
    required this.paidOnlineCount,
    required this.pendingOnlineCount,
    required this.completedCashCount,
    required this.scheduledCashCount,
    required this.hasEstimatedOnlineValues,
  });

  factory FinancialSummary.fromMap(Map<String, dynamic> map) {
    double money(String key) => (map[key] as num?)?.toDouble() ?? 0;
    int count(String key) => (map[key] as num?)?.toInt() ?? 0;

    return FinancialSummary(
      grossRevenue: money('grossRevenue'),
      netRevenue: money('netRevenue'),
      onlineGross: money('onlineGross'),
      onlineNet: money('onlineNet'),
      marketplaceFees: money('marketplaceFees'),
      mercadoPagoFees: money('mercadoPagoFees'),
      cashReceived: money('cashReceived'),
      cashScheduled: money('cashScheduled'),
      pendingOnline: money('pendingOnline'),
      paidOnlineCount: count('paidOnlineCount'),
      pendingOnlineCount: count('pendingOnlineCount'),
      completedCashCount: count('completedCashCount'),
      scheduledCashCount: count('scheduledCashCount'),
      hasEstimatedOnlineValues: map['hasEstimatedOnlineValues'] == true,
    );
  }
}

class FinancialFeePolicy {
  final double configuredPercent;
  final double appliedPercent;
  final bool isTrialActive;
  final DateTime? trialEndsAt;

  const FinancialFeePolicy({
    required this.configuredPercent,
    required this.appliedPercent,
    required this.isTrialActive,
    this.trialEndsAt,
  });

  factory FinancialFeePolicy.fromMap(Map<String, dynamic> map) {
    return FinancialFeePolicy(
      configuredPercent: (map['configuredPercent'] as num?)?.toDouble() ?? 3,
      appliedPercent: (map['appliedPercent'] as num?)?.toDouble() ?? 3,
      isTrialActive: map['isTrialActive'] == true,
      trialEndsAt: DateTime.tryParse(map['trialEndsAt']?.toString() ?? ''),
    );
  }
}

class FinancialTransaction {
  final String id;
  final String type;
  final String status;
  final double amount;
  final double marketplaceFee;
  final double mercadoPagoFee;
  final double netAmount;
  final bool isNetEstimated;
  final String serviceName;
  final String clientName;
  final String methodLabel;
  final DateTime? occurredAt;

  const FinancialTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.marketplaceFee,
    required this.mercadoPagoFee,
    required this.netAmount,
    required this.isNetEstimated,
    required this.serviceName,
    required this.clientName,
    required this.methodLabel,
    this.occurredAt,
  });

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    double money(String key) => (map[key] as num?)?.toDouble() ?? 0;

    return FinancialTransaction(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'online',
      status: map['status']?.toString() ?? 'pending',
      amount: money('amount'),
      marketplaceFee: money('marketplaceFee'),
      mercadoPagoFee: money('mercadoPagoFee'),
      netAmount: money('netAmount'),
      isNetEstimated: map['isNetEstimated'] == true,
      serviceName: map['serviceName']?.toString() ?? 'Serviço',
      clientName: map['clientName']?.toString() ?? 'Cliente',
      methodLabel: map['methodLabel']?.toString() ?? 'Mercado Pago',
      occurredAt: DateTime.tryParse(map['occurredAt']?.toString() ?? ''),
    );
  }
}

class FinancialDashboard {
  final int periodDays;
  final bool paymentConnected;
  final FinancialSummary summary;
  final FinancialFeePolicy feePolicy;
  final List<FinancialTransaction> transactions;
  final DateTime? generatedAt;

  const FinancialDashboard({
    required this.periodDays,
    required this.paymentConnected,
    required this.summary,
    required this.feePolicy,
    required this.transactions,
    this.generatedAt,
  });

  factory FinancialDashboard.fromMap(Map<String, dynamic> map) {
    final rawTransactions = map['transactions'] as List<dynamic>? ?? const [];
    return FinancialDashboard(
      periodDays: (map['periodDays'] as num?)?.toInt() ?? 30,
      paymentConnected: map['paymentConnected'] == true,
      summary: FinancialSummary.fromMap(
        Map<String, dynamic>.from(map['summary'] as Map? ?? const {}),
      ),
      feePolicy: FinancialFeePolicy.fromMap(
        Map<String, dynamic>.from(map['feePolicy'] as Map? ?? const {}),
      ),
      transactions: rawTransactions
          .whereType<Map>()
          .map(
            (item) => FinancialTransaction.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
      generatedAt: DateTime.tryParse(map['generatedAt']?.toString() ?? ''),
    );
  }
}
