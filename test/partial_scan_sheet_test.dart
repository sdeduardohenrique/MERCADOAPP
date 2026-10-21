import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soma_ai/core/models/cart_item.dart';
import 'package:soma_ai/core/models/partial_scan_data.dart';
import 'package:soma_ai/core/theme/app_theme.dart';
import 'package:soma_ai/features/scanner/presentation/widgets/partial_scan_sheet.dart';

Widget _app(PartialScanSheet sheet) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: sheet),
  );
}

void main() {
  testWidgets('preço parcial vem preenchido e só pede o nome', (tester) async {
    CartItem? added;

    await tester.pumpWidget(
      _app(
        PartialScanSheet(
          data: const PartialScanData(unitPrice: 4.49),
          onSubmit: (item) => added = item,
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Completar informações'), findsOneWidget);
    expect(find.textContaining('Encontramos o preço'), findsOneWidget);
    expect(find.textContaining('4,49'), findsWidgets);

    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller?.text,
      '4,49',
    );

    await tester.enterText(fields.at(0), 'Leite integral 1L');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pump();

    expect(added, isNotNull);
    expect(added!.name, 'Leite integral 1L');
    expect(added!.unitPrice, 4.49);
    expect(added!.ean, isNull);
    expect(added!.source, ScanSource.camera);
  });

  testWidgets('EAN parcial pede nome e preço antes de adicionar',
      (tester) async {
    CartItem? added;

    await tester.pumpWidget(
      _app(
        PartialScanSheet(
          data: const PartialScanData(ean: '7891000000001'),
          onSubmit: (item) => added = item,
          onRetry: () {},
        ),
      ),
    );

    expect(find.textContaining('EAN 7891000000001'), findsOneWidget);
    expect(find.textContaining('Informe o nome do produto e o preço'),
        findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Arroz 5kg');
    await tester.enterText(fields.at(1), '27,90');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pump();

    expect(added, isNotNull);
    expect(added!.name, 'Arroz 5kg');
    expect(added!.ean, '7891000000001');
    expect(added!.unitPrice, 27.90);
  });

  testWidgets('impede adicionar com preço inválido', (tester) async {
    CartItem? added;

    await tester.pumpWidget(
      _app(
        PartialScanSheet(
          data: const PartialScanData(ean: '7891000000001'),
          onSubmit: (item) => added = item,
          onRetry: () {},
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Arroz');
    await tester.enterText(fields.at(1), 'abc');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pump();

    expect(find.text('Preço inválido'), findsOneWidget);
    expect(added, isNull);
  });
}
