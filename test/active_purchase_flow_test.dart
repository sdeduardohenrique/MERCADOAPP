import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soma_ai/core/models/cart_item.dart';
import 'package:soma_ai/core/models/mercado.dart';
import 'package:soma_ai/core/providers/location_provider.dart';
import 'package:soma_ai/core/services/location_service.dart';
import 'package:soma_ai/core/utils/formatters.dart';
import 'package:soma_ai/features/cart/presentation/active_purchase_screen.dart';
import 'package:soma_ai/features/cart/presentation/providers/cart_provider.dart';
import 'package:soma_ai/features/cart/presentation/purchase_success_screen.dart';
import 'package:soma_ai/features/community/domain/market_service.dart';
import 'package:soma_ai/features/community/presentation/providers/market_provider.dart';
import 'package:soma_ai/features/home/presentation/providers/purchase_history_provider.dart';
import 'package:soma_ai/features/shell/presentation/app_shell.dart';

Mercado _market() {
  return const Mercado(
    id: 'mercado-1',
    nome: 'Mercado do Bairro',
    latitude: -23.5505,
    longitude: -46.6333,
    distanciaMetros: 42,
  );
}

CartItem _item() {
  return CartItem(
    id: 'leite',
    name: 'Leite Integral 1L',
    ean: '7891000000001',
    unitPrice: 4.49,
    quantity: 2,
    unit: 'un',
    totalPrice: 8.98,
    addedAt: DateTime(2026, 10, 21),
    source: ScanSource.camera,
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: AppShell()),
  );
}

MarketService _withoutLocation() {
  return MarketService(
    nearbyFetcher: ({
      required double latitude,
      required double longitude,
      required double radiusMeters,
      int limit = 20,
    }) async =>
        const [],
    nameSearcher: (
      String query, {
      double? latitude,
      double? longitude,
      double radiusMeters = 5000,
    }) async =>
        const [],
    creator: ({
      required String name,
      double? latitude,
      double? longitude,
      String? city,
      String? neighborhood,
    }) async =>
        MarketCreationResult(
      Mercado(
        id: 'local',
        nome: name,
        latitude: latitude,
        longitude: longitude,
        cidade: city,
        bairro: neighborhood,
        isRemoto: false,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Iniciar nova compra abre o carrinho, não a câmera', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addItem(_item());
    container.read(selectedMarketProvider.notifier).select(_market());

    await tester.pumpWidget(_app(container));
    await tester.pump();

    await tester.tap(find.text('Iniciar nova compra'));
    await tester.pumpAndSettle();

    expect(find.byType(ActivePurchaseScreen), findsOneWidget);
    expect(find.text('Leite Integral 1L'), findsOneWidget);
    expect(find.text('Ler Etiquetas (Câmera)'), findsOneWidget);
    expect(find.text('Preparando a câmera...'), findsNothing);
  });

  testWidgets('Dashboard mostra compra em andamento e retoma o carrinho', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addItem(_item());

    await tester.pumpWidget(_app(container));
    await tester.pump();

    expect(find.text('Você tem uma compra em andamento'), findsOneWidget);
    expect(find.textContaining('R\$\u00A08,98'), findsWidgets);

    await tester.tap(find.text('Retomar'));
    await tester.pumpAndSettle();

    expect(find.byType(ActivePurchaseScreen), findsOneWidget);
    expect(find.text('Leite Integral 1L'), findsOneWidget);
  });

  testWidgets('modo manual adiciona item e recalcula o total', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(selectedMarketProvider.notifier).select(_market());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ActivePurchaseScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Seu carrinho está vazio'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Ferramentas de Compra'), findsOneWidget);
    await tester.tap(find.text('Entrada Manual'));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar item manualmente'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Leite Integral 1L');
    await tester.enterText(fields.at(1), '4,49');
    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pumpAndSettle();

    expect(find.text('Leite Integral 1L'), findsOneWidget);
    expect(find.text(Formatters.currency(4.49)), findsWidgets);
    expect(find.text('Seu carrinho está vazio'), findsNothing);
  });

  testWidgets('finalizar sem mercado salva apenas no histórico pessoal', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        marketServiceProvider.overrideWithValue(_withoutLocation()),
        // GPS negado de forma determinística (sem tocar no plugin real).
        locationProvider.overrideWith(
          (ref) => LocationNotifier(
            resolver: () async => const LocationAccessResult.failure(
              LocationAccessStatus.permissionDenied,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addItem(_item());

    final history = container.read(purchaseHistoryProvider.notifier);
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && !history.isLoaded; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    await tester.pumpWidget(_app(container));
    await tester.pump();

    await tester.tap(find.text('Iniciar nova compra'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finalizar Compra'));
    await tester.pumpAndSettle();

    final skip = find.text('Continuar sem selecionar mercado');
    await tester.ensureVisible(skip);
    await tester.tap(skip);
    await tester.pumpAndSettle();

    expect(find.text('Compra sem mercado'), findsOneWidget);
    expect(find.text('Somente histórico pessoal'), findsOneWidget);

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.byType(ActivePurchaseScreen), findsNothing);
    expect(container.read(cartProvider), isEmpty);
    expect(container.read(selectedMarketProvider), isNull);

    final saved = container
        .read(purchaseHistoryProvider)
        .where((purchase) => purchase.storeName == 'Compra sem mercado')
        .toList();
    expect(saved, hasLength(1));
    expect(saved.single.marketId, isNull);
    expect(saved.single.items.single.name, 'Leite Integral 1L');
  });

  testWidgets('finalizar compra limpa o carrinho e volta ao Dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addItem(_item());
    container.read(selectedMarketProvider.notifier).select(_market());

    await tester.pumpWidget(_app(container));
    await tester.pump();

    await tester.tap(find.text('Iniciar nova compra'));
    await tester.pumpAndSettle();

    expect(find.text('Leite Integral 1L'), findsOneWidget);

    await tester.tap(find.text('Finalizar Compra'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Deseja encerrar esta compra no valor de'),
      findsOneWidget,
    );

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.byType(ActivePurchaseScreen), findsNothing);
    expect(find.byType(PurchaseSuccessScreen), findsOneWidget);
    expect(find.text('Compra finalizada!'), findsOneWidget);
    expect(find.text('Compra finalizada com sucesso!'), findsOneWidget);
    expect(container.read(cartProvider), isEmpty);

    final back = find.text('Voltar ao início');
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(find.byType(PurchaseSuccessScreen), findsNothing);
    expect(find.text('Iniciar nova compra'), findsOneWidget);
  });
}
