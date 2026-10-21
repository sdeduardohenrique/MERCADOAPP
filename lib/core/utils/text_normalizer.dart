/// Text normalization utilities for Portuguese/Brazilian product names
import 'dart:math';

class TextNormalizer {
  /// Removes accents and diacritics from Portuguese text
  static String removeAccents(String text) {
    return text
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[ÀÁÂÃÄÅ]'), 'A')
        .replaceAll(RegExp(r'[ÈÉÊË]'), 'E')
        .replaceAll(RegExp(r'[ÌÍÎÏ]'), 'I')
        .replaceAll(RegExp(r'[ÒÓÔÕÖ]'), 'O')
        .replaceAll(RegExp(r'[ÙÚÛÜ]'), 'U')
        .replaceAll(RegExp(r'[Ç]'), 'C')
        .replaceAll(RegExp(r'[Ñ]'), 'N');
  }

  /// Normalizes text for comparison: lowercase, no accents, no extra spaces
  static String normalize(String text) {
    return removeAccents(text)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Cleans product name from OCR artifacts
  static String cleanProductName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s\-.,()/&%]+'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim()
        .replaceAll(RegExp(r'^(?:R\$\s?\d+[.,]\d{2}\s*)+'), '') // Remove leading prices
        .replaceAll(RegExp(r'\s*(?:R\$\s?)?\d+[.,]\d{2}\s*$'), '') // Remove trailing prices
        .replaceAll(RegExp(r'^\d+\s*[xX]\s*'), '') // Remove leading "2x "
        .trim();
  }

  /// Extracts potential brand from product name
  static String? extractBrand(String name) {
    final knownBrands = [
      'Nestlé', 'Coca-Cola', 'Pepsi', 'Ambev', 'Sadia', 'Perdigão',
      'Qualy', 'Doriana', 'Clight', 'Tang', 'Marmitex', 'Knorr',
      'Ajinomoto', 'Maggi', 'Vono', 'Arisco', 'Hemmer', 'Camil',
      'Tio João', 'Prato Fino', 'Namorado', 'Yoki', 'Predilecta',
      'Quero', 'Elefante', 'Caramuru', 'Ciclo', 'Minerva', 'Friboi',
      'Swift', 'JBS', 'Marfrig', 'Aurora', 'Cooperativa', 'Itambé',
      'Piracanjuba', 'Ninho', 'Molico', 'Chandelle', 'Batavo',
      'Danone', 'Activia', 'Yakult', 'Choco', 'Toddy', 'Nescau',
      'Garoto', 'Lacta', 'Nestle', 'Cacau Show', 'Kopenhagen',
      'Bauducco', 'Pullman', 'Wickbold', 'Seven Boys', 'Panco',
      'Vigor', 'Catupiry', 'Tirolez', 'Polengui', 'Queijos',
      'Seara', 'Frigorífico', 'Frangosul', 'Doux', 'Copacol',
      'C.Vale', 'Aurora', 'Languiru', 'Cooperalfa', 'Cooperja',
    ];

    final normalizedName = normalize(name);
    for (final brand in knownBrands) {
      if (normalizedName.contains(normalize(brand))) {
        return brand;
      }
    }
    return null;
  }

  /// Normalizes unit strings to standard format
  static String normalizeUnit(String unit) {
    final u = unit.toLowerCase().trim();
    switch (u) {
      case 'un':
      case 'unid':
      case 'unidade':
      case 'unidades':
      case 'pc':
      case 'pç':
      case 'peca':
      case 'pecas':
        return 'un';
      case 'kg':
      case 'kilograma':
      case 'quilograma':
      case 'kilogramas':
      case 'quilogramas':
        return 'kg';
      case 'g':
      case 'gr':
      case 'grama':
      case 'gramas':
        return 'g';
      case 'l':
      case 'lt':
      case 'litro':
      case 'litros':
        return 'L';
      case 'ml':
      case 'mililitro':
      case 'mililitros':
      case 'mililitro':
        return 'ml';
      case 'cx':
      case 'caixa':
      case 'caixas':
        return 'cx';
      case 'pt':
      case 'pct':
      case 'pacote':
      case 'pacotes':
        return 'pt';
      default:
        return u;
    }
  }

  /// Calculates similarity between two strings (simple Levenshtein-like)
  static double similarity(String a, String b) {
    final na = normalize(a);
    final nb = normalize(b);
    if (na == nb) return 1.0;
    if (na.isEmpty || nb.isEmpty) return 0.0;

    final longer = na.length > nb.length ? na : nb;
    final shorter = na.length > nb.length ? nb : na;
    final longerLength = longer.length;

    if (longerLength == 0) return 1.0;

    return (longerLength - _editDistance(longer, shorter)) / longerLength;
  }

  static int _editDistance(String a, String b) {
    final costs = List<int>.filled(b.length + 1, 0);
    for (int j = 0; j <= b.length; j++) {
      costs[j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      costs[0] = i;
      int nw = i - 1;
      for (int j = 1; j <= b.length; j++) {
        int cj = min(
          min(costs[j] + 1, costs[j - 1] + 1),
          nw + (a[i - 1] == b[j - 1] ? 0 : 1),
        );
        nw = costs[j];
        costs[j] = cj;
      }
    }
    return costs[b.length];
  }
}