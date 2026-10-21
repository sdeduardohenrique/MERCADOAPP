import 'package:flutter_test/flutter_test.dart';
import 'package:soma_ai/core/models/purchase.dart';
import 'package:soma_ai/features/cart/domain/checkout_service.dart';

Purchase _purchase() {
  return Purchase(
    id: '00000000-0000-4000-8000-000000000001',
    storeName: 'Mercado',
    date: DateTime(2026, 10, 21),
    items: const [
      PurchaseItem(name: 'Leite', unitPrice: 4.49, quantity: 2),
    ],
  );
}

void main() {
  group('CheckoutService', () {
    test('sincroniza quando há sessão e o saver remoto funciona', () async {
      var saved = 0;
      final service = CheckoutService(
        syncGate: () => null,
        remoteSaver: (purchase) async {
          saved++;
        },
      );

      final result = await service.sync(_purchase());

      expect(result.isSynced, isTrue);
      expect(result.isPending, isFalse);
      expect(saved, 1);
    });

    test('não chama o Supabase em modo offline', () async {
      var saved = 0;
      final service = CheckoutService(
        syncGate: () => CheckoutSyncStatus.skippedOffline,
        remoteSaver: (purchase) async {
          saved++;
        },
      );

      final result = await service.sync(_purchase());

      expect(result.status, CheckoutSyncStatus.skippedOffline);
      expect(result.isPending, isTrue);
      expect(saved, 0);
    });

    test('não bloqueia a compra quando o saver remoto falha', () async {
      final service = CheckoutService(
        syncGate: () => null,
        remoteSaver: (purchase) async {
          throw StateError('sem rede');
        },
      );

      final result = await service.sync(_purchase());

      expect(result.status, CheckoutSyncStatus.failed);
      expect(result.error, isA<StateError>());
      expect(result.isPending, isTrue);
    });
  });
}
