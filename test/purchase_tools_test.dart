import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soma_ai/core/utils/formatters.dart';
import 'package:soma_ai/features/cart/domain/purchase_tools.dart';
import 'package:soma_ai/features/cart/presentation/active_purchase_screen.dart';
import 'package:soma_ai/features/cart/presentation/providers/cart_provider.dart';
import 'package:soma_ai/features/cart/presentation/widgets/promotion_calculator_modal.dart';
import 'package:soma_ai/features/cart/presentation/widgets/unit_cost_comparator_modal.dart';

Widget _host(
  ProviderContainer container,
  Future<void> Function(BuildContext) open,
) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => open(context),
              child: const Text('Abrir ferramenta'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openTool(
  WidgetTester tester,
  ProviderContainer container,
  Future<void> Function(BuildContext) open,
) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_host(container, open));
  await tester.tap(find.text('Abrir ferramenta'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WholesalePromotion', () {
    test('atacado: 3 unidades a R\$ 4,50 contra R\$ 5,00', () {
      const promotion = WholesalePromotion(
        normalUnitPrice: 5.00,
        quantity: 3,
        promoUnitPrice: 4.50,
      );

      expect(promotion.isValid, isTrue);
      expect(promotion.total, closeTo(13.50, 0.001));
      expect(promotion.normalTotal, closeTo(15.00, 0.001));
      expect(promotion.savings, closeTo(1.50, 0.001));
      expect(promotion.savingsPercent, closeTo(10, 0.001));
      expect(promotion.effectiveUnitPrice, closeTo(4.50, 0.001));
    });

    test('quantidade mínima abaixo de 2 é inválida', () {
      const promotion = WholesalePromotion(
        normalUnitPrice: 5,
        quantity: 1,
        promoUnitPrice: 4.50,
      );

      expect(promotion.isValid, isFalse);
    });
  });

  group('BuyXPayYPromotion', () {
    test('leve 3, pague 2 com unidade a R\$ 6,00', () {
      const promotion = BuyXPayYPromotion(
        take: 3,
        pay: 2,
        unitPrice: 6.00,
      );

      expect(promotion.isValid, isTrue);
      expect(promotion.freeUnits, 1);
      expect(promotion.total, closeTo(12.00, 0.001));
      expect(promotion.effectiveUnitPrice, closeTo(4.00, 0.001));
      expect(promotion.savings, closeTo(6.00, 0.001));
      expect(promotion.savingsPercent, closeTo(33.333, 0.01));
    });

    test('pague igual ou maior que o leve é inválido', () {
      expect(
        const BuyXPayYPromotion(take: 2, pay: 2, unitPrice: 6).isValid,
        isFalse,
      );
      expect(
        const BuyXPayYPromotion(take: 2, pay: 3, unitPrice: 6).isValid,
        isFalse,
      );
    });
  });

  group('compareUnitCosts', () {
    test('800 g por R\$ 14,00 vs 1,6 kg por R\$ 26,00', () {
      const optionA = UnitCostOption(
        price: 14.00,
        amount: 800,
        unit: MeasureUnit.gram,
      );
      const optionB = UnitCostOption(
        price: 26.00,
        amount: 1.6,
        unit: MeasureUnit.kilogram,
      );

      final comparison = compareUnitCosts(optionA, optionB);

      expect(comparison.isValid, isTrue);
      expect(comparison.winner, same(optionB));
      expect(comparison.baseLabel, 'kg');
      expect(optionA.pricePerBase, closeTo(17.50, 0.001));
      expect(optionB.pricePerBase, closeTo(16.25, 0.001));
      expect(comparison.differencePerBase, closeTo(1.25, 0.001));
      expect(comparison.differencePercent, closeTo(7.142, 0.01));
    });

    test('volume converte ml para litro', () {
      const optionA = UnitCostOption(
        price: 5.00,
        amount: 500,
        unit: MeasureUnit.milliliter,
      );
      const optionB = UnitCostOption(
        price: 18.00,
        amount: 2,
        unit: MeasureUnit.liter,
      );

      final comparison = compareUnitCosts(optionA, optionB);

      expect(comparison.baseLabel, 'L');
      expect(optionA.pricePerBase, closeTo(10.00, 0.001));
      expect(optionB.pricePerBase, closeTo(9.00, 0.001));
      expect(comparison.winner, same(optionB));
    });

    test('massa e volume não são comparáveis', () {
      const optionA = UnitCostOption(
        price: 10,
        amount: 500,
        unit: MeasureUnit.gram,
      );
      const optionB = UnitCostOption(
        price: 10,
        amount: 1,
        unit: MeasureUnit.liter,
      );

      final comparison = compareUnitCosts(optionA, optionB);

      expect(comparison.isValid, isFalse);
      expect(comparison.winner, isNull);
      expect(comparison.invalidReason, contains('peso'));
    });

    test('empate técnico não escolhe vencedor', () {
      const optionA = UnitCostOption(
        price: 10,
        amount: 1,
        unit: MeasureUnit.kilogram,
      );
      const optionB = UnitCostOption(
        price: 20,
        amount: 2,
        unit: MeasureUnit.kilogram,
      );

      final comparison = compareUnitCosts(optionA, optionB);

      expect(comparison.isTie, isTrue);
      expect(comparison.winner, isNull);
    });
  });

  group('parseDecimalInput', () {
    test('aceita vírgula, ponto e texto com R\$', () {
      expect(parseDecimalInput('14,00'), 14);
      expect(parseDecimalInput('1.6'), 1.6);
      expect(parseDecimalInput('R\$ 4,50'), 4.5);
      expect(parseDecimalInput('800'), 800);
      expect(parseDecimalInput(''), isNull);
    });
  });

  group('PromotionCalculatorModal', () {
    testWidgets('atacado calcula total/economia e adiciona ao carrinho',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await _openTool(tester, container, showPromotionCalculatorModal);

      expect(find.text('Calculadora de Promoções'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('promo_normal_price')),
        '5,00',
      );
      await tester.enterText(find.byKey(const Key('promo_quantity')), '3');
      await tester.enterText(find.byKey(const Key('promo_price')), '4,50');
      await tester.pumpAndSettle();

      expect(find.text(Formatters.currency(13.50)), findsOneWidget);
      expect(find.textContaining('Cada unidade sai por'), findsOneWidget);
      expect(find.textContaining(Formatters.currency(1.50)), findsWidgets);

      await tester.tap(find.byKey(const Key('promo_add_button')));
      await tester.pumpAndSettle();

      final cart = container.read(cartProvider);
      expect(cart, hasLength(1));
      expect(cart.single.quantity, 3);
      expect(cart.single.unitPrice, closeTo(4.50, 0.001));
      expect(cart.single.totalPrice, closeTo(13.50, 0.001));
      expect(cart.single.name, contains('atacado'));
    });

    testWidgets('leve 3 pague 2 rateia o preço e adiciona 3 unidades',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await _openTool(tester, container, showPromotionCalculatorModal);

      await tester.tap(find.text('Leve X, Pague Y'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('promo_buy_unit_price')),
        '6,00',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('cada unidade sai por apenas'),
        findsOneWidget,
      );
      expect(find.textContaining('Você paga por 2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('promo_add_button')));
      await tester.pumpAndSettle();

      final cart = container.read(cartProvider);
      expect(cart, hasLength(1));
      expect(cart.single.quantity, 3);
      expect(cart.single.unitPrice, closeTo(4.00, 0.001));
      expect(cart.single.totalPrice, closeTo(12.00, 0.001));
      expect(cart.single.name, contains('leve 3 pague 2'));
    });
  });

  group('UnitCostComparatorModal', () {
    testWidgets('destaca a opção mais barata e adiciona o vencedor',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await _openTool(tester, container, showUnitCostComparatorModal);

      expect(find.text('Comparador de Custo'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('unit_cost_price_a')),
        '14,00',
      );
      await tester.enterText(
        find.byKey(const Key('unit_cost_amount_a')),
        '800',
      );
      await tester.enterText(
        find.byKey(const Key('unit_cost_price_b')),
        '26,00',
      );
      await tester.enterText(
        find.byKey(const Key('unit_cost_amount_b')),
        '1,6',
      );
      await tester.pumpAndSettle();

      expect(find.text('Mais Econômico!'), findsOneWidget);
      expect(
        find.textContaining('${Formatters.currency(17.50)} / kg'),
        findsOneWidget,
      );
      expect(
        find.textContaining('${Formatters.currency(16.25)} / kg'),
        findsOneWidget,
      );
      expect(
        find.textContaining('é mais barato que o da Opção A'),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('unit_cost_add_button')),
      );
      await tester.tap(find.byKey(const Key('unit_cost_add_button')));
      await tester.pumpAndSettle();

      final cart = container.read(cartProvider);
      expect(cart, hasLength(1));
      final item = cart.single;
      expect(item.name, 'Produto Comparado');
      expect(item.isByWeight, isTrue);
      expect(item.weightKg, closeTo(1.6, 0.001));
      expect(item.unitPrice, closeTo(16.25, 0.001));
      expect(item.totalPrice, closeTo(26.00, 0.001));
    });
  });

  group('ActivePurchaseScreen · hub de ferramentas', () {
    testWidgets('barra inferior enxuta e FAB abre as quatro ferramentas',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ActivePurchaseScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Ler Etiquetas (Câmera)'), findsOneWidget);
      expect(find.text('Finalizar Compra'), findsOneWidget);
      expect(find.text('Manual'), findsNothing);
      expect(find.text('Voz'), findsNothing);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Ferramentas de Compra'), findsOneWidget);
      expect(find.text('Entrada Manual'), findsOneWidget);
      expect(find.text('Entrada por Voz'), findsOneWidget);
      expect(find.text('Calculadora de Promoções'), findsOneWidget);
      expect(find.text('Comparador de Custo'), findsOneWidget);
    });
  });
}
