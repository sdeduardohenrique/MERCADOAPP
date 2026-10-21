import 'package:flutter_test/flutter_test.dart';

import 'package:soma_ai/core/models/community_offer.dart';

void main() {
  test('oferta com campos nulos não quebra a renderização', () {
    const data = <String, dynamic>{
      'id': 'oferta-1',
      'product_name': null,
      'store_name': null,
      'price': null,
      'unit': null,
      'captured_at': null,
      'old_price': null,
      'latitude': null,
      'longitude': null,
      'endereco': null,
      'bairro': null,
      'cidade': null,
      'contributor_name': null,
      'confirmation_count': null,
    };
    final offer = CommunityOffer.fromRpc(data);

    expect(offer.productName, 'Produto');
    expect(offer.marketName, 'Mercado');
    expect(offer.price, 0);
    expect(offer.unitLabel, 'un');
    expect(offer.contributorLabel, 'Vizinho do SomaAí');
    expect(offer.contributorInitials, 'SA');
    expect(offer.fullAddress, isEmpty);
    expect(offer.mapDestination, isNull);
    expect(offer.savings, 0);
    expect(offer.confirmationsLabel, 'Ainda sem confirmações');
  });

  test('endereço, desconto e destino do mapa são derivados com segurança', () {
    const data = <String, dynamic>{
      'id': 'oferta-2',
      'product_name': 'Café 500g',
      'store_name': 'Mercado Central',
      'store_chain': 'Rede Central',
      'price': '18,90',
      'old_price': 24.90,
      'unit': 'un',
      'captured_at': '2026-10-21T10:00:00Z',
      'distance_km': '1.25',
      'confirmation_count': 3,
      'endereco': 'Rua A, 10',
      'bairro': 'Centro',
      'cidade': 'São Paulo',
      'latitude': -23.55,
      'longitude': -46.63,
      'contributor_name': 'Maria Silva',
    };
    final offer = CommunityOffer.fromRpc(data);

    expect(offer.price, 18.90);
    expect(offer.oldPrice, 24.90);
    expect(offer.savings, closeTo(6.0, 0.001));
    expect(offer.savingsPercentage, closeTo(24.096, 0.01));
    expect(offer.distanceLabel, '1,3 km');
    expect(offer.fullAddress, 'Rua A, 10, Centro, São Paulo');
    expect(offer.mapDestination, '-23.550000,-46.630000');
    expect(offer.contributorInitials, 'MS');
    expect(offer.confirmationsLabel, '3 confirmações');
    expect(offer.marketLabel, 'Mercado Central • Rede Central');
  });
}
