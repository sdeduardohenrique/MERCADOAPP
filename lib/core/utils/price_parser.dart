import 'text_normalizer.dart';

/// Parses OCR text to extract product information from Brazilian price labels.
///
/// The parser is deliberately conservative: a number only becomes a price when
/// it has an explicit monetary shape (two decimals, ideally preceded by `R$`)
/// and passes the sanity range. Random numbers, dates, barcodes and package
/// weights are ignored so they cannot become imaginary cart items.
class PriceParser {
  /// Smallest unit price accepted for a regular grocery item.
  static const double minUnitPrice = 0.10;

  /// Largest unit price accepted for a regular grocery item.
  ///
  /// Special electronics can cost more; the camera flow intentionally rejects
  /// them rather than risk turning an arbitrary number into a purchase.
  static const double maxUnitPrice = 500.00;

  static const int _maxNameLength = 90;

  // R$ 12,90 · R$12,90 · R$ 1.234,56 · R$ 12.90
  static final RegExp _currencyPriceRegex = RegExp(
    r'R\$\s*(-?\d{1,3}(?:\.\d{3})*,\d{2}|\d{1,3}(?:,\d{3})*\.\d{2}|\d+[.,]\d{2})(?![\d.,])',
    caseSensitive: false,
  );

  // 12,90 · 1.234,56 · 12.90 — only used when the line is isolated or has a
  // price keyword immediately before it.
  static final RegExp _strictPriceRegex = RegExp(
    r'(?<![\d.,])(\d{1,3}(?:\.\d{3})*,\d{2}|\d{1,3}(?:,\d{3})*\.\d{2}|\d+[.,]\d{2})(?![\d.,])',
  );

  // "2x 4,99" / "3x R$ 4,99"
  static final RegExp _promoXRegex = RegExp(
    r'(?<![\d.,])(\d{1,2})\s*[xX]\s*(?:R\$\s*)?(\d{1,3}(?:\.\d{3})*,\d{2}|\d+[.,]\d{2})(?![\d.,])',
  );

  // "3 por 10,00" — the lookbehind prevents matching the cents of "29,90 por".
  static final RegExp _promoPorRegex = RegExp(
    r'(?<![\d.,])(\d{1,2})\s+por\s+(?:R\$\s*)?(\d{1,3}(?:\.\d{3})*,\d{2}|\d+[.,]\d{2})(?![\d.,])',
    caseSensitive: false,
  );

  // A keyword that turns a bare number into a price ("POR 12,90").
  static final RegExp _priceKeywordRegex = RegExp(
    r'(?:^|\b)(?:por|preço|preco|valor|unit[áa]rio|cada|a\s+partir\s+de|somente|s[óo])\s*$',
    caseSensitive: false,
  );

  static final RegExp _isolatedBeforeRegex = RegExp(
    r'^(?:preço|preco|valor|por|cada|de|a\s+partir\s+de|somente|s[óo])?$',
    caseSensitive: false,
  );

  static final RegExp _isolatedAfterRegex = RegExp(
    r'^/?(?:un|unid|und|unidade|kg|g|gr|ml|l|lt|litro|pacote|pct|caixa|cx|dz|d[úu]zia|cada|a\s+vista|à\s+vista)?$',
    caseSensitive: false,
  );

  static final RegExp _dateRegex = RegExp(
    r'\b\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}\b',
  );

  static final RegExp _eanLineRegex = RegExp(r'^\s*\d{8,14}\s*$');
  static final RegExp _percentRegex = RegExp(r'\d\s*%');

  static final RegExp _metaLineRegex = RegExp(
    r'\b(?:validade|vence|vencimento|fabric|fabrica[çc][aã]o|lote|ean|c[óo]digo|cod|ref|tel|cnpj|ie|inscri[çc][aã]o)\b',
    caseSensitive: false,
  );

  static final RegExp _labelNoiseRegex = RegExp(
    r'^(?:oferta|promo[çc][aã]o|preço|preco|valor|leve|pague|aproveite|unidade|atacado|varejo|cliente|consumidor)\b',
    caseSensitive: false,
  );

  // "500 g", "1,5 kg", "2 un" are package sizes, not prices. A two-decimal
  // value ("18,90 un") is intentionally NOT matched here: it is a price.
  static final RegExp _unitOnlyRegex = RegExp(
    r'^\s*\d+(?:[.,]\d)?\s*(?:kg|g|gr|ml|l|lt|litro|un|unid|und|pct|pacote|caixa|cx)\s*$',
    caseSensitive: false,
  );

  /// Parses OCR text and extracts product information.
  static ParsedOcrItem? parseFromOcr(String fullText) {
    final lines = _nonEmptyLines(fullText);

    if (lines.isEmpty) return null;

    final best = _findBestPrice(lines);
    if (best == null) return null;

    final price = best.value;
    final name = _extractProductName(lines);
    if (name == null || name.length < 2) return null;

    final qtyInfo = _extractQuantityUnit(lines);
    // Package weight ("5 kg", "1 L") is a unit, not a quantity. Only an
    // explicit promo multiplier ("2x 4,99") changes the cart quantity.
    final quantity = best.promoQuantity ?? 1;
    final unit = qtyInfo['unit'] as String?;

    return ParsedOcrItem(
      name: TextNormalizer.cleanProductName(name),
      brand: _extractBrand(lines, name),
      unitPrice: price,
      quantity: quantity,
      unit: unit,
    );
  }

  /// Extracts only a reliable price from OCR.
  ///
  /// Used when the camera read a price but could not identify a usable product
  /// name. The same conservative rules of [parseFromOcr] apply.
  static double? parsePriceFromOcr(String fullText) {
    final lines = _nonEmptyLines(fullText);
    if (lines.isEmpty) return null;
    return _findBestPrice(lines)?.value;
  }

  /// Extracts a possible product name even when no price was found.
  ///
  /// The scanner uses this only to pre-fill the partial-read sheet; the user
  /// still confirms the value before it enters the cart.
  static String? extractProductNameFromOcr(String fullText) {
    final lines = _nonEmptyLines(fullText);
    if (lines.isEmpty) return null;

    final name = _extractProductName(lines);
    if (name == null || name.length < 2) return null;
    return TextNormalizer.cleanProductName(name);
  }

  static List<String> _nonEmptyLines(String fullText) {
    return fullText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Parses a monetary string into a double.
  ///
  /// Accepts `12,90`, `12.90`, `1.234,56` and `1,234.56`. Returns `null` when
  /// the string does not have exactly two decimal places.
  static double? parsePrice(String raw) {
    var value = raw.replaceAll(RegExp(r'[^\d.,\-]'), '');
    if (value.isEmpty) return null;

    final negative = value.startsWith('-');
    value = value.replaceAll('-', '');

    if (!RegExp(r'[.,]\d{2}$').hasMatch(value)) return null;

    final lastComma = value.lastIndexOf(',');
    final lastDot = value.lastIndexOf('.');

    if (lastComma >= 0 && lastComma > lastDot) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot >= 0) {
      value = value.replaceAll(',', '');
    } else {
      return null;
    }

    final parsed = double.tryParse(value);
    if (parsed == null) return null;
    return negative ? -parsed : parsed;
  }

  static bool isSanePrice(double? value) {
    return value != null && value >= minUnitPrice && value <= maxUnitPrice;
  }

  static _PriceCandidate? _findBestPrice(List<String> lines) {
    final candidates = <_PriceCandidate>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      if (_shouldIgnoreLine(line, lower)) continue;

      // Promotions are checked first so "2x R$ 4,99" keeps the quantity.
      for (final match in _promoXRegex.allMatches(line)) {
        final candidate = _promoCandidate(
          match.group(1),
          match.group(2),
          lineIndex: i,
          score: 115,
          raw: match.group(0)!,
        );
        if (candidate != null) candidates.add(candidate);
      }

      for (final match in _promoPorRegex.allMatches(line)) {
        final candidate = _promoCandidate(
          match.group(1),
          match.group(2),
          lineIndex: i,
          score: 118,
          raw: match.group(0)!,
        );
        if (candidate != null) candidates.add(candidate);
      }

      // Explicit currency: highest confidence, anywhere on the line.
      for (final match in _currencyPriceRegex.allMatches(line)) {
        final value = parsePrice(match.group(1)!);
        if (!isSanePrice(value)) continue;

        final before = line.substring(0, match.start).toLowerCase();
        final keywordBonus = _priceKeywordRegex.hasMatch(before) ? 15 : 0;
        candidates.add(
          _PriceCandidate(
            value: value!,
            score: 100 + keywordBonus,
            lineIndex: i,
            start: match.start,
            raw: match.group(0)!,
          ),
        );
      }

      // Bare numbers: only isolated price lines ("12,90", "12,90 un") or a
      // number immediately preceded by "por", "preço", "valor", etc.
      if (!_currencyPriceRegex.hasMatch(line)) {
        for (final match in _strictPriceRegex.allMatches(line)) {
          final value = parsePrice(match.group(1)!);
          if (!isSanePrice(value)) continue;

          final before = line.substring(0, match.start).trim();
          final after = line.substring(match.end).trim();
          final keyword = _priceKeywordRegex.hasMatch(before.toLowerCase());
          final isolated = _isIsolatedPriceLine(before, after);

          if (!keyword && !isolated) continue;

          candidates.add(
            _PriceCandidate(
              value: value!,
              score: keyword ? 90 : 70,
              lineIndex: i,
              start: match.start,
              raw: match.group(0)!,
            ),
          );
        }
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      // Same confidence: the last price on the label is usually the
      // highlighted/promotional one.
      final byLine = b.lineIndex.compareTo(a.lineIndex);
      if (byLine != 0) return byLine;
      return b.start.compareTo(a.start);
    });

    // Cross-frame confirmation (two consecutive equal readings) is enforced by
    // LabelScannerService, so a single strong reading is enough here.
    return candidates.first;
  }

  static _PriceCandidate? _promoCandidate(
    String? quantityRaw,
    String? totalRaw, {
    required int lineIndex,
    required int score,
    required String raw,
  }) {
    final quantity = int.tryParse(quantityRaw ?? '');
    final total = parsePrice(totalRaw ?? '');
    if (quantity == null || quantity <= 0 || total == null) return null;

    final unitPrice = total / quantity;
    if (!isSanePrice(unitPrice)) return null;

    return _PriceCandidate(
      value: unitPrice,
      score: score,
      lineIndex: lineIndex,
      start: 0,
      raw: raw,
      promoQuantity: quantity,
    );
  }

  static bool _shouldIgnoreLine(String line, String lower) {
    if (_dateRegex.hasMatch(line)) return true;
    if (_eanLineRegex.hasMatch(line)) return true;
    if (_percentRegex.hasMatch(line)) return true;
    if (_metaLineRegex.hasMatch(lower)) return true;
    if (_unitOnlyRegex.hasMatch(line)) return true;
    return false;
  }

  static bool _isIsolatedPriceLine(String before, String after) {
    final cleanBefore = before.replaceAll(RegExp(r'[R$\s:.\-]'), '');
    final cleanAfter = after.replaceAll(RegExp(r'\s'), '');
    return _isolatedBeforeRegex.hasMatch(cleanBefore) &&
        _isolatedAfterRegex.hasMatch(cleanAfter);
  }

  static String? _extractProductName(List<String> lines) {
    final candidates = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i].trim();
      if (raw.length < 3) continue;
      if (_eanLineRegex.hasMatch(raw)) continue;
      if (_metaLineRegex.hasMatch(raw)) continue;
      if (_labelNoiseRegex.hasMatch(raw.toLowerCase())) continue;
      if (_unitOnlyRegex.hasMatch(raw)) continue;

      // OCR sometimes merges "Leite R$ 4,49" into one line. Strip the
      // monetary part instead of discarding the product name with it.
      final line = raw
          .replaceAll(_currencyPriceRegex, ' ')
          .replaceAll(_strictPriceRegex, ' ')
          .replaceAll(RegExp(r'\b\d{8,14}\b'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (line.length < 3) continue;
      if (_labelNoiseRegex.hasMatch(line.toLowerCase())) continue;
      if (!RegExp(r'[A-Za-zÀ-ÿ]{3,}').hasMatch(line)) continue;

      final letters = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(line).length;
      final digits = RegExp(r'\d').allMatches(line).length;
      if (letters < 3 || digits > letters) continue;

      candidates.add(line);
    }

    if (candidates.isEmpty) return null;

    // Product names are usually the longest textual line on the label.
    candidates.sort((a, b) => b.length.compareTo(a.length));
    final name = candidates.first;
    return name.length > _maxNameLength
        ? name.substring(0, _maxNameLength).trim()
        : name;
  }

  static String? _extractBrand(List<String> lines, String? name) {
    if (name == null) return null;

    final nameIndex = lines.indexOf(name);
    if (nameIndex > 0 && lines[nameIndex - 1].length > 1) {
      final previous = lines[nameIndex - 1];
      if (!_currencyPriceRegex.hasMatch(previous) &&
          !_strictPriceRegex.hasMatch(previous)) {
        return previous;
      }
    }

    const knownBrands = [
      'Nestlé',
      'Coca-Cola',
      'Pepsi',
      'Ambev',
      'Sadia',
      'Perdigão',
      'Qualy',
      'Doriana',
      'Clight',
      'Tang',
      'Marmitex',
      'Knorr',
      'Ajinomoto',
      'Maggi',
      'Vono',
      'Arisco',
      'Hemmer',
      'Camil',
      'Tio João',
      'Prato Fino',
      'Namorado',
      'Carrefour',
      'Extra',
      'Pão de Açúcar',
      'Assaí',
      'Atacadão',
      'Mateus',
      'Supermercados',
    ];

    for (final line in lines) {
      for (final brand in knownBrands) {
        if (line.toLowerCase().contains(brand.toLowerCase())) {
          return brand;
        }
      }
    }
    return null;
  }

  static Map<String, dynamic> _extractQuantityUnit(List<String> lines) {
    final quantityRegex = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:x|X|un|unid|kg|g|ml|l|L)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = quantityRegex.firstMatch(line);
      if (match != null) {
        final qtyStr = match.group(1)!.replaceAll(',', '.');
        final qty = double.tryParse(qtyStr);
        String? unit =
            match.group(0)!.replaceAll(RegExp(r'[\d.,\sxX]'), '').toLowerCase();
        unit = unit
            .replaceAll('unid', 'un')
            .replaceAll('litro', 'L')
            .replaceAll('quilograma', 'kg')
            .replaceAll('grama', 'g')
            .replaceAll('mililitro', 'ml');
        if (unit.isEmpty) unit = 'un';
        return {'quantity': qty?.round() ?? 1, 'unit': unit};
      }
    }
    return {'quantity': 1, 'unit': 'un'};
  }
}

class _PriceCandidate {
  final double value;
  final int score;
  final int lineIndex;
  final int start;
  final String raw;
  final int? promoQuantity;

  const _PriceCandidate({
    required this.value,
    required this.score,
    required this.lineIndex,
    required this.start,
    required this.raw,
    this.promoQuantity,
  });
}

/// Represents a parsed item from OCR.
class ParsedOcrItem {
  final String name;
  final String? brand;
  final double unitPrice;
  final int? quantity;
  final String? unit;

  ParsedOcrItem({
    required this.name,
    this.brand,
    required this.unitPrice,
    this.quantity,
    this.unit,
  });
}
