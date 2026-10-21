/// Dados que o scanner conseguiu ler, mesmo quando a etiqueta não trouxe
/// produto e preço na mesma leitura.
///
/// O fluxo completo continua exigindo nome + preço. Quando só um dos lados é
/// reconhecido, este objeto alimenta a folha "Completar informações" para que
/// o utilizador termine o item sem perder a leitura da câmera.
class PartialScanData {
  final String? ean;
  final double? unitPrice;
  final String? suggestedName;

  /// Texto bruto do OCR, guardado para auditoria/depuração no [CartItem].
  final String rawText;

  const PartialScanData({
    this.ean,
    this.unitPrice,
    this.suggestedName,
    this.rawText = '',
  });

  bool get hasEan => ean != null && ean!.isNotEmpty;

  bool get hasPrice => unitPrice != null && unitPrice! > 0;

  bool get isEmpty => !hasEan && !hasPrice;

  String get guidance {
    if (hasEan && hasPrice) {
      return 'Encontramos o código de barras e o preço. '
          'Só falta o nome do produto.';
    }
    if (hasEan) {
      return 'Encontramos o código de barras. '
          'Informe o nome do produto e o preço.';
    }
    return 'Encontramos o preço, mas não o nome. '
        'Informe o nome do produto para continuar.';
  }
}
