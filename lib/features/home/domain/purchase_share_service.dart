import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import '../../../core/models/purchase.dart';
import '../../../core/utils/formatters.dart';

/// Gera e compartilha o recibo digital da compra.
///
/// O texto usa a formatação do WhatsApp (`*negrito*`) e é montado a partir do
/// snapshot salvo no histórico — não depende de rede nem do carrinho atual.
class PurchaseShareService {
  const PurchaseShareService();

  static const String notInformed = 'Não informado';

  String marketLabel(Purchase purchase) {
    final name = _clean(purchase.storeName);
    if (name.isEmpty || name == 'Compra sem mercado') {
      return notInformed;
    }
    return name;
  }

  String buildMessage(Purchase purchase) {
    final items = purchase.items;
    final itemLines = items.isEmpty
        ? 'Nenhum item registrado.'
        : items.map(_itemLine).join('\n');

    final buffer = StringBuffer()
      ..writeln('🛒 *SomaAí - Resumo da Compra*')
      ..writeln('📍 Mercado: ${marketLabel(purchase)}')
      ..writeln('📅 Data: ${Formatters.numericDate(purchase.date)}')
      ..writeln()
      ..writeln('🧾 *Itens Comprados:*')
      ..writeln(itemLines)
      ..writeln()
      ..writeln('💰 *Total Pago:* ${Formatters.currency(purchase.total)}')
      ..writeln(
        '🤑 *Economia Alcançada:* ${Formatters.currency(purchase.savings)}',
      )
      ..writeln()
      ..write('✅ *Sem sustos no caixa!*');

    return buffer.toString();
  }

  Future<ShareResult> share(
    Purchase purchase, {
    Rect? sharePositionOrigin,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        text: buildMessage(purchase),
        subject: 'SomaAí - Resumo da Compra',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  String _itemLine(PurchaseItem item) {
    final name = _clean(item.name);
    final weight = item.weightKg;
    final suffix = weight == null ? '' : ' (${Formatters.weight(weight)})';
    return '${item.itemCount}x $name$suffix - '
        '${Formatters.currency(item.totalPrice)}';
  }

  String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
