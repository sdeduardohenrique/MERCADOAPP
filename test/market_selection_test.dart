import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soma_ai/core/models/mercado.dart';
import 'package:soma_ai/core/services/location_service.dart';
import 'package:soma_ai/core/theme/app_theme.dart';
import 'package:soma_ai/features/cart/presentation/active_purchase_screen.dart';
import 'package:soma_ai/features/community/domain/market_service.dart';
import 'package:soma_ai/features/community/presentation/providers/market_provider.dart';
import 'package:soma_ai/features/community/presentation/widgets/market_selection_sheet.dart';
import 'package:soma_ai/features/shell/presentation/app_shell.dart';

const _exactMarket = Mercado(
  id: 'mercado-exato',
  nome: 'Mercado Amigão',
  latitude: -23.5505,
  longitude: -46.6333,
  distanciaMetros: 38,
  cidade: 'São Paulo',
  bairro: 'Centro',
);

const _fallbackMarket = Mercado(
  id: 'mercado-fallback',
  nome: 'Mercearia do Joaquim',
  latitude: -23.5515,
  longitude: -46.6343,
  distanciaMetros: 1400,
  cidade: 'São Paulo',
  bairro: 'Bela Vista',
);

LocationAccessResult _located() => const LocationAccessResult.success(
      LocationCoordinates(latitude: -23.5505, longitude: -46.6333),
    );

MarketService _service({
  LocationAccessResult? location,
  List<Mercado> exact = const [],
  List<Mercado> nearby = const [],
  List<Mercado> search = const [],
  MarketCreationResult? created,
}) {
  return MarketService(
    locationResolver: ({bool forceRefresh = true}) async =>
        location ?? _located(),
    nearbyFetcher: ({
      required double latitude,
      required double longitude,
      required double radiusMeters,
      int limit = 20,
    }) async {
      return radiusMeters <= 100 ? exact : nearby;
    },
    nameSearcher: (
      String query, {
      double? latitude,
      double? longitude,
    }) async =>
        search,
    creator: ({
      required String name,
      double? latitude,
      double? longitude,
      String? city,
      String? neighborhood,
    }) async {
      return created ??
          MarketCreationResult(
            Mercado(
              id: 'novo-mercado',
              nome: name,
              latitude: latitude,
              longitude: longitude,
              cidade: city,
              bairro: neighborhood,
            ),
          );
    },
  );
}

Widget _sheetApp(
  ProviderContainer container,
  ValueChanged<MarketSelectionResult> onResult,
) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showMarketSelectionSheet(context);
                onResult(result);
              },
              child: const Text('Abrir mercado'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('mostra card de match perfeito e seleciona o mercado',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        marketServiceProvider.overrideWithValue(
          _service(exact: const [_exactMarket]),
        ),
      ],
    );
    addTearDown(container.dispose);
    MarketSelectionResult? result;

    await tester.pumpWidget(_sheetApp(container, (market) => result = market));
    await tester.tap(find.text('Abrir mercado'));
    await tester.pumpAndSettle();

    expect(find.text('IDENTIFICAMOS QUE VOCÊ ESTÁ NO'), findsOneWidget);
    expect(find.text('Mercado Amigão'), findsOneWidget);
    expect(find.text('Sim, é este mercado'), findsOneWidget);

    await tester.tap(find.text('Sim, é este mercado'));
    await tester.pumpAndSettle();

    expect(result?.market?.id, _exactMarket.id);
    expect(find.text('Onde você está comprando?'), findsNothing);
  });

  testWidgets('não estou aqui mostra a lista de mercados num raio maior',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        marketServiceProvider.overrideWithValue(
          _service(
            exact: const [_exactMarket],
            nearby: const [_exactMarket, _fallbackMarket],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    MarketSelectionResult? result;

    await tester.pumpWidget(_sheetApp(container, (market) => result = market));
    await tester.tap(find.text('Abrir mercado'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Não estou aqui'));
    await tester.pumpAndSettle();

    expect(find.text('Mercados próximos'), findsOneWidget);
    expect(find.text('Mercearia do Joaquim'), findsOneWidget);

    await tester.tap(find.text('Mercearia do Joaquim'));
    await tester.pumpAndSettle();

    expect(result?.market?.id, _fallbackMarket.id);
  });

  testWidgets('GPS negado não bloqueia: cadastro manual sem coordenadas',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        marketServiceProvider.overrideWithValue(
          _service(
            location: const LocationAccessResult.failure(
              LocationAccessStatus.permissionDenied,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    MarketSelectionResult? result;

    await tester.pumpWidget(_sheetApp(container, (market) => result = market));
    await tester.tap(find.text('Abrir mercado'));
    await tester.pumpAndSettle();

    expect(find.text('Sem permissão de localização'), findsOneWidget);

    await tester.tap(find.text('Meu mercado não está na lista'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Mercado da Esquina');
    await tester.enterText(fields.at(1), 'São Paulo');
    await tester.enterText(fields.at(2), 'Centro');
    await tester.ensureVisible(find.text('Salvar e começar compra'));
    await tester.tap(find.text('Salvar e começar compra'));
    await tester.pumpAndSettle();

    expect(result?.market?.nome, 'Mercado da Esquina');
    expect(result?.market?.temCoordenadas, isFalse);
  });

  testWidgets('continuar sem mercado limpa a seleção e retorna skipped', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        marketServiceProvider.overrideWithValue(
          _service(exact: const [_exactMarket]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedMarketProvider.notifier).select(_exactMarket);
    MarketSelectionResult? result;

    await tester.pumpWidget(_sheetApp(container, (value) => result = value));
    await tester.tap(find.text('Abrir mercado'));
    await tester.pumpAndSettle();

    final skip = find.text('Continuar sem selecionar mercado');
    await tester.ensureVisible(skip);
    await tester.tap(skip);
    await tester.pumpAndSettle();

    expect(result?.isSkipped, isTrue);
    expect(result?.market, isNull);
    expect(container.read(selectedMarketProvider), isNull);
  });

  testWidgets('Dashboard pede o mercado antes de abrir o carrinho',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        marketServiceProvider.overrideWithValue(
          _service(exact: const [_exactMarket]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Iniciar nova compra'));
    await tester.pumpAndSettle();

    expect(find.text('Mercado Amigão'), findsOneWidget);
    expect(find.byType(ActivePurchaseScreen), findsNothing);

    await tester.tap(find.text('Sim, é este mercado'));
    await tester.pumpAndSettle();

    // O orçamento é opcional mas é oferecido ao iniciar uma compra nova.
    expect(find.text('Orçamento da compra'), findsOneWidget);
    await tester.tap(find.text('Continuar sem orçamento'));
    await tester.pumpAndSettle();

    expect(find.byType(ActivePurchaseScreen), findsOneWidget);
    expect(container.read(selectedMarketProvider)?.id, _exactMarket.id);
    expect(find.text('Leite Integral 1L'), findsNothing);
  });
}
