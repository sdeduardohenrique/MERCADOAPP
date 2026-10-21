import 'package:flutter_test/flutter_test.dart';

import 'package:soma_ai/core/models/purchase.dart';
import 'package:soma_ai/features/home/domain/purchase_history_sync_service.dart';

Purchase _purchase({String id = '00000000-0000-4000-8000-000000000001'}) {
  return Purchase(
    id: id,
    storeName: 'Mercado',
    date: DateTime(2026, 10, 21),
    items: const [
      PurchaseItem(name: 'Leite', unitPrice: 4.49, quantity: 2),
    ],
  );
}

void main() {
  group('PurchaseHistorySyncService', () {
    test('sincroniza edição quando há sessão', () async {
      Purchase? updated;
      final service = PurchaseHistorySyncService(
        syncGate: () => null,
        remoteUpdater: (purchase) async => updated = purchase,
        remoteDeleter: (_) async {},
      );

      final purchase = _purchase();
      final result = await service.update(purchase);

      expect(result.isSynced, isTrue);
      expect(result.isPending, isFalse);
      expect(updated?.id, purchase.id);
    });

    test('sincroniza exclusão quando há sessão', () async {
      String? deleted;
      final service = PurchaseHistorySyncService(
        syncGate: () => null,
        remoteUpdater: (_) async {},
        remoteDeleter: (id) async => deleted = id,
      );

      final result = await service.delete(_purchase().id);

      expect(result.isSynced, isTrue);
      expect(deleted, _purchase().id);
    });

    test('não chama o Supabase quando está offline', () async {
      var calls = 0;
      final service = PurchaseHistorySyncService(
        syncGate: () => PurchaseMutationStatus.skippedOffline,
        remoteUpdater: (_) async => calls++,
        remoteDeleter: (_) async => calls++,
      );

      final update = await service.update(_purchase());
      final delete = await service.delete(_purchase().id);

      expect(update.status, PurchaseMutationStatus.skippedOffline);
      expect(delete.status, PurchaseMutationStatus.skippedOffline);
      expect(update.isPending, isTrue);
      expect(calls, 0);
    });

    test('não tenta enviar compras de demonstração', () async {
      var calls = 0;
      final service = PurchaseHistorySyncService(
        syncGate: () => null,
        remoteUpdater: (_) async => calls++,
        remoteDeleter: (_) async => calls++,
      );

      final result = await service.update(_purchase(id: 'demo-1'));

      expect(result.status, PurchaseMutationStatus.skippedLocalOnly);
      expect(calls, 0);
    });

    test('falha de rede não lança e mantém a alteração local', () async {
      final service = PurchaseHistorySyncService(
        syncGate: () => null,
        remoteUpdater: (_) async => throw StateError('sem rede'),
        remoteDeleter: (_) async => throw StateError('sem rede'),
      );

      final update = await service.update(_purchase());
      final delete = await service.delete(_purchase().id);

      expect(update.status, PurchaseMutationStatus.failed);
      expect(update.error, isA<StateError>());
      expect(delete.status, PurchaseMutationStatus.failed);
      expect(delete.error, isA<StateError>());
    });
  });
}
