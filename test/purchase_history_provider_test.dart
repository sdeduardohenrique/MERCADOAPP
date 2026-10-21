import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soma_ai/core/models/purchase.dart';
import 'package:soma_ai/features/home/domain/purchase_history_sync_service.dart';
import 'package:soma_ai/features/home/presentation/providers/purchase_history_provider.dart';

const _id = '00000000-0000-4000-8000-000000000001';

Purchase _purchase({double price = 10}) {
  return Purchase(
    id: _id,
    storeName: 'Extra',
    date: DateTime.now(),
    items: [PurchaseItem(name: 'Arroz', unitPrice: price, quantity: 1)],
  );
}

Future<ProviderContainer> _container(Purchase purchase) async {
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

  final notifier = container.read(purchaseHistoryProvider.notifier);
  for (var i = 0; i < 50 && !notifier.isLoaded; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  return container;
}

void main() {
  test('editar compra recalcula o total do mês imediatamente', () async {
    final container = await _container(_purchase());
    addTearDown(container.dispose);

    expect(container.read(monthlySpendingProvider), 10);

    final updated = _purchase(price: 12).copyWith(
      items: const [
        PurchaseItem(name: 'Arroz', unitPrice: 12, quantity: 2),
      ],
    );

    final result = await container
        .read(purchaseHistoryProvider.notifier)
        .updatePurchase(updated);

    expect(result.isSynced, isTrue);
    expect(container.read(monthlySpendingProvider), 24);
    expect(container.read(purchaseHistoryProvider).single.total, 24);
  });

  test('excluir compra remove do histórico e do total do mês', () async {
    final container = await _container(_purchase());
    addTearDown(container.dispose);

    final result = await container
        .read(purchaseHistoryProvider.notifier)
        .removePurchase(_id);

    expect(result.isSynced, isTrue);
    expect(container.read(purchaseHistoryProvider), isEmpty);
    expect(container.read(monthlySpendingProvider), 0);
  });
}
