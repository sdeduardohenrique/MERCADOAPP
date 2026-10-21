import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soma_ai/core/models/purchase.dart';
import 'package:soma_ai/core/theme/app_theme.dart';
import 'package:soma_ai/core/utils/formatters.dart';
import 'package:soma_ai/features/home/domain/purchase_history_sync_service.dart';
import 'package:soma_ai/features/home/presentation/edit_purchase_screen.dart';
import 'package:soma_ai/features/home/presentation/providers/purchase_history_provider.dart';

const _id = '00000000-0000-4000-8000-000000000001';

Purchase _purchase() {
  return Purchase(
    id: _id,
    storeName: 'Extra',
    date: DateTime.now(),
    items: const [
      PurchaseItem(name: 'Arroz', unitPrice: 10, quantity: 1),
    ],
  );
}

void main() {
  testWidgets('edita item, recalcula total e salva no histórico', (
    tester,
  ) async {
    final purchase = _purchase();
    SharedPreferences.setMockInitialValues({
      PurchaseHistoryNotifier.storageKey: jsonEncode([purchase.toJson()]),
    });

    final container = ProviderContainer(
      overrides: [
        purchaseHistorySyncServiceProvider.overrideWithValue(
          PurchaseHistorySyncService(
            syncGate: () => null,
            remoteUpdater: (_) async {},
            remoteDeleter: (_) async {},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(purchaseHistoryProvider.notifier);
    for (var i = 0; i < 50 && !notifier.isLoaded; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditPurchaseScreen(purchase: purchase),
                      ),
                    );
                  },
                  child: const Text('Abrir edição'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir edição'));
    await tester.pumpAndSettle();

    expect(find.text('Editar compra'), findsOneWidget);
    expect(find.text(Formatters.currency(10)), findsWidgets);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '12,00');
    await tester.tap(find.text('Salvar item'));
    await tester.pumpAndSettle();

    expect(find.text(Formatters.currency(12)), findsWidgets);

    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(find.byType(EditPurchaseScreen), findsNothing);
    expect(container.read(monthlySpendingProvider), 12);
    expect(container.read(purchaseHistoryProvider).single.total, 12);
  });
}
