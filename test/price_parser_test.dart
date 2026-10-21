import 'package:flutter_test/flutter_test.dart';
import 'package:soma_ai/core/utils/price_parser.dart';

void main() {
  group('PriceParser.parsePrice', () {
    test('aceita formatos brasileiros com duas casas', () {
      expect(PriceParser.parsePrice('12,90'), 12.90);
      expect(PriceParser.parsePrice('12.90'), 12.90);
      expect(PriceParser.parsePrice('1.234,56'), 1234.56);
      expect(PriceParser.parsePrice('1,234.56'), 1234.56);
    });

    test('rejeita números sem duas casas ou malformados', () {
      expect(PriceParser.parsePrice('12'), isNull);
      expect(PriceParser.parsePrice('12,9'), isNull);
      expect(PriceParser.parsePrice('12,900'), isNull);
      expect(PriceParser.parsePrice('abc'), isNull);
    });
  });

  group('PriceParser.parseFromOcr — preços válidos', () {
    test('aceita R\$ e mantém o nome do produto', () {
      final item = PriceParser.parseFromOcr(
        'Leite Integral 1L\nR\$ 4,49',
      );

      expect(item, isNotNull);
      expect(item!.unitPrice, 4.49);
      expect(item.name, contains('Leite'));
      expect(item.quantity, 1);
    });

    test('aceita preço isolado na linha', () {
      final item = PriceParser.parseFromOcr('Café Torrado\n12,90');
      expect(item?.unitPrice, 12.90);
    });

    test('separa nome e preço quando o OCR junta tudo na mesma linha', () {
      final item = PriceParser.parseFromOcr('Leite Integral R\$ 4,49');

      expect(item, isNotNull);
      expect(item!.unitPrice, 4.49);
      expect(item.name, 'Leite Integral');
    });

    test('aceita preço isolado com unidade', () {
      final item = PriceParser.parseFromOcr('Sabão em pó\n18,90 un');
      expect(item?.unitPrice, 18.90);
    });

    test('aceita palavra-chave antes do valor', () {
      final item = PriceParser.parseFromOcr('Feijão Carioca\nPOR 8,99');
      expect(item?.unitPrice, 8.99);
    });

    test('prefere o preço promocional depois de "por"', () {
      final item = PriceParser.parseFromOcr(
        'Arroz 5kg\nDe R\$ 29,90 por R\$ 24,90',
      );

      expect(item?.unitPrice, 24.90);
      expect(item?.quantity, 1, reason: 'peso da embalagem não é quantidade');
      expect(item?.unit, 'kg');
    });

    test('promoção 2x mantém a quantidade', () {
      final item = PriceParser.parseFromOcr('Leite\n2x 4,99');

      expect(item?.unitPrice, closeTo(2.495, 0.001));
      expect(item?.quantity, 2);
      expect(item?.unit, 'un');
    });

    test('ignora validade e lê o preço real', () {
      final item = PriceParser.parseFromOcr(
        'Leite Integral\nValidade 12/10/2026\nR\$ 4,49',
      );

      expect(item?.unitPrice, 4.49);
    });

    test('limite inferior aceito', () {
      final item = PriceParser.parseFromOcr('Bala\nR\$ 0,10');
      expect(item?.unitPrice, 0.10);
    });

    test('limite superior aceito', () {
      final item = PriceParser.parseFromOcr('Item\nR\$ 500,00');
      expect(item?.unitPrice, 500.00);
    });
  });

  group('Leitura parcial', () {
    test('extrai preço mesmo sem nome de produto', () {
      expect(PriceParser.parsePriceFromOcr('R\$ 4,49'), 4.49);
      expect(PriceParser.parsePriceFromOcr('7891000000001\n12,90'), 12.90);
    });

    test('não inventa preço quando só existe código de barras', () {
      expect(PriceParser.parsePriceFromOcr('7891000000001'), isNull);
    });

    test('extrai nome provável quando só falta o preço', () {
      final name = PriceParser.extractProductNameFromOcr(
        'Leite Integral 1L\n7891000000001',
      );
      expect(name, contains('Leite'));
    });
  });

  group('PriceParser.parseFromOcr — falsos positivos rejeitados', () {
    test('rejeita zero e centavos abaixo do mínimo', () {
      expect(PriceParser.parseFromOcr('Leite\nR\$ 0,00'), isNull);
      expect(PriceParser.parseFromOcr('Leite\nR\$ 0,09'), isNull);
    });

    test('rejeita valor acima do teto de mercado', () {
      expect(PriceParser.parseFromOcr('Leite\nR\$ 500,01'), isNull);
      expect(PriceParser.parseFromOcr('Leite\nR\$ 1.234,56'), isNull);
    });

    test('rejeita número inteiro sem casas decimais', () {
      expect(PriceParser.parseFromOcr('Leite\n12'), isNull);
      expect(PriceParser.parseFromOcr('Leite\nR\$ 12'), isNull);
    });

    test('rejeita data, código de barras, porcentagem e peso', () {
      expect(PriceParser.parseFromOcr('Leite\n12/10/2026'), isNull);
      expect(PriceParser.parseFromOcr('Leite\n7891234567895'), isNull);
      expect(PriceParser.parseFromOcr('Leite\n10%'), isNull);
      expect(PriceParser.parseFromOcr('Leite\n500 g'), isNull);
    });

    test('rejeita número grudado em texto sem R\$ ou palavra-chave', () {
      expect(PriceParser.parseFromOcr('Leite Integral 12,90'), isNull);
    });

    test('rejeita valor negativo', () {
      expect(PriceParser.parseFromOcr('Leite\nR\$ -5,00'), isNull);
    });
  });
}
