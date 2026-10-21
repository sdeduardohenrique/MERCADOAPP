import 'package:flutter_test/flutter_test.dart';
import 'package:soma_ai/core/models/cart_item.dart';
import 'package:soma_ai/features/scanner/domain/label_scanner_service.dart';

CartItem _item(String name, double price, {String? ean}) {
  return CartItem(
    id: '${name}_$price',
    name: name,
    ean: ean,
    unitPrice: price,
    quantity: 1,
    unit: 'un',
    totalPrice: price,
    addedAt: DateTime(2026, 10, 20),
    source: ScanSource.camera,
  );
}

void main() {
  group('FrameThrottle', () {
    test('descarta frames dentro da janela mínima', () {
      final throttle = FrameThrottle(const Duration(milliseconds: 800));
      final start = DateTime(2026, 10, 20, 12);

      expect(throttle.tryAcquire(start), isTrue);
      expect(
        throttle.tryAcquire(start.add(const Duration(milliseconds: 500))),
        isFalse,
      );
      expect(
        throttle.tryAcquire(start.add(const Duration(milliseconds: 799))),
        isFalse,
      );
      expect(
        throttle.tryAcquire(start.add(const Duration(milliseconds: 800))),
        isTrue,
      );
    });
  });

  group('PriceConfirmationGate', () {
    test('confirma somente na segunda leitura idêntica', () {
      final gate = PriceConfirmationGate();
      final now = DateTime(2026, 10, 20, 12);
      final leite = _item('Leite Integral 1L', 4.49);

      expect(gate.register(leite, now: now), isFalse);
      expect(
        gate.register(leite, now: now.add(const Duration(milliseconds: 900))),
        isTrue,
      );
    });

    test('reinicia quando o preço muda', () {
      final gate = PriceConfirmationGate();
      final now = DateTime(2026, 10, 20, 12);

      expect(gate.register(_item('Leite', 4.49), now: now), isFalse);
      expect(
        gate.register(
          _item('Leite', 5.49),
          now: now.add(const Duration(milliseconds: 900)),
        ),
        isFalse,
      );
      expect(
        gate.register(
          _item('Leite', 5.49),
          now: now.add(const Duration(milliseconds: 1800)),
        ),
        isTrue,
      );
    });

    test('reinicia quando passa da janela de confirmação', () {
      final gate = PriceConfirmationGate();
      final now = DateTime(2026, 10, 20, 12);
      final leite = _item('Leite', 4.49);

      expect(gate.register(leite, now: now), isFalse);
      expect(
        gate.register(leite, now: now.add(const Duration(seconds: 6))),
        isFalse,
      );
    });

    test('normaliza acentos e maiúsculas na chave', () {
      final gate = PriceConfirmationGate();
      final now = DateTime(2026, 10, 20, 12);

      expect(gate.register(_item('Café Torrado', 12.90), now: now), isFalse);
      expect(
        gate.register(
          _item('CAFE TORRADO', 12.90),
          now: now.add(const Duration(milliseconds: 900)),
        ),
        isTrue,
      );
    });

    test('após confirmar, a próxima leitura recomeça do zero', () {
      final gate = PriceConfirmationGate();
      final now = DateTime(2026, 10, 20, 12);
      final leite = _item('Leite', 4.49);

      expect(gate.register(leite, now: now), isFalse);
      expect(
        gate.register(leite, now: now.add(const Duration(milliseconds: 900))),
        isTrue,
      );
      expect(
        gate.register(leite, now: now.add(const Duration(milliseconds: 1800))),
        isFalse,
      );
    });

    test('EAN diferente não confirma o mesmo nome/preço', () {
      final gate = PriceConfirmationGate();
      final now = DateTime(2026, 10, 20, 12);

      expect(
        gate.register(_item('Leite', 4.49, ean: '7891000000001'), now: now),
        isFalse,
      );
      expect(
        gate.register(
          _item('Leite', 4.49, ean: '7891000000002'),
          now: now.add(const Duration(milliseconds: 900)),
        ),
        isFalse,
      );
    });
  });
}
