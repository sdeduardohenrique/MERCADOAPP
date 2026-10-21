import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/mercado.dart';

/// Mercado da compra em andamento.
///
/// O carrinho continua sendo `List<CartItem>`; este provider guarda o contexto
/// espacial da compra para que cada item possa alimentar a comunidade.
class SelectedMarketNotifier extends StateNotifier<Mercado?> {
  SelectedMarketNotifier() : super(null);

  void select(Mercado market) => state = market;

  void clear() => state = null;
}

final selectedMarketProvider =
    StateNotifierProvider<SelectedMarketNotifier, Mercado?>((ref) {
  return SelectedMarketNotifier();
});
