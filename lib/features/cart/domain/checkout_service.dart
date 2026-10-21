import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/purchase.dart';
import '../../../core/services/supabase_service.dart';

/// Resultado da tentativa de espelhar uma compra no Supabase.
///
/// A compra local é sempre a fonte de verdade. O estado remoto serve apenas
/// para sincronização e para alimentar o total do mês quando há sessão.
enum CheckoutSyncStatus {
  synced,
  skippedOffline,
  skippedUnauthenticated,
  failed,
}

class CheckoutSyncResult {
  final CheckoutSyncStatus status;
  final Object? error;

  const CheckoutSyncResult(this.status, {this.error});

  bool get isSynced => status == CheckoutSyncStatus.synced;

  bool get isPending =>
      status == CheckoutSyncStatus.skippedOffline ||
      status == CheckoutSyncStatus.skippedUnauthenticated ||
      status == CheckoutSyncStatus.failed;
}

typedef RemotePurchaseSaver = Future<void> Function(Purchase purchase);
typedef CheckoutSyncGate = CheckoutSyncStatus? Function();

/// Coordena o "commit" de uma compra já criada pelo carrinho.
///
/// A UI grava primeiro no histórico local (SharedPreferences). Depois chama
/// [sync], que nunca lança: falhas de rede/sessão não podem impedir o utilizador
/// de finalizar a compra.
class CheckoutService {
  CheckoutService({
    RemotePurchaseSaver? remoteSaver,
    CheckoutSyncGate? syncGate,
  })  : _remoteSaver = remoteSaver ?? SupabaseService.savePurchase,
        _syncGate = syncGate ?? _defaultSyncGate;

  final RemotePurchaseSaver _remoteSaver;
  final CheckoutSyncGate _syncGate;

  Future<CheckoutSyncResult> sync(Purchase purchase) async {
    final blocked = _syncGate();
    if (blocked != null) return CheckoutSyncResult(blocked);

    try {
      await _remoteSaver(purchase);
      return const CheckoutSyncResult(CheckoutSyncStatus.synced);
    } catch (error) {
      return CheckoutSyncResult(CheckoutSyncStatus.failed, error: error);
    }
  }

  static CheckoutSyncStatus? _defaultSyncGate() {
    if (!SupabaseService.isReady) {
      return CheckoutSyncStatus.skippedOffline;
    }
    if (SupabaseService.currentUser == null) {
      return CheckoutSyncStatus.skippedUnauthenticated;
    }
    return null;
  }
}

final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  return CheckoutService();
});
