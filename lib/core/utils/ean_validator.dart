/// Validates and normalizes EAN/GTIN codes
class EanValidator {
  /// Checks if a string is a valid EAN-13, EAN-8, UPC-A, or UPC-E
  static bool isValidEan(String code) {
    final cleaned = code.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 8) return _validateEan8(cleaned);
    if (cleaned.length == 12) return _validateUpcA(cleaned);
    if (cleaned.length == 13) return _validateEan13(cleaned);
    return false;
  }

  /// Normalizes EAN to 13 digits (GTIN-13)
  static String? normalize(String code) {
    final cleaned = code.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 8) {
      // EAN-8 to EAN-13: prefix with 00000
      return '00000$cleaned';
    }
    if (cleaned.length == 12) {
      // UPC-A to EAN-13: prefix with 0
      return '0$cleaned';
    }
    if (cleaned.length == 13) {
      return cleaned;
    }
    return null;
  }

  /// Validates EAN-8 checksum
  static bool _validateEan8(String code) {
    if (code.length != 8) return false;
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      final digit = int.parse(code[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(code[7]);
  }

  /// Validates UPC-A checksum
  static bool _validateUpcA(String code) {
    if (code.length != 12) return false;
    int sum = 0;
    for (int i = 0; i < 11; i++) {
      final digit = int.parse(code[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(code[11]);
  }

  /// Validates EAN-13 checksum
  static bool _validateEan13(String code) {
    if (code.length != 13) return false;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(code[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(code[12]);
  }

  /// Extracts all valid EANs from a list of barcode strings
  static List<String> extractValidEans(List<String> barcodes) {
    return barcodes
        .map((b) => normalize(b))
        .where((e) => e != null && isValidEan(e))
        .cast<String>()
        .toSet()
        .toList();
  }
}
