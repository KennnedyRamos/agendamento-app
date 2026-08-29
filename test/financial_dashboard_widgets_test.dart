import 'package:agendamento_app/app/models/financial_dashboard.dart';
import 'package:agendamento_app/app/widgets/financial_dashboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('painel de receita cabe em uma tela Android compacta',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: RevenueOverviewCard(
              selectedMonth: DateTime(2026, 8),
              netRevenue: 'R\$ 1.234,56',
              grossRevenue: 'R\$ 1.500,00',
              completedCount: 42,
              dailyRevenue: [
                FinancialDailyRevenue(
                  date: DateTime(2026, 8, 2),
                  day: 2,
                  appointmentCount: 5,
                  grossAmount: 120,
                  netAmount: 116.4,
                ),
              ],
              currency: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$'),
              isEstimated: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('R\$ 1.234,56'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
