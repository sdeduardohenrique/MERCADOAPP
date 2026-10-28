import 'dart:math' as math;

/// Cenários clássicos de promoção de supermercado.
enum PromotionKind { wholesale, buyXPayY }

/// "A partir de N unidades, cada uma sai por R$ X".
class WholesalePromotion {
  final double normalUnitPrice;
  final int quantity;
  final double promoUnitPrice;

  const WholesalePromotion({
    required this.normalUnitPrice,
    required this.quantity,
    required this.promoUnitPrice,
  });

  bool get isValid =>
      normalUnitPrice > 0 && promoUnitPrice > 0 && quantity >= 2;

  double get total => quantity * promoUnitPrice;

  double get normalTotal => quantity * normalUnitPrice;

  double get savings => normalTotal - total;

  bool get hasSavings => savings > 0.004;

  double get savingsPercent =>
      normalTotal <= 0 ? 0 : (savings / normalTotal) * 100;

  double get effectiveUnitPrice => quantity <= 0 ? 0 : total / quantity;
}

/// "Leve X, pague Y": o total pago é dividido entre as X unidades levadas.
class BuyXPayYPromotion {
  final int take;
  final int pay;
  final double unitPrice;

  const BuyXPayYPromotion({
    required this.take,
    required this.pay,
    required this.unitPrice,
  });

  bool get isValid => take >= 2 && pay >= 1 && pay < take && unitPrice > 0;

  int get freeUnits => take - pay;

  /// Total efetivamente pago (apenas pelas unidades cobradas).
  double get total => pay * unitPrice;

  double get normalTotal => take * unitPrice;

  /// Preço unitário rateado: total pago / quantidade levada.
  double get effectiveUnitPrice => take <= 0 ? 0 : total / take;

  double get savings => normalTotal - total;

  bool get hasSavings => savings > 0.004;

  double get savingsPercent =>
      normalTotal <= 0 ? 0 : (savings / normalTotal) * 100;
}

/// Unidades aceitas no comparador de custo.
enum MeasureUnit { gram, kilogram, milliliter, liter }

extension MeasureUnitX on MeasureUnit {
  bool get isMass => this == MeasureUnit.gram || this == MeasureUnit.kilogram;

  bool get isVolume =>
      this == MeasureUnit.milliliter || this == MeasureUnit.liter;

  String get label => switch (this) {
        MeasureUnit.gram => 'g',
        MeasureUnit.kilogram => 'kg',
        MeasureUnit.milliliter => 'ml',
        MeasureUnit.liter => 'L',
      };

  /// Unidade base usada na comparação: kg para massa, L para volume.
  String get baseLabel => isMass ? 'kg' : 'L';

  /// Converte a quantidade informada para a unidade base.
  double toBase(double amount) => switch (this) {
        MeasureUnit.gram => amount / 1000,
        MeasureUnit.kilogram => amount,
        MeasureUnit.milliliter => amount / 1000,
        MeasureUnit.liter => amount,
      };
}

/// Uma embalagem (preço + tamanho) do comparador.
class UnitCostOption {
  final double price;
  final double amount;
  final MeasureUnit unit;

  const UnitCostOption({
    required this.price,
    required this.amount,
    required this.unit,
  });

  bool get isValid => price > 0 && amount > 0;

  /// Tamanho na unidade base (kg ou L).
  double? get baseAmount => isValid ? unit.toBase(amount) : null;

  /// Preço por kg (massa) ou por L (volume).
  double? get pricePerBase {
    final base = baseAmount;
    if (base == null || base <= 0) return null;
    return price / base;
  }

  String get sizeLabel => formatMeasure(amount, unit);
}

/// Resultado da comparação entre duas embalagens.
class UnitCostComparison {
  final UnitCostOption optionA;
  final UnitCostOption optionB;

  /// `null` quando faltam dados ou as dimensões são incompatíveis.
  final UnitCostOption? winner;

  final bool isTie;
  final String? invalidReason;

  const UnitCostComparison._({
    required this.optionA,
    required this.optionB,
    this.winner,
    this.isTie = false,
    this.invalidReason,
  });

  bool get isValid => winner != null || isTie;

  UnitCostOption? get loser {
    final winnerOption = winner;
    if (winnerOption == null) return null;
    return identical(winnerOption, optionA) ? optionB : optionA;
  }

  String get baseLabel => optionA.unit.baseLabel;

  double? get differencePerBase {
    final winnerOption = winner;
    final loserOption = loser;
    if (winnerOption == null || loserOption == null) return null;
    final winnerPrice = winnerOption.pricePerBase;
    final loserPrice = loserOption.pricePerBase;
    if (winnerPrice == null || loserPrice == null) return null;
    return (loserPrice - winnerPrice).abs();
  }

  double? get differencePercent {
    final winnerOption = winner;
    final loserOption = loser;
    if (winnerOption == null || loserOption == null) return null;
    final winnerPrice = winnerOption.pricePerBase;
    final loserPrice = loserOption.pricePerBase;
    if (winnerPrice == null || loserPrice == null || loserPrice <= 0) {
      return null;
    }
    return ((loserPrice - winnerPrice).abs() / loserPrice) * 100;
  }
}

/// Compara duas embalagens convertendo tudo para kg ou L.
///
/// Regras:
/// - preço e quantidade precisam ser maiores que zero nas duas opções;
/// - massa (g/kg) só compara com massa; volume (ml/L) só com volume;
/// - empate técnico (< R$ 0,005 de diferença) não destaca vencedor.
UnitCostComparison compareUnitCosts(
  UnitCostOption optionA,
  UnitCostOption optionB,
) {
  if (!optionA.isValid || !optionB.isValid) {
    return UnitCostComparison._(
      optionA: optionA,
      optionB: optionB,
      invalidReason: 'Informe o preço e a quantidade das duas opções.',
    );
  }

  if (optionA.unit.isMass != optionB.unit.isMass) {
    return UnitCostComparison._(
      optionA: optionA,
      optionB: optionB,
      invalidReason:
          'Compare apenas unidades de peso (g/kg) ou de volume (ml/L).',
    );
  }

  final priceA = optionA.pricePerBase!;
  final priceB = optionB.pricePerBase!;
  final diff = priceA - priceB;

  if (diff.abs() < 0.005) {
    return UnitCostComparison._(
      optionA: optionA,
      optionB: optionB,
      isTie: true,
    );
  }

  return UnitCostComparison._(
    optionA: optionA,
    optionB: optionB,
    winner: diff < 0 ? optionA : optionB,
  );
}

/// Formata um tamanho na unidade informada: `800 g`, `1,6 kg`, `500 ml`, `2 L`.
String formatMeasure(double amount, MeasureUnit unit) {
  final rounded = double.parse(amount.toStringAsFixed(3));
  final text = rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded
          .toStringAsFixed(3)
          .replaceAll('.', ',')
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r',$'), '');
  return '$text ${unit.label}';
}

/// Converte texto digitado (`14`, `14,00`, `14.00`, `1,6`) em `double`.
double? parseDecimalInput(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^\d.,]'), '').trim();
  if (cleaned.isEmpty) return null;

  final lastComma = cleaned.lastIndexOf(',');
  final lastDot = cleaned.lastIndexOf('.');
  final separator = math.max(lastComma, lastDot);

  String normalized;
  if (separator < 0) {
    normalized = cleaned;
  } else {
    final integerPart =
        cleaned.substring(0, separator).replaceAll(RegExp(r'[.,]'), '');
    final decimalPart =
        cleaned.substring(separator + 1).replaceAll(RegExp(r'[.,]'), '');
    normalized = decimalPart.isEmpty
        ? integerPart
        : '${integerPart.isEmpty ? '0' : integerPart}.$decimalPart';
  }

  final value = double.tryParse(normalized);
  if (value == null || value.isNaN || value.isInfinite) return null;
  return value;
}
