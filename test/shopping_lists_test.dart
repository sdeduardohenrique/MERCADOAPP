import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soma_ai/core/models/cart_item.dart';
import 'package:soma_ai/core/models/mercado.dart';
import 'package:soma_ai/core/providers/location_provider.dart';
import 'package:soma_ai/core/providers/session_provider.dart';
import 'package:soma_ai/core/services/location_service.dart';
import 'package:soma_ai/features/cart/presentation/active_purchase_screen.dart';
import 'package:soma_ai/features/cart/presentation/providers/cart_provider.dart';
import 'package:soma_ai/features/community/domain/market_service.dart';
import 'package:soma_ai/features/community/presentation/providers/market_provider.dart';
import 'package:soma_ai/features/shopping_list/domain/shopping_list.dart';
import 'package:soma_ai/features/shopping_list/domain/shopping_list_matcher.dart';
import 'package:soma_ai/features/shopping_list/domain/shopping_sector.dart';
import 'package:soma_ai/features/shopping_list/presentation/providers/shopping_lists_provider.dart';
import 'package:soma_ai/features/shopping_list/presentation/shopping_list_detail_screen.dart';
import 'package:soma_ai/features/shopping_list/presentation/shopping_lists_screen.dart';

Future<ProviderContainer> _guestContainer({
  bool resetStorage = true,
  List<Override> overrides = const [],
}) async {
  if (resetStorage) SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await container.read(guestSessionProvider.notifier).start('Ana');
  await container.read(shoppingListsProvider.future);
  return container;
}

const _testMarket = Mercado(
  id: 'mercado-teste',
  nome: 'Mercado Teste',
  latitude: -23.5505,
  longitude: -46.6333,
  distanciaMetros: 30,
  cidade: 'São Paulo',
  bairro: 'Centro',
);

List<Override> _marketOverrides() {
  return [
    marketServiceProvider.overrideWithValue(
      MarketService(
        nearbyFetcher: ({
          required double latitude,
          required double longitude,
          required double radiusMeters,
          int limit = 20,
        }) async =>
            const [_testMarket],
      ),
    ),
    locationProvider.overrideWith(
      (ref) => LocationNotifier(
        resolver: () async => const LocationAccessResult.success(
          LocationCoordinates(latitude: -23.5505, longitude: -46.6333),
        ),
      ),
    ),
  ];
}

ShoppingListItem _item(
  String id,
  String name, {
  bool bought = false,
}) {
  final now = DateTime.now().toUtc();
  return ShoppingListItem(
    id: id,
    listId: 'list-1',
    name: name,
    sector: ShoppingSector.categorize(name),
    isBought: bought,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('setores e quantidades', () {
    test('categoriza automaticamente pelos setores do mercado', () {
      expect(ShoppingSector.categorize('Tomate'), ShoppingSector.hortifruti);
      expect(
          ShoppingSector.categorize('Patinho moído'), ShoppingSector.acougue);
      expect(ShoppingSector.categorize('Leite'), ShoppingSector.laticinios);
      expect(ShoppingSector.categorize('Detergente'), ShoppingSector.limpeza);
      expect(ShoppingSector.categorize('Arroz'), ShoppingSector.mercearia);
      expect(ShoppingSector.categorize('Pão de Forma'), ShoppingSector.padaria);
      expect(ShoppingSector.categorize('Café'), ShoppingSector.padaria);
      expect(ShoppingSector.categorize('Leite condensado'),
          ShoppingSector.mercearia);
      expect(ShoppingSector.categorize('Item sem categoria'),
          ShoppingSector.outros);
    });

    test('formata quantidade e unidade sem zeros sobrando', () {
      expect(formatShoppingQuantity(1, 'un'), '1 un');
      expect(formatShoppingQuantity(2, 'un'), '2 un');
      expect(formatShoppingQuantity(1.5, 'kg'), '1,5 kg');
      expect(formatShoppingQuantity(0.25, 'kg'), '0,25 kg');
      expect(formatShoppingQuantity(3, 'cx'), '3 cx');
    });
  });

  group('matcher da lista', () {
    test('pontua nomes iguais e contidos', () {
      expect(shoppingMatchScore('Leite', 'Leite'), 100);
      expect(
        shoppingMatchScore('Leite', 'Leite Integral Parmalat'),
        greaterThan(80),
      );
    });

    test('não confunde produtos diferentes', () {
      expect(shoppingMatchScore('Leite em Pó', 'Leite Integral'), 0);
      expect(shoppingMatchScore('Sabão em Pó', 'Sabão Líquido'), 0);
      expect(shoppingMatchScore('Leite Condensado', 'Leite Integral'), 0);
    });

    test('escolhe o melhor item pendente e ignora comprados', () {
      final items = [
        _item('1', 'Leite Condensado'),
        _item('2', 'Leite'),
        _item('3', 'Leite Integral', bought: true),
      ];
      final match = bestShoppingListItemMatch(
        'Leite Integral Parmalat',
        items,
      );
      expect(match?.id, '2');
    });
  });

  group('shopping_lists_provider', () {
    test('cria múltiplas listas com itens, setor, quantidade e preço',
        () async {
      final container = await _guestContainer();
      final notifier = container.read(shoppingListsProvider.notifier);

      final feira = await notifier.createList('Feira da Semana', icon: '🥬');
      final churrasco =
          await notifier.createList('Churrasco de Domingo', icon: '🥩');
      expect(feira, isNotNull);
      expect(churrasco, isNotNull);

      await notifier.addItem(
        feira!.id,
        name: 'Tomate',
        quantity: 2,
        unit: 'kg',
        estimatedPrice: 8.5,
      );
      await notifier.addItem(feira.id, name: 'Leite', estimatedPrice: 5.99);
      await notifier.addItem(
        churrasco!.id,
        name: 'Patinho moído',
        quantity: 1.5,
        unit: 'kg',
        estimatedPrice: 39.9,
      );

      final lists = container.read(shoppingListsProvider).value!;
      expect(lists, hasLength(2));

      final feiraAtual = lists.firstWhere((list) => list.id == feira.id);
      expect(feiraAtual.totalItems, 2);
      expect(feiraAtual.pendingItems, 2);
      expect(feiraAtual.items.first.sector, ShoppingSector.hortifruti);
      expect(feiraAtual.items.last.sector, ShoppingSector.laticinios);
      expect(feiraAtual.estimatedTotal, closeTo(2 * 8.5 + 5.99, 0.001));

      final churrascoAtual =
          lists.firstWhere((list) => list.id == churrasco.id);
      expect(churrascoAtual.items.single.sector, ShoppingSector.acougue);
      expect(churrascoAtual.items.single.estimatedTotal, closeTo(59.85, 0.001));
    });

    test('risca item, atualiza progresso e limpa comprados', () async {
      final container = await _guestContainer();
      final notifier = container.read(shoppingListsProvider.notifier);
      final list = await notifier.createList('Feira');
      await notifier.addItem(list!.id, name: 'Tomate');
      await notifier.addItem(list.id, name: 'Arroz');

      final first = container
          .read(shoppingListByIdProvider(list.id))!
          .items
          .firstWhere((item) => item.name == 'Tomate');
      await notifier.toggleItem(list.id, first.id);

      var current = container.read(shoppingListByIdProvider(list.id))!;
      expect(current.boughtItems, 1);
      expect(current.pendingItems, 1);
      expect(current.progress, 0.5);

      await notifier.clearBought(list.id);
      current = container.read(shoppingListByIdProvider(list.id))!;
      expect(current.totalItems, 1);
      expect(current.items.single.name, 'Arroz');
    });

    test('persiste listas localmente entre containers', () async {
      final first = await _guestContainer();
      final notifier = first.read(shoppingListsProvider.notifier);
      final list = await notifier.createList('Atacado do Mês', icon: '📦');
      await notifier.addItem(
        list!.id,
        name: 'Arroz',
        quantity: 3,
        unit: 'kg',
        estimatedPrice: 6.2,
      );

      final second = await _guestContainer(resetStorage: false);
      final lists = second.read(shoppingListsProvider).value!;
      expect(lists, hasLength(1));
      expect(lists.single.name, 'Atacado do Mês');
      expect(lists.single.items.single.name, 'Arroz');
      expect(lists.single.items.single.quantity, 3);
    });

    test('migra a lista antiga do visitante para Minha Lista', () async {
      SharedPreferences.setMockInitialValues({
        'somaai.pre_shopping_list.v1.guest': jsonEncode([
          {
            'id': 'old-1',
            'name': 'Leite',
            'isBought': true,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
          {
            'id': 'old-2',
            'name': 'Tomate',
            'isBought': false,
            'createdAt': '2026-01-02T00:00:00.000Z',
            'updatedAt': '2026-01-02T00:00:00.000Z',
          },
        ]),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(guestSessionProvider.notifier).start('Ana');
      final lists = await container.read(shoppingListsProvider.future);

      expect(lists, hasLength(1));
      expect(lists.single.name, 'Minha Lista');
      expect(lists.single.items.map((item) => item.name), ['Leite', 'Tomate']);
      expect(lists.single.items.first.sector, ShoppingSector.laticinios);
      expect(lists.single.items.last.sector, ShoppingSector.hortifruti);
      expect(lists.single.items.first.isBought, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('somaai.shopping_lists.v2.guest'), isNotNull);
    });

    test('remove lista e limpa a seleção ativa', () async {
      final container = await _guestContainer();
      final notifier = container.read(shoppingListsProvider.notifier);
      final list = await notifier.createList('Churrasco');
      container.read(activeShoppingListIdProvider.notifier).select(list!.id);

      await notifier.deleteList(list.id);
      expect(container.read(shoppingListsProvider).value, isEmpty);
      expect(container.read(activeShoppingListIdProvider), isNull);
    });

    test('marca automaticamente o item mais parecido na lista ativa', () async {
      final container = await _guestContainer();
      final notifier = container.read(shoppingListsProvider.notifier);
      final list = await notifier.createList('Feira');
      await notifier.addItem(list!.id, name: 'Leite');
      await notifier.addItem(list.id, name: 'Arroz');
      container.read(activeShoppingListIdProvider.notifier).select(list.id);

      final marked =
          await notifier.markBoughtMatching('Leite Integral Parmalat');
      expect(marked?.name, 'Leite');

      final current = container.read(shoppingListByIdProvider(list.id))!;
      expect(
        current.items.firstWhere((item) => item.name == 'Leite').isBought,
        isTrue,
      );
      expect(
        current.items.firstWhere((item) => item.name == 'Arroz').isBought,
        isFalse,
      );
    });

    test('carrinho adiciona item e risca a lista ativa', () async {
      final container = await _guestContainer();
      final notifier = container.read(shoppingListsProvider.notifier);
      final list = await notifier.createList('Feira');
      await notifier.addItem(list!.id, name: 'Leite');
      container.read(activeShoppingListIdProvider.notifier).select(list.id);

      container.read(cartProvider.notifier).addItem(
            CartItem(
              id: 'cart-1',
              name: 'Leite Integral',
              unitPrice: 5.99,
              quantity: 1,
              unit: 'un',
              totalPrice: 5.99,
              addedAt: DateTime.now(),
              source: ScanSource.manual,
            ),
          );

      await Future<void>.delayed(const Duration(milliseconds: 60));
      final current = container.read(shoppingListByIdProvider(list.id))!;
      expect(current.items.single.isBought, isTrue);
    });
  });

  group('ShoppingListsScreen', () {
    testWidgets('mostra vazio e cria uma lista pelo FAB', (tester) async {
      final container = await _guestContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ShoppingListsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Minhas Listas'), findsOneWidget);
      expect(find.text('Sua primeira lista começa aqui'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Nova lista'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Feira da Semana');
      await tester.tap(find.text('Criar lista'));
      await tester.pumpAndSettle();

      expect(find.byType(ShoppingListDetailScreen), findsOneWidget);
      expect(find.text('Feira da Semana'), findsOneWidget);
      expect(find.text('Sua lista está vazia'), findsOneWidget);
      expect(
        container.read(shoppingListsProvider).value!.single.name,
        'Feira da Semana',
      );
    });

    testWidgets('lista cards com nome, contador e estimativa', (tester) async {
      final container = await _guestContainer();
      final notifier = container.read(shoppingListsProvider.notifier);
      final feira = await notifier.createList('Feira da Semana', icon: '🥬');
      final churrasco =
          await notifier.createList('Churrasco de Domingo', icon: '🥩');
      await notifier.addItem(feira!.id, name: 'Tomate', estimatedPrice: 8);
      await notifier.addItem(
        churrasco!.id,
        name: 'Patinho moído',
        estimatedPrice: 39.9,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ShoppingListsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Feira da Semana'), findsOneWidget);
      expect(find.text('Churrasco de Domingo'), findsOneWidget);
      expect(find.text('0 de 1 itens'), findsNWidgets(2));
      expect(find.textContaining('R\$'), findsWidgets);
    });
  });

  group('ShoppingListDetailScreen', () {
    testWidgets('agrupa itens por setor e adiciona com quantidade e preço',
        (tester) async {
      final container = await _guestContainer();
      final notifier = container.read(shoppingListsProvider.notifier);
      final list = await notifier.createList('Feira da Semana', icon: '🥬');
      await notifier.addItem(list!.id, name: 'Tomate');
      await notifier.addItem(list.id, name: 'Leite');
      await notifier.addItem(list.id, name: 'Detergente');
      await notifier.addItem(list.id, name: 'Arroz');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ShoppingListDetailScreen(listId: list.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hortifrúti'), findsOneWidget);
      expect(find.text('Laticínios & Frios'), findsOneWidget);
      expect(find.text('Tomate'), findsOneWidget);
      expect(find.text('Leite'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Limpeza & Lavanderia'),
        220,
        scrollable: scrollable,
      );
      expect(find.text('Limpeza & Lavanderia'), findsOneWidget);
      expect(find.text('Detergente'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Mercearia & Mantimentos'),
        220,
        scrollable: scrollable,
      );
      expect(find.text('Mercearia & Mantimentos'), findsOneWidget);
      expect(find.text('Arroz'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Adicionar item'),
        -260,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Adicionar item'));
      await tester.pumpAndSettle();
      expect(find.text('Adicionar item'), findsWidgets);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Patinho moído',
      );
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), '2');
      await tester.enterText(find.byType(TextFormField).at(2), '29.90');
      await tester.ensureVisible(find.text('Adicionar à lista'));
      await tester.tap(find.text('Adicionar à lista'));
      await tester.pumpAndSettle();

      final current = container.read(shoppingListByIdProvider(list.id))!;
      final added =
          current.items.firstWhere((item) => item.name == 'Patinho moído');
      expect(added.sector, ShoppingSector.acougue);
      expect(added.quantity, 2);
      expect(added.unit, 'un');
      expect(added.estimatedPrice, closeTo(29.9, 0.001));
      await tester.scrollUntilVisible(
        find.text('Patinho moído'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Patinho moído'), findsOneWidget);
    });

    testWidgets('pede mercado e orçamento antes de iniciar a compra',
        (tester) async {
      final container = await _guestContainer(overrides: _marketOverrides());
      final notifier = container.read(shoppingListsProvider.notifier);
      final list = await notifier.createList('Feira da Semana', icon: '🥬');
      await notifier.addItem(list!.id, name: 'Leite');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ShoppingListDetailScreen(listId: list.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Iniciar Compra no Mercado'));
      await tester.pumpAndSettle();

      expect(find.text('Mercado Teste'), findsOneWidget);
      expect(find.byType(ActivePurchaseScreen), findsNothing);

      await tester.tap(find.text('Sim, é este mercado'));
      await tester.pumpAndSettle();

      expect(find.text('Orçamento da compra'), findsOneWidget);
      await tester.tap(find.text('Continuar sem orçamento'));
      await tester.pumpAndSettle();

      expect(find.byType(ActivePurchaseScreen), findsOneWidget);
      expect(find.text('Lista: Feira da Semana'), findsOneWidget);
      expect(find.text('0/1 itens no carrinho'), findsOneWidget);
      expect(container.read(selectedMarketProvider)?.id, _testMarket.id);

      container.read(cartProvider.notifier).addItem(
            CartItem(
              id: 'cart-1',
              name: 'Leite Integral',
              unitPrice: 5.99,
              quantity: 1,
              unit: 'un',
              totalPrice: 5.99,
              addedAt: DateTime.now(),
              source: ScanSource.manual,
            ),
          );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('1/1 itens no carrinho • tudo comprado 🎉'),
          findsOneWidget);
      final current = container.read(shoppingListByIdProvider(list.id))!;
      expect(current.items.single.isBought, isTrue);
    });
  });
}
