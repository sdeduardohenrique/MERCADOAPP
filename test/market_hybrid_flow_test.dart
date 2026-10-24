import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:soma_ai/core/models/mercado.dart';
import 'package:soma_ai/core/services/location_service.dart';
import 'package:soma_ai/core/services/tomtom_service.dart';
import 'package:soma_ai/features/community/domain/market_service.dart';

const _latitude = -23.5505;
const _longitude = -46.6333;

Map<String, dynamic> _discoverPayload({
  List<Map<String, dynamic>> results = const [],
}) {
  return {'results': results};
}

Map<String, dynamic> _poi({
  String id = 'tt-1',
  String title = 'Supermercado Extra',
  double lat = _latitude,
  double lng = _longitude,
  int distance = 120,
}) {
  return {
    'id': id,
    'type': 'poi',
    'title': title,
    'position': {
      'type': 'Point',
      'coordinates': [lng, lat],
    },
    'distanceInMeters': distance,
    'poiTypes': [
      {'id': 'supermarket', 'name': 'Supermarket'},
    ],
    'address': {
      'street': 'Av. Paulista',
      'houseNumber': '100',
      'municipality': 'São Paulo',
      'municipalitySubdivision': 'Bela Vista',
    },
  };
}

TomTomService _tomTom({
  Map<String, dynamic>? payload,
  int statusCode = 200,
  http.Client? client,
}) {
  final httpClient = client ??
      MockClient((request) async {
        expect(request.url.path, '/maps/orbis/places/discover');
        expect(request.headers['TomTom-Api-Version'], '3');
        expect(request.headers['Attributes'], 'results');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final filters = body['filters'] as Map<String, dynamic>;
        final circle = filters['geometry'] as Map<String, dynamic>;
        expect(circle['type'], 'circle');
        expect(circle['center'], [_longitude, _latitude]);

        return http.Response(
          jsonEncode(payload ?? _discoverPayload(results: [_poi()])),
          statusCode,
          headers: {'content-type': 'application/json'},
        );
      });
  return TomTomService(apiKey: 'test-key', httpClient: httpClient);
}

MarketService _service({
  List<Mercado> local = const [],
  TomTomService? tomTom,
  bool failLocal = false,
}) {
  return MarketService(
    locationResolver: ({bool forceRefresh = true}) async =>
        const LocationAccessResult.success(
      LocationCoordinates(latitude: _latitude, longitude: _longitude),
    ),
    nearbyFetcher: ({
      required double latitude,
      required double longitude,
      required double radiusMeters,
      int limit = 20,
    }) async {
      if (failLocal) {
        throw const MarketServiceException('Base interna indisponível.');
      }
      return local;
    },
    tomTomService: tomTom,
  );
}

void main() {
  group('TomTomService', () {
    test('sem chave configurada não faz requisição e devolve lista vazia',
        () async {
      var called = false;
      final service = TomTomService(
        apiKey: '',
        httpClient: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      expect(service.isConfigured, isFalse);
      expect(
        await service.searchNearby(latitude: _latitude, longitude: _longitude),
        isEmpty,
      );
      expect(called, isFalse);
    });

    test('converte POIs do discover para o modelo Mercado', () async {
      final service = _tomTom();

      final places = await service.searchNearby(
        latitude: _latitude,
        longitude: _longitude,
      );

      expect(places, hasLength(1));
      final place = places.single;
      expect(place.id, 'tt-1');
      expect(place.cidade, 'São Paulo');
      expect(place.bairro, 'Bela Vista');
      expect(place.endereco, 'Av. Paulista, 100');

      final mercado = place.toMercado();
      expect(mercado.nome, 'Supermercado Extra');
      expect(mercado.externalId, 'tt-1');
      expect(mercado.isRemoto, isFalse);
      expect(mercado.latitude, _latitude);
      expect(mercado.longitude, _longitude);
    });

    test('erro HTTP vira TomTomServiceException com código', () async {
      final service = _tomTom(
        statusCode: 403,
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'detailedError': {'code': 'Forbidden', 'message': 'nope'},
              }),
              403,
            )),
      );

      await expectLater(
        service.searchNearby(latitude: _latitude, longitude: _longitude),
        throwsA(
          isA<TomTomServiceException>()
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('busca por nome filtra categorias de mercado e ordena por distância',
        () async {
      late Map<String, dynamic> sentBody;
      final service = TomTomService(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(_discoverPayload(results: [
              _poi(id: 'tt-far', title: 'Carrefour', distance: 302000),
              _poi(id: 'tt-near', title: 'Carrefour', distance: 800),
              _poi(id: 'tt-mid', title: 'Carrefour Hiper', distance: 4200),
            ])),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final places = await service.searchByName(
        'Carrefour',
        latitude: _latitude,
        longitude: _longitude,
      );

      final filters = sentBody['filters'] as Map<String, dynamic>;
      expect(filters['poiTypes'], TomTomService.marketPoiTypes);
      expect(places.map((p) => p.id), ['tt-near', 'tt-mid', 'tt-far']);
    });
  });

  group('MarketService híbrido', () {
    test('usa TomTom como fallback e mantém filiais com o mesmo nome',
        () async {
      final service = _service(
        tomTom: _tomTom(
          payload: _discoverPayload(results: [
            _poi(),
            _poi(id: 'tt-2', title: 'Carrefour', distance: 300),
            _poi(id: 'tt-3', title: 'Carrefour', distance: 450),
          ]),
        ),
      );

      final mercados = await service.findNearby(
        latitude: _latitude,
        longitude: _longitude,
      );

      expect(mercados.map((m) => m.nome), [
        'Supermercado Extra',
        'Carrefour',
        'Carrefour',
      ]);
      expect(mercados.map((m) => m.externalId), ['tt-1', 'tt-2', 'tt-3']);
    });

    test('não chama a TomTom quando a base interna já tem resultados',
        () async {
      var called = false;
      final tomTom = TomTomService(
        apiKey: 'test-key',
        httpClient: MockClient((_) async {
          called = true;
          return http.Response(
            jsonEncode(_discoverPayload(results: [_poi()])),
            200,
          );
        }),
      );
      final service = _service(
        local: const [
          Mercado(
            id: 'local-1',
            nome: 'Mercado do Bairro',
            latitude: _latitude,
            longitude: _longitude,
            distanciaMetros: 40,
          ),
        ],
        tomTom: tomTom,
      );

      final mercados = await service.findNearby(
        latitude: _latitude,
        longitude: _longitude,
      );

      expect(mercados.single.nome, 'Mercado do Bairro');
      expect(called, isFalse);
    });

    test('includeExternal=false consulta apenas a base interna', () async {
      var called = false;
      final tomTom = TomTomService(
        apiKey: 'test-key',
        httpClient: MockClient((_) async {
          called = true;
          return http.Response(
            jsonEncode(_discoverPayload(results: [_poi()])),
            200,
          );
        }),
      );
      final service = _service(local: const [], tomTom: tomTom);

      final mercados = await service.findNearby(
        latitude: _latitude,
        longitude: _longitude,
        radiusMeters: 100,
        includeExternal: false,
      );

      expect(mercados, isEmpty);
      expect(called, isFalse);
    });

    test('falha da TomTom não derruba o fluxo e devolve lista vazia',
        () async {
      final service = _service(
        tomTom: _tomTom(
          statusCode: 500,
          client: MockClient((_) async => http.Response('erro', 500)),
        ),
      );

      final mercados = await service.findNearby(
        latitude: _latitude,
        longitude: _longitude,
      );

      expect(mercados, isEmpty);
    });

    test('falha da base interna usa TomTom como fallback', () async {
      final service = _service(
        failLocal: true,
        tomTom: _tomTom(),
      );

      final mercados = await service.findNearby(
        latitude: _latitude,
        longitude: _longitude,
      );

      expect(mercados.single.nome, 'Supermercado Extra');
      expect(mercados.single.externalId, 'tt-1');
    });

    test('sem base interna e sem TomTom propaga erro amigável', () async {
      final service = _service(failLocal: true);

      await expectLater(
        service.findNearby(latitude: _latitude, longitude: _longitude),
        throwsA(
          isA<MarketServiceException>().having(
            (e) => e.message,
            'message',
            'Base interna indisponível.',
          ),
        ),
      );
    });
  });
}
