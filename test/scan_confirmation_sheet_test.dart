import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soma_ai/core/models/cart_item.dart';
import 'package:soma_ai/core/theme/app_theme.dart';
import 'package:soma_ai/core/utils/formatters.dart';
import 'package:soma_ai/features/scanner/presentation/widgets/scan_confirmation_sheet.dart';

CartItem _leite() {
  return CartItem(
    id: 'leite',
    name: 'Leite Integral 1L',
    ean: '7891000000001',
    unitPrice: 4.49,
    quantity: 1,
    unit: 'un',
    totalPrice: 4.49,
    addedAt: DateTime(2026, 10, 20),
    source: ScanSource.camera,
  );
}

void main() {
  testWidgets('mostra o item lido e as duas ações', (tester) async {
    var confirmed = 0;
    var retried = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ScanConfirmationSheet(
            item: _leite(),
            onConfirm: () => confirmed++,
            onRetry: () => retried++,
          ),
        ),
      ),
    );

    expect(find.text('Leitura confirmada'), findsOneWidget);
    expect(find.text('Leite Integral 1L'), findsOneWidget);
    expect(find.text(Formatters.currency(4.49)), findsOneWidget);
    expect(find.text('1 item • un'), findsOneWidget);

    await tester.tap(find.text('Adicionar ao carrinho'));
    expect(confirmed, 1);

    await tester.tap(find.text('Escanear de novo'));
    expect(retried, 1);
  });
}
