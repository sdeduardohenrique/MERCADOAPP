import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soma_ai/core/models/purchase.dart';
import 'package:soma_ai/core/utils/formatters.dart';
import 'package:soma_ai/features/cart/presentation/purchase_success_screen.dart';
import 'package:soma_ai/features/home/domain/purchase_share_service.dart';
import 'package:soma_ai/features/home/presentation/purchase_history_screen.dart';
import 'package:soma_ai/features/home/presentation/providers/purchase_history_provider.dart';

Purchase _purchase({
  String storeName = 'Mercado do Bairro',
  List<PurchaseItem>? items,
  double savings = 3.50,
}) {
  return Purchase(
    id: 'purchase-1',
    storeName: storeName,
    date: DateTime(2026, 10, 28),
    savings: savings,
    items: items ??
        const [
          PurchaseItem(
            name: 'Arroz 5kg',
            unitPrice: 25,
            quantity: 1,
          ),
          PurchaseItem(
            name: 'Óleo de Soja',
            unitPrice: 6,
            quantity: 2,
          ),
        ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PurchaseShareService', () {
    test('gera o recibo no formato do WhatsApp', () {
      final purchase = _purchase();
      final message = const PurchaseShareService().buildMessage(purchase);

      final expected = '🛒 *SomaAí - Resumo da Compra*\n'
          '📍 Mercado: Mercado do Bairro\n'
          '📅 Data: 28/10/2026\n'
          '\n'
          '🧾 *Itens Comprados:*\n'
          '1x Arroz 5kg - ${Formatters.currency(25)}\n'
          '2x Óleo de Soja - ${Formatters.currency(12)}\n'
          '\n'
          '💰 *Total Pago:* ${Formatters.currency(37)}\n'
          '🤑 *Economia Alcançada:* ${Formatters.currency(3.50)}\n'
          '\n'
          '✅ *Sem sustos no caixa!*';

      expect(message, expected);
    });

    test('usa "Não informado" quando não há mercado', () {
      const service = PurchaseShareService();
      final message = service.buildMessage(
        _purchase(storeName: 'Compra sem mercado'),
      );

      expect(message, contains('📍 Mercado: Não informado'));
      expect(
        service.marketLabel(_purchase(storeName: 'Compra sem mercado')),
        'Não informado',
      );
      expect(
        service.marketLabel(_purchase(storeName: '  ')),
        'Não informado',
      );
    });

    test('formata item vendido por peso com o peso entre parênteses', () {
      final purchase = _purchase(
        savings: 0,
        items: const [
          PurchaseItem(
            name: 'Produto Comparado',
            unit: 'kg',
            unitPrice: 16.25,
            quantity: 1,
            weightKg: 1.6,
          ),
        ],
      );

      final message = const PurchaseShareService().buildMessage(purchase);

      expect(
        message,
        contains(
          '1x Produto Comparado (1,6 kg) - ${Formatters.currency(26)}',
        ),
      );
      expect(
        message,
        contains(
          '🤑 *Economia Alcançada:* ${Formatters.currency(0)}',
        ),
      );
    });

    test('lista todos os itens da compra', () {
      final purchase = _purchase(
        items: const [
          PurchaseItem(name: 'Arroz', unitPrice: 10, quantity: 1),
          PurchaseItem(name: 'Feijão', unitPrice: 8, quantity: 2),
          PurchaseItem(name: 'Café', unitPrice: 15, quantity: 1),
        ],
      );

      final message = const PurchaseShareService().buildMessage(purchase);

      expect(message, contains('1x Arroz - ${Formatters.currency(10)}'));
      expect(message, contains('2x Feijão - ${Formatters.currency(16)}'));
      expect(message, contains('1x Café - ${Formatters.currency(15)}'));
    });
  });

  group('PurchaseSuccessScreen', () {
    testWidgets('mostra resumo e botão Compartilhar Resumo', (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final purchase = _purchase();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PurchaseSuccessScreen(purchase: purchase),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compra finalizada!'), findsOneWidget);
      expect(find.text('Compartilhar Resumo'), findsOneWidget);
      expect(find.text('Total pago'), findsOneWidget);
      expect(find.text(Formatters.currency(37)), findsOneWidget);
      expect(find.text('Mercado do Bairro'), findsOneWidget);
      expect(find.text('Ver detalhes da compra'), findsOneWidget);
    });
  });

  group('PurchaseDetailScreen', () {
    testWidgets('mostra o botão Compartilhar Resumo', (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final purchase = _purchase();
      SharedPreferences.setMockInitialValues({
        PurchaseHistoryNotifier.storageKey:
            jsonEncode([purchase.toJson()]),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final history = container.read(purchaseHistoryProvider.notifier);
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && !history.isLoaded; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PurchaseDetailScreen(purchaseId: purchase.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compartilhar Resumo'), findsOneWidget);
      expect(find.text('Mercado do Bairro'), findsOneWidget);
    });
  });
}
