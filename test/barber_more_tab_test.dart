import 'package:agendamento_app/app/screens/barber_more_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('agrupa financeiro, historico e barbearia em Mais',
      (tester) async {
    var openedFinancial = false;
    var openedHistory = false;
    var openedBarbershop = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarberMoreTab(
            onOpenFinancial: () => openedFinancial = true,
            onOpenHistory: () => openedHistory = true,
            onOpenBarbershop: () => openedBarbershop = true,
            onLogout: () {},
          ),
        ),
      ),
    );

    expect(find.text('Financeiro'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Minha barbearia'), findsOneWidget);

    await tester.tap(find.text('Financeiro'));
    await tester.tap(find.text('Histórico'));
    await tester.tap(find.text('Minha barbearia'));

    expect(openedFinancial, isTrue);
    expect(openedHistory, isTrue);
    expect(openedBarbershop, isTrue);
  });
}
