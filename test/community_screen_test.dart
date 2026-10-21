import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soma_ai/core/models/community_offer.dart';
import 'package:soma_ai/core/theme/app_theme.dart';
import 'package:soma_ai/features/community/domain/community_service.dart';
import 'package:soma_ai/features/community/presentation/community_screen.dart';

final _offer = CommunityOffer(
  id: 'oferta-1',
  productName: 'Café 500g',
  brand: 'Torra Forte',
  marketId: 'mercado-1',
  marketName: 'Mercado Central',
  marketChain: 'Rede Central',
  price: 18.90,
  oldPrice: 24.90,
  unit: 'un',
  distanceKm: 1.25,
  capturedAt: DateTime.now().subtract(const Duration(minutes: 8)),
  confirmations: 3,
  address: 'Rua A, 10',
  neighborhood: 'Centro',
  city: 'São Paulo',
  latitude: -23.55,
  longitude: -46.63,
  contributorName: 'Maria Silva',
);

CommunityService _service() {
  return CommunityService(
    offersFetcher: ({
      double? latitude,
      double? longitude,
      required double radiusKm,
      String? city,
      String? query,
      int limit = 30,
    }) async =>
        [_offer],
  );
}

Future<void> _pumpCommunity(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      communityServiceProvider.overrideWithValue(_service()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: CommunityScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renderiza oferta real e abre detalhes com endereço e rota', (
    tester,
  ) async {
    await _pumpCommunity(tester);

    expect(find.text('Radar de ofertas'), findsOneWidget);
    expect(find.text('Café 500g'), findsOneWidget);
    expect(find.text('Mercado Central • Rede Central'), findsOneWidget);
    expect(find.text('1,3 km'), findsWidgets);

    await tester.tap(find.text('Café 500g'));
    await tester.pumpAndSettle();

    expect(find.text('Detalhes da oferta'), findsOneWidget);
    expect(find.text('Rua A, 10, Centro, São Paulo'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Waze'), findsOneWidget);
  });
}
