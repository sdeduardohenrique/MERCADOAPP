/// Normalização de texto usada por setores e pelo matcher de produtos.
String normalizeShoppingText(String value) {
  var text = value.toLowerCase();
  const replacements = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
