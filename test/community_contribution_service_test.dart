import 'package:flutter_test/flutter_test.dart';

import 'package:soma_ai/core/models/cart_item.dart';
import 'package:soma_ai/core/models/mercado.dart';
import 'package:soma_ai/features/community/domain/community_contribution_service.dart';

CartItem _item() {
  return CartItem(
    id: 'item-1',
    name: 'Leite Integral 1L',
    ean: '7891000000001',
    unitPrice: 4.49,
    quantity: 2,
    unit: 'un',
    totalPrice: 8.98,
    addedAt: DateTime(2026, 10, 21),
    source: ScanSource.manual,
  );
}

const _remoteMarket = Mercado(
  id: 'mercado-remoto',
  nome: 'Mercado Amigão',
  latitude: -23.5505,
  longitude: -46.6333,
);

const _localMarket = Mercado(
  id: 'mercado-local',
  nome: 'Mercado Offline',
  isRemoto: false,
);

void main() {
  test('envia o item com o mercado remoto', () async {
    String? receivedMarket;
    CartItem? receivedItem;

    final service = CommunityContributionService(
      gate: () => true,
      submitter: ({
        required CartItem item,
        required String marketId,
      }) async {
        receivedItem = item;
        receivedMarket = marketId;
        return true;
      },
    );

    final sent = await service.contribute(
      item: _item(),
      market: _remoteMarket,
    );

    expect(sent, isTrue);
    expect(receivedMarket, _remoteMarket.id);
    expect(receivedItem?.ean, '7891000000001');
  });

  test('não envia mercado local nem sem sessão', () async {
    var calls = 0;
    final service = CommunityContributionService(
      gate: () => true,
      submitter: ({
        required CartItem item,
        required String marketId,
      }) async {
        calls++;
        return true;
      },
    );

    expect(
      await service.contribute(item: _item(), market: _localMarket),
      isFalse,
    );
    expect(calls, 0);

    final signedOut = CommunityContributionService(
      gate: () => false,
      submitter: ({
        required CartItem item,
        required String marketId,
      }) async {
        calls++;
        return true;
      },
    );

    expect(
      await signedOut.contribute(item: _item(), market: _remoteMarket),
      isFalse,
    );
    expect(calls, 0);
  });

  test('falha da rede não propaga exceção', () async {
    final service = CommunityContributionService(
      gate: () => true,
      submitter: ({
        required CartItem item,
        required String marketId,
      }) async {
        throw Exception('offline');
      },
    );

    final sent = await service.contribute(
      item: _item(),
      market: _remoteMarket,
    );

    expect(sent, isFalse);
  });
}
