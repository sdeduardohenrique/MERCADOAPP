import 'package:intl/intl.dart';

/// Formatadores do app.
///
/// Evitamos `DateFormat(..., 'pt_BR')` para não depender da inicialização dos
/// dados de locale do `intl` no primeiro frame. `NumberFormat.currency` com
/// locale pt_BR funciona sem inicialização explícita.
class Formatters {
  Formatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 2,
  );

  static const List<String> _monthsShort = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  static const List<String> _monthsLong = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  /// R$ 1.234,56
  static String currency(double value) => _currency.format(value);

  /// Hoje / Ontem / 12 out
  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    if (diff > 1 && diff < 7) return 'Há $diff dias';

    return '${date.day.toString().padLeft(2, '0')} ${_monthsShort[date.month - 1]}';
  }

  /// 20 de outubro de 2026
  static String longDate(DateTime date) =>
      '${date.day} de ${_monthsLong[date.month - 1]} de ${date.year}';

  /// 28/10/2026
  static String numericDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  /// Outubro
  static String monthName(DateTime date) {
    final name = _monthsLong[date.month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  /// R$ 12,90 → "12,90"
  static String currencyCompact(double value) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2)
          .format(value)
          .trim();

  /// 500 g · 1 kg · 1,25 kg
  static String weight(double kg) {
    final grams = (kg * 1000).round();
    if (grams > 0 && grams < 1000) return '$grams g';

    final value = grams / 1000;
    if (value == value.roundToDouble()) return '${value.toInt()} kg';

    return '${value.toStringAsFixed(3).replaceAll('.', ',').replaceFirst(RegExp(r'0+$'), '')} kg';
  }

  /// 1,000 (used by weight inputs)
  static String weightInput(double kg) =>
      kg.toStringAsFixed(3).replaceAll('.', ',');

  /// 12% (sem casas decimais quando inteiro)
  static String percent(double value) {
    final rounded = value.roundToDouble();
    return value == rounded
        ? '${value.toInt()}%'
        : '${value.toStringAsFixed(1).replaceAll('.', ',')}%';
  }
}
