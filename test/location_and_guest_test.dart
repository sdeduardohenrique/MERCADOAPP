import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soma_ai/core/providers/location_provider.dart';
import 'package:soma_ai/core/providers/session_provider.dart';
import 'package:soma_ai/core/services/location_service.dart';
import 'package:soma_ai/core/services/tomtom_service.dart';
import 'package:soma_ai/features/community/domain/market_service.dart';
import 'package:soma_ai/features/community/presentation/widgets/guest_community_lock.dart';

const _lat = -24.732273;
const _lng = -53.742256;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationNotifier', () {
    test('captura alta precisão e expõe o estado global', () async {
      var calls = 0;
      final notifier = LocationNotifier(
        resolver: () async {
          calls++;
          return LocationAccessResult.success(
            const LocationCoordinates(
              latitude: _lat,
              longitude: _lng,
              accuracyMeters: 8,
            ),
          );
        },
      );
      addTearDown(notifier.dispose);

      final result = await notifier.refresh();

      expect(result.hasCoordinates, isTrue);
      expect(notifier.state.coordinates?.latitude, _lat);
      expect(notifier.state.coordinates?.longitude, _lng);
      expect(notifier.state.accuracyMeters, 8);
      expect(notifier.state.updatedAt, isNotNull);
      expect(calls, 1);
    });

    test('reaproveita leitura recente e renova quando forçado', () async {
      var calls = 0;
      final notifier = LocationNotifier(
        resolver: () async {
          calls++;
          return LocationAccessResult.success(
            const LocationCoordinates(latitude: _lat, longitude: _lng),
          );
        },
      );
      addTearDown(notifier.dispose);

      await notifier.ensureCoordinates();
      await notifier.ensureCoordinates();
      expect(calls, 1, reason: 'leitura recente não deve abrir o GPS de novo');

      await notifier.ensureCoordinates(force: true);
      expect(calls, 2);
    });

    test('falha descarta a coordenada antiga (nunca usa local velho)',
        () async {
      var shouldFail = false;
      final notifier = LocationNotifier(
        resolver: () async => shouldFail
            ? const LocationAccessResult.failure(
                LocationAccessStatus.timeout,
              )
            : LocationAccessResult.success(
                const LocationCoordinates(latitude: _lat, longitude: _lng),
              ),
      );
      addTearDown(notifier.dispose);

      await notifier.refresh();
      expect(notifier.state.hasCoordinates, isTrue);

      shouldFail = true;
      await notifier.refresh();

      expect(notifier.state.hasCoordinates, isFalse);
      expect(notifier.state.status, LocationAccessStatus.timeout);
      expect(notifier.state.hasFailure, isTrue);
    });
  });

  group('GuestSessionNotifier', () {
    test('salva, restaura e limpa o apelido apenas no dispositivo', () async {
      SharedPreferences.setMockInitialValues({});

      final notifier = GuestSessionNotifier();
      addTearDown(notifier.dispose);

      await notifier.start('  Edu  ');
      expect(notifier.state?.name, 'Edu');

      final restored = GuestSessionNotifier();
      addTearDown(restored.dispose);
      await restored.restore();
      expect(restored.state?.name, 'Edu');

      await restored.clear();
      expect(restored.state, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(GuestSessionNotifier.storageKey), isNull);
    });
  });

  group('MarketService no modo visitante', () {
    test('não consulta a base interna nem grava na comunidade', () async {
      var localCalled = false;

      final service = MarketService(
        allowRemote: false,
        nearbyFetcher: ({
          required double latitude,
          required double longitude,
          required double radiusMeters,
          int limit = 20,
        }) async {
          localCalled = true;
          return const [];
        },
        tomTomService: TomTomService(
          apiKey: 'test-key',
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'id': 'tt-guest',
                    'type': 'poi',
                    'title': 'Mercado do Bairro',
                    'position': {
                      'type': 'Point',
                      'coordinates': [_lng, _lat],
                    },
                    'distanceInMeters': 120,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      final markets = await service.findNearby(
        latitude: _lat,
        longitude: _lng,
      );

      expect(localCalled, isFalse, reason: 'visitante não lê a comunidade');
      expect(markets, hasLength(1));
      expect(markets.single.externalId, 'tt-guest');

      // Upsert também é ignorado (não lança nem toca no Supabase).
      final persisted = await service.persistExternalMarket(markets.single);
      expect(persisted.market.externalId, 'tt-guest');
      expect(persisted.isRemote, isFalse);
    });

    test('busca por nome repassa o raio escolhido para a TomTom', () async {
      Map<String, dynamic>? sent;
      final service = MarketService(
        allowRemote: false,
        tomTomService: TomTomService(
          apiKey: 'test-key',
          httpClient: MockClient((request) async {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{"results":[]}', 200,
                headers: {'content-type': 'application/json'});
          }),
        ),
      );

      await service.searchByName(
        'Carrefour',
        latitude: _lat,
        longitude: _lng,
        radiusMeters: 1000,
      );

      final circle =
          (sent!['filters'] as Map<String, dynamic>)['geometry'] as Map;
      expect(circle['radiusInMeters'], 1000);
      expect(circle['center'], [_lng, _lat]);
    });
  });

  group('GuestCommunityLock', () {
    testWidgets('mostra o bloqueio e dispara a criação de conta',
        (tester) async {
      var tapped = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuestCommunityLock(onCreateAccount: () => tapped++),
          ),
        ),
      );

      expect(
        find.textContaining('você precisa criar uma conta gratuita'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await tester.tap(find.text('Criar minha conta'));
      await tester.pump();

      expect(tapped, 1);
    });
  });

  group('Estado de visitante na UI', () {
    test('isGuestProvider reflete a sessão', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isGuestProvider), isFalse);

      await container.read(guestSessionProvider.notifier).start('Edu');
      expect(container.read(isGuestProvider), isTrue);
      expect(container.read(guestSessionProvider)?.name, 'Edu');

      await container.read(guestSessionProvider.notifier).clear();
      expect(container.read(isGuestProvider), isFalse);
    });
  });

  group('Mercado local', () {
    test('visitante cria mercado apenas localmente', () async {
      final service = MarketService(allowRemote: false);

      final result = await service.createMarket(
        name: 'Mercado da Esquina',
        latitude: _lat,
        longitude: _lng,
        city: 'Toledo',
      );

      expect(result.market.isRemoto, isFalse);
      expect(result.market.nome, 'Mercado da Esquina');
    });
  });
}
