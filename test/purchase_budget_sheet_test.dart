import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soma_ai/features/cart/presentation/widgets/purchase_budget_sheet.dart';

Future<Completer<BudgetSetupResult?>> _openSheet(
  WidgetTester tester,
  double? initial,
) async {
  final completer = Completer<BudgetSetupResult?>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showPurchaseBudgetSheet(
                  context,
                  initialBudget: initial,
                );
                if (!completer.isCompleted) completer.complete(result);
              },
              child: const Text('Abrir orçamento'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir orçamento'));
  await tester.pumpAndSettle();
  return completer;
}

void main() {
  testWidgets('define um orçamento válido', (tester) async {
    final completer = await _openSheet(tester, null);

    await tester.enterText(
      find.byKey(const Key('purchase_budget_input')),
      '350',
    );
    await tester.tap(find.text('Definir orçamento'));
    await tester.pumpAndSettle();

    final result = await completer.future;
    expect(result, isNotNull);
    expect(result!.budget, 350.00);
  });

  testWidgets('continuar sem orçamento devolve resultado explícito',
      (tester) async {
    final completer = await _openSheet(tester, 200);

    await tester.tap(find.text('Continuar sem orçamento'));
    await tester.pumpAndSettle();

    final result = await completer.future;
    expect(result, isNotNull);
    expect(result!.budget, isNull);
  });

  testWidgets('remover orçamento limpa o teto', (tester) async {
    final completer = await _openSheet(tester, 200);

    await tester.tap(find.text('Remover orçamento'));
    await tester.pumpAndSettle();

    final result = await completer.future;
    expect(result, isNotNull);
    expect(result!.budget, isNull);
  });
}
