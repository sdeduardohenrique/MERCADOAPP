import 'shopping_text.dart';

/// Setores do supermercado usados para agrupar a lista e otimizar o percurso.
enum ShoppingSector {
  hortifruti(
    label: 'Hortifrúti',
    emoji: '🥬',
    keywords: [
      'tomate',
      'alface',
      'maca',
      'banana',
      'cebola',
      'batata',
      'cenoura',
      'laranja',
      'limao',
      'uva',
      'morango',
      'abacaxi',
      'melancia',
      'brocolis',
      'couve',
      'pepino',
      'abobrinha',
      'berinjela',
      'pimentao',
      'alho',
      'fruta',
      'verdura',
      'legume',
      'hortifruti',
    ],
  ),
  acougue(
    label: 'Açougue & Peixaria',
    emoji: '🥩',
    keywords: [
      'carne',
      'patinho',
      'moido',
      'moida',
      'frango',
      'peixe',
      'file',
      'picanha',
      'alcatra',
      'costela',
      'linguica',
      'salsicha',
      'bacon',
      'camarao',
      'tilapia',
      'salmão',
      'salmao',
      'acougue',
      'peixaria',
    ],
  ),
  laticinios(
    label: 'Laticínios & Frios',
    emoji: '🥛',
    keywords: [
      'leite',
      'queijo',
      'manteiga',
      'margarina',
      'iogurte',
      'requeijao',
      'cream cheese',
      'nata',
      'creme de leite',
      'ovos',
      'ovo',
      'presunto',
      'mortadela',
      'salame',
      'peito de peru',
      'sorvete',
      'laticinio',
      'frios',
    ],
  ),
  limpeza(
    label: 'Limpeza & Lavanderia',
    emoji: '🧹',
    keywords: [
      'detergente',
      'sabao em po',
      'sabao liquido',
      'sabao',
      'amaciante',
      'desinfetante',
      'agua sanitaria',
      'multiuso',
      'limpa vidro',
      'esponja',
      'vassoura',
      'rodo',
      'saco de lixo',
      'papel higienico',
      'limpeza',
      'lavanderia',
    ],
  ),
  mercearia(
    label: 'Mercearia & Mantimentos',
    emoji: '🥫',
    keywords: [
      'arroz',
      'feijao',
      'oleo',
      'acucar',
      'macarrao',
      'farinha',
      'sal',
      'leite condensado',
      'leite em po',
      'molho',
      'extrato de tomate',
      'atum',
      'sardinha',
      'milho',
      'ervilha',
      'azeite',
      'vinagre',
      'tempero',
      'mercearia',
      'mantimento',
    ],
  ),
  padaria(
    label: 'Padaria & Matinais',
    emoji: '🍞',
    keywords: [
      'pao de forma',
      'pao frances',
      'pao',
      'bolo',
      'biscoito',
      'bolacha',
      'cereal',
      'aveia',
      'granola',
      'achocolatado',
      'manteiga de amendoim',
      'cafe',
      'padaria',
      'matinal',
      'cafe da manha',
    ],
  ),
  outros(
    label: 'Outros',
    emoji: '🛒',
    keywords: [],
  );

  const ShoppingSector({
    required this.label,
    required this.emoji,
    required this.keywords,
  });

  final String label;
  final String emoji;
  final List<String> keywords;

  String get id => name;

  static ShoppingSector fromId(String? value) {
    if (value == null || value.isEmpty) return ShoppingSector.outros;
    for (final sector in values) {
      if (sector.id == value) return sector;
    }
    return ShoppingSector.outros;
  }

  /// Categoriza pelo termo mais específico encontrado no nome.
  ///
  /// Ex.: "Leite condensado" cai em Mercearia (keyword maior) e não em
  /// Laticínios; "Pão de forma" cai em Padaria e não em Mercearia.
  static ShoppingSector categorize(String name) {
    final normalized = normalizeShoppingText(name);
    if (normalized.isEmpty) return ShoppingSector.outros;

    ShoppingSector best = ShoppingSector.outros;
    var bestLength = 0;

    for (final sector in values) {
      for (final keyword in sector.keywords) {
        if (normalized.contains(keyword) && keyword.length > bestLength) {
          best = sector;
          bestLength = keyword.length;
        }
      }
    }
    return best;
  }
}

/// Unidades aceitas no banco e na interface.
class ShoppingUnitOption {
  const ShoppingUnitOption(this.id, this.label);

  final String id;
  final String label;
}

const List<ShoppingUnitOption> shoppingUnitOptions = [
  ShoppingUnitOption('un', 'un (unidade)'),
  ShoppingUnitOption('kg', 'kg (quilo)'),
  ShoppingUnitOption('g', 'g (grama)'),
  ShoppingUnitOption('L', 'L (litro)'),
  ShoppingUnitOption('ml', 'ml (mililitro)'),
  ShoppingUnitOption('cx', 'cx (caixa)'),
  ShoppingUnitOption('pacote', 'pacote'),
  ShoppingUnitOption('dz', 'dz (dúzia)'),
];

const Set<String> _validShoppingUnits = {
  'un',
  'kg',
  'g',
  'L',
  'ml',
  'cx',
  'pacote',
  'dz',
};

String normalizeShoppingUnit(String? value) {
  if (value == null) return 'un';
  return _validShoppingUnits.contains(value) ? value : 'un';
}

String shoppingUnitLabel(String value) {
  for (final option in shoppingUnitOptions) {
    if (option.id == value) return option.id;
  }
  return 'un';
}

/// 1 → "1 un"; 1,5 → "1,5 kg"; 0,250 → "250 g" não é convertido: mantém a
/// unidade escolhida para não surpreender o utilizador.
String formatShoppingQuantity(double quantity, String unit) {
  final normalized = normalizeShoppingUnit(unit);
  final rounded = double.parse(quantity.toStringAsFixed(3));
  final isInteger = rounded == rounded.roundToDouble();
  final value = isInteger
      ? rounded.toInt().toString()
      : rounded
          .toStringAsFixed(3)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll('.', ',');
  return '$value ${shoppingUnitLabel(normalized)}';
}
