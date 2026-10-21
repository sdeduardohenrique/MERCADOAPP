import 'package:flutter_test/flutter_test.dart';
import 'package:soma_ai/core/models/purchase.dart';
import 'package:soma_ai/core/utils/formatters.dart';

void main() {
  group('Purchase', () {
    test('calcula total e quantidade de itens', () {
      final purchase = Purchase(
        id: '1',
        storeName: 'Extra',
        date: DateTime(2026, 10, 20),
        savings: 5,
        items: const [
          PurchaseItem(name: 'Arroz', unitPrice: 10.5, quantity: 2),
          PurchaseItem(name: 'Feijão', unitPrice: 7, quantity: 3),
        ],
      );

      expect(purchase.total, 42.0);
      expect(purchase.itemCount, 5);
      expect(purchase.uniqueItems, 2);
    });

    test('serializa e desserializa mantendo os valores', () {
      final original = Purchase(
        id: 'abc',
        storeName: 'Assaí',
        date: DateTime(2026, 10, 18, 14, 30),
        savings: 3.25,
        items: const [
          PurchaseItem(name: 'Leite', unitPrice: 4.49, quantity: 6),
        ],
      );

      final restored = Purchase.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.storeName, original.storeName);
      expect(restored.date, original.date);
      expect(restored.savings, original.savings);
      expect(restored.total, original.total);
    });

    test('fromJson tolera campos em falta', () {
      final restored = Purchase.fromJson(const {});
      expect(restored.storeName, 'Mercado');
      expect(restored.total, 0);
      expect(restored.items, isEmpty);
    });
  });

  group('Formatters', () {
    test('formata moeda em pt-BR', () {
      expect(Formatters.currency(1234.5), 'R\$\u00A01.234,50');
    });

    test('formata datas relativas', () {
      final now = DateTime.now();
      expect(Formatters.relativeDate(now), 'Hoje');
      expect(
        Formatters.relativeDate(now.subtract(const Duration(days: 1))),
        'Ontem',
      );
    });

    test('formata percentuais', () {
      expect(Formatters.percent(12), '12%');
    });
  });
}
