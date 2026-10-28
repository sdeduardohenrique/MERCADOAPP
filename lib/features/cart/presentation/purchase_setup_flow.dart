import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../community/presentation/providers/market_provider.dart';
import '../../community/presentation/widgets/market_selection_sheet.dart';
import 'providers/purchase_budget_provider.dart';
import 'widgets/purchase_budget_sheet.dart';

/// Prepara uma compra nova pedindo o mercado e o orçamento antes de abrir o
/// carrinho. É usado tanto pela Home quanto pelo botão "Iniciar Compra no
/// Mercado" das listas, para que os dois caminhos tenham o mesmo onboarding.
///
/// Retorna `false` quando o utilizador fecha a seleção de mercado sem decidir.
/// O orçamento é opcional: fechar a folha continua a compra sem teto, assim
/// como em [showPurchaseBudgetSheet].
Future<bool> prepareNewPurchase(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await showMarketSelectionSheet(context);
  if (!context.mounted || result.action == MarketSelectionAction.dismissed) {
    return false;
  }

  final market = result.market;
  if (market == null) {
    ref.read(selectedMarketProvider.notifier).clear();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Compra sem mercado: os preços ficarão apenas no seu histórico.',
          ),
        ),
      );
  } else {
    ref.read(selectedMarketProvider.notifier).select(market);

    if (!market.isRemoto) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Mercado salvo neste dispositivo. A sincronização acontece quando houver conexão.',
            ),
          ),
        );
    }
  }

  final budget = await showPurchaseBudgetSheet(context);
  if (!context.mounted) return false;
  ref.read(purchaseBudgetProvider.notifier).setBudget(budget?.budget);
  return true;
}
