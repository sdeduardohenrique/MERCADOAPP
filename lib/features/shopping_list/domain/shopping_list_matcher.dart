import 'shopping_list.dart';
import 'shopping_text.dart';

const Set<String> _stopwords = {
  'a',
  'o',
  'as',
  'os',
  'de',
  'da',
  'do',
  'das',
  'dos',
  'em',
  'e',
  'com',
  'para',
  'por',
  'sem',
  'tipo',
  'un',
  'und',
  'kg',
  'g',
  'l',
  'ml',
  'mg',
  'pack',
  'pacote',
};

final RegExp _measurement = RegExp(r'^\d+([.,]\d+)?(kg|g|l|ml|mg|un|und)?$');

List<String> _words(String normalized) =>
    normalized.isEmpty ? const [] : normalized.split(' ');

Set<String> _baseTokens(String normalized) {
  final tokens = <String>{};
  for (final word in _words(normalized)) {
    if (word.length < 2) continue;
    if (_stopwords.contains(word)) continue;
    if (_measurement.hasMatch(word)) continue;
    tokens.add(word);
  }
  return tokens;
}

Set<String> _expandedTokens(String normalized) {
  final tokens = <String>{};
  for (final word in _words(normalized)) {
    if (word.length < 2 || _stopwords.contains(word)) continue;
    tokens.add(word);
    if (word.length > 3 && word.endsWith('s')) {
      tokens.add(word.substring(0, word.length - 1));
    }
  }
  return tokens;
}

/// Pontuação de semelhança entre um item da lista e um produto do carrinho.
///
/// 100 = nome idêntico; 80–95 = todas as palavras da lista aparecem no
/// produto (ou vice-versa); 50–70 = sobreposição forte de palavras.
double shoppingMatchScore(String listName, String productName) {
  final list = normalizeShoppingText(listName);
  final product = normalizeShoppingText(productName);
  if (list.isEmpty || product.isEmpty) return 0;
  if (list == product) return 100;

  final listWords = _words(list);
  final productWords = _words(product);
  final listInsideProduct = listWords.every(productWords.contains);
  final productInsideList = productWords.every(listWords.contains);
  if (listInsideProduct || productInsideList) {
    final shorter =
        list.length <= product.length ? list.length : product.length;
    final longer = list.length >= product.length ? list.length : product.length;
    return 80 + (shorter / longer) * 15;
  }

  final listBase = _baseTokens(list);
  final productBase = _baseTokens(product);
  if (listBase.isEmpty || productBase.isEmpty) return 0;

  final common = _expandedTokens(list).intersection(_expandedTokens(product));
  final coverage = common.length / listBase.length;
  if (coverage >= 0.75) return 50 + coverage * 20;
  return 0;
}

/// Encontra o item pendente mais parecido com [productName].
///
/// Apenas um item é riscado por produto: o de maior pontuação. Itens já
/// comprados são ignorados, evitando marcar duas vezes a mesma linha.
ShoppingListItem? bestShoppingListItemMatch(
  String productName,
  Iterable<ShoppingListItem> items,
) {
  ShoppingListItem? best;
  var bestScore = 0.0;
  for (final item in items) {
    if (item.isBought) continue;
    final score = shoppingMatchScore(item.name, productName);
    if (score > bestScore) {
      bestScore = score;
      best = item;
    }
  }
  return bestScore > 0 ? best : null;
}
