import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soma_ai/core/models/cart_item.dart';
import 'package:soma_ai/core/models/mercado.dart';
import 'package:soma_ai/features/cart/presentation/active_purchase_screen.dart';
import 'package:soma_ai/features/cart/presentation/providers/cart_provider.dart';
import 'package:soma_ai/features/cart/presentation/providers/purchase_budget_provider.dart';
import 'package:soma_ai/features/community/presentation/providers/market_provider.dart';

const _market = Mercado(
  id: 'mercado-1',
  nome: 'Mercado do Bairro',
  latitude: -23.5505,
  longitude: -46.6333,
  distanciaMetros: 42,
);

CartItem _item({String? photoPath}) {
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
    photoPath: photoPath,
  );
}

Widget _screen(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: ActivePurchaseScreen()),
  );
}

void main() {
  group('CartItem por peso', () {
    test('calcula o total a partir do peso em kg', () {
      final item = CartItem(
        id: 'banana',
        name: 'Banana',
        unitPrice: 6.99,
        quantity: 1,
        unit: 'kg',
        kind: CartItemKind.weight,
        weightKg: 0.75,
        totalPrice: 0,
        addedAt: DateTime(2026, 10, 21),
        source: ScanSource.manual,
      );

      expect(item.isByWeight, isTrue);
      expect(item.effectiveQuantity, 0.75);
      expect(item.withCalculatedTotal().totalPrice, closeTo(5.2425, 0.001));
      expect(item.itemCount, 1);
    });
  });

  group('CartNotifier', () {
    test('updateItem substitui o item e recalcula o subtotal', () {
      final notifier = CartNotifier();
      notifier.addItem(_item());

      notifier.updateItem(
        notifier.state.single.copyWith(unitPrice: 5.00, quantity: 3),
      );

      final updated = notifier.state.single;
      expect(updated.unitPrice, 5.00);
      expect(updated.quantity, 3);
      expect(updated.totalPrice, 15.00);
    });

    test('stepper de item por peso soma e subtrai 100 g', () {
      final notifier = CartNotifier();
      notifier.addItem(
        CartItem(
          id: 'banana',
          name: 'Banana',
          unitPrice: 6.99,
          quantity: 1,
          unit: 'kg',
          kind: CartItemKind.weight,
          weightKg: 0.5,
          totalPrice: 0,
          addedAt: DateTime(2026, 10, 21),
          source: ScanSource.manual,
        ),
      );

      notifier.incrementQuantity('banana');
      expect(notifier.state.single.weightKg, closeTo(0.6, 0.001));

      notifier.decrementQuantity('banana');
      expect(notifier.state.single.weightKg, closeTo(0.5, 0.001));

      // Nunca zera o peso pelo stepper: o item só sai pelo botão de remover.
      notifier.decrementQuantity('banana');
      notifier.decrementQuantity('banana');
      notifier.decrementQuantity('banana');
      notifier.decrementQuantity('banana');
      notifier.decrementQuantity('banana');
      expect(notifier.state.single.weightKg, greaterThan(0));
    });

    test('merge por EAN soma pesos com o mesmo preço', () {
      final notifier = CartNotifier();
      CartItem weighted(double kg) => CartItem(
            id: 'id-$kg',
            name: 'Banana',
            ean: '123',
            unitPrice: 6.99,
            quantity: 1,
            unit: 'kg',
            kind: CartItemKind.weight,
            weightKg: kg,
            totalPrice: 0,
            addedAt: DateTime(2026, 10, 21),
            source: ScanSource.manual,
          );

      notifier.addItem(weighted(0.5));
      notifier.addItem(weighted(0.25));

      expect(notifier.state, hasLength(1));
      expect(notifier.state.single.weightKg, closeTo(0.75, 0.001));
      expect(notifier.state.single.totalPrice, closeTo(5.2425, 0.001));
    });
  });

  group('PurchaseBudgetNotifier', () {
    test('guarda, arredonda e limpa o teto', () {
      final notifier = PurchaseBudgetNotifier();

      notifier.setBudget(299.999);
      expect(notifier.state, 300.00);

      notifier.setBudget(0);
      expect(notifier.state, isNull);

      notifier.setBudget(150);
      notifier.clear();
      expect(notifier.state, isNull);
    });
  });

  group('ActivePurchaseScreen · edição', () {
    testWidgets('lápis edita o item e recalcula com peso', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).addItem(_item());
      container.read(selectedMarketProvider.notifier).select(_market);

      await tester.pumpWidget(_screen(container));
      await tester.pump();

      await tester.tap(find.byTooltip('Editar item'));
      await tester.pumpAndSettle();

      expect(find.text('Editar item'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('cart_item_name')),
        'Banana prata',
      );
      await tester.enterText(
        find.byKey(const Key('cart_item_price')),
        '6,99',
      );
      await tester.tap(find.text('Por peso (kg)'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('cart_item_weight')),
        '0,500',
      );
      await tester.ensureVisible(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      final updated = container.read(cartProvider).single;
      expect(updated.name, 'Banana prata');
      expect(updated.isByWeight, isTrue);
      expect(updated.weightKg, closeTo(0.5, 0.001));
      expect(updated.totalPrice, closeTo(3.495, 0.001));
      expect(find.text('Banana prata'), findsOneWidget);
    });

    testWidgets('stepper inline soma unidades sem abrir o modal',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).addItem(_item());

      await tester.pumpWidget(_screen(container));
      await tester.pump();

      final plus = find.byTooltip('Aumentar quantidade');
      await tester.ensureVisible(plus);
      await tester.pumpAndSettle();
      await tester.tap(plus);
      await tester.pump();

      expect(container.read(cartProvider).single.quantity, 3);
    });
  });

  group('ActivePurchaseScreen · orçamento e foto', () {
    testWidgets('mostra aviso de orçamento excedido e o teto', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).addItem(_item());
      container.read(purchaseBudgetProvider.notifier).setBudget(5);

      await tester.pumpWidget(_screen(container));
      await tester.pump();

      expect(find.textContaining('Orçamento'), findsWidgets);
      expect(find.textContaining('Excedeu'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('abre a foto da etiqueta em tela cheia', (tester) async {
      final directory = Directory.systemTemp.createTempSync('somaai_photo');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/etiqueta.png')
        ..writeAsBytesSync(_onePixelPng);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).addItem(
            _item(photoPath: file.path),
          );

      await tester.pumpWidget(_screen(container));
      await tester.pump();

      final photoButton = find.byTooltip('Ver foto da etiqueta');
      await tester.ensureVisible(photoButton);
      await tester.pumpAndSettle();
      await tester.tap(photoButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Foto da etiqueta'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('miniatura sem foto mostra o ícone de origem', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).addItem(_item());

      await tester.pumpWidget(_screen(container));
      await tester.pump();

      final thumbnail = find.byKey(const ValueKey('cart_thumbnail_leite'));
      expect(thumbnail, findsOneWidget);
      expect(
        find.descendant(
          of: thumbnail,
          matching: find.byIcon(Icons.photo_camera_rounded),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Ver foto da etiqueta'), findsNothing);
    });

    testWidgets('card de orçamento troca de zona conforme o consumo',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).addItem(_item());

      await tester.pumpWidget(_screen(container));

      container.read(purchaseBudgetProvider.notifier).setBudget(100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Zona segura'), findsOneWidget);
      expect(find.textContaining('Ainda pode gastar'), findsOneWidget);

      container.read(purchaseBudgetProvider.notifier).setBudget(10);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Atenção: perto do teto'), findsOneWidget);

      container.read(purchaseBudgetProvider.notifier).setBudget(5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Orçamento estourado'), findsOneWidget);
      expect(find.textContaining('Excedeu'), findsOneWidget);
    });
  });
}

const _onePixelPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
];
