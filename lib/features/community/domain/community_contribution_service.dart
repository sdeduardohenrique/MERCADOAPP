import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/cart_item.dart';
import '../../../core/models/mercado.dart';
import '../../../core/services/price_validation_service.dart';
import '../../../core/services/supabase_service.dart';

typedef CommunityPriceSubmitter = Future<bool> Function({
  required CartItem item,
  required String marketId,
});

typedef CommunityContributionGate = bool Function();

/// Alimenta a comunidade em background com os itens da compra atual.
///
/// Só envia quando há mercado remoto e sessão autenticada. Qualquer falha é
/// silenciosa: a compra local nunca depende da contribuição.
class CommunityContributionService {
  CommunityContributionService({
    CommunityPriceSubmitter? submitter,
    CommunityContributionGate? gate,
  })  : _submitter = submitter,
        _gate = gate ?? _defaultGate;

  final CommunityPriceSubmitter? _submitter;
  final CommunityContributionGate _gate;

  Future<bool> contribute({
    required CartItem item,
    required Mercado market,
  }) async {
    if (!market.isRemoto || !_gate()) return false;

    try {
      final submitter = _submitter;
      if (submitter != null) {
        return await submitter(item: item, marketId: market.id);
      }
      return await PriceValidationService().submitCommunityPrice(
        item: item,
        storeId: market.id,
        price: item.unitPrice,
        quantity: item.isByWeight ? item.weightKg : item.quantity.toDouble(),
        unit: item.isByWeight ? 'kg' : item.unit,
      );
    } catch (error) {
      debugPrint('[SomaAí] Contribuição comunitária ignorada: $error');
      return false;
    }
  }

  static bool _defaultGate() {
    try {
      return SupabaseService.isReady && SupabaseService.currentUser != null;
    } catch (_) {
      return false;
    }
  }
}

final communityContributionServiceProvider =
    Provider<CommunityContributionService>((ref) {
  return CommunityContributionService();
});
