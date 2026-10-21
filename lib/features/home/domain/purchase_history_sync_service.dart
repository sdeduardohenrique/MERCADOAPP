import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/purchase.dart';
import '../../../core/services/supabase_service.dart';

/// Resultado do espelhamento de uma edição/exclusão no Supabase.
///
/// O histórico local é sempre atualizado antes. Este resultado serve apenas
/// para a UI informar com honestidade se a nuvem também foi atualizada.
enum PurchaseMutationStatus {
  synced,
  skippedOffline,
  skippedUnauthenticated,
  skippedLocalOnly,
  failed,
}

class PurchaseMutationResult {
  final PurchaseMutationStatus status;
  final Object? error;

  const PurchaseMutationResult(this.status, {this.error});

  bool get isSynced => status == PurchaseMutationStatus.synced;

  bool get isPending =>
      status == PurchaseMutationStatus.skippedOffline ||
      status == PurchaseMutationStatus.skippedUnauthenticated ||
      status == PurchaseMutationStatus.skippedLocalOnly;

  bool get hasFailed => status == PurchaseMutationStatus.failed;
}

typedef RemotePurchaseUpdater = Future<void> Function(Purchase purchase);
typedef RemotePurchaseDeleter = Future<void> Function(String id);
typedef PurchaseMutationSyncGate = PurchaseMutationStatus? Function();

/// Coordena edição/exclusão local-first do histórico.
///
/// Nenhum método lança: uma falha de rede não pode impedir o utilizador de
/// corrigir uma compra no dispositivo.
class PurchaseHistorySyncService {
  PurchaseHistorySyncService({
    RemotePurchaseUpdater? remoteUpdater,
    RemotePurchaseDeleter? remoteDeleter,
    PurchaseMutationSyncGate? syncGate,
  })  : _remoteUpdater = remoteUpdater ?? SupabaseService.updatePurchase,
        _remoteDeleter = remoteDeleter ?? SupabaseService.deletePurchase,
        _syncGate = syncGate ?? _defaultSyncGate;

  final RemotePurchaseUpdater _remoteUpdater;
  final RemotePurchaseDeleter _remoteDeleter;
  final PurchaseMutationSyncGate _syncGate;

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<PurchaseMutationResult> update(Purchase purchase) async {
    if (!_uuidPattern.hasMatch(purchase.id)) {
      return const PurchaseMutationResult(
        PurchaseMutationStatus.skippedLocalOnly,
      );
    }

    final blocked = _syncGate();
    if (blocked != null) return PurchaseMutationResult(blocked);

    try {
      await _remoteUpdater(purchase);
      return const PurchaseMutationResult(PurchaseMutationStatus.synced);
    } catch (error) {
      return PurchaseMutationResult(
        PurchaseMutationStatus.failed,
        error: error,
      );
    }
  }

  Future<PurchaseMutationResult> delete(String id) async {
    if (!_uuidPattern.hasMatch(id)) {
      return const PurchaseMutationResult(
        PurchaseMutationStatus.skippedLocalOnly,
      );
    }

    final blocked = _syncGate();
    if (blocked != null) return PurchaseMutationResult(blocked);

    try {
      await _remoteDeleter(id);
      return const PurchaseMutationResult(PurchaseMutationStatus.synced);
    } catch (error) {
      return PurchaseMutationResult(
        PurchaseMutationStatus.failed,
        error: error,
      );
    }
  }

  static PurchaseMutationStatus? _defaultSyncGate() {
    if (!SupabaseService.isReady) {
      return PurchaseMutationStatus.skippedOffline;
    }
    if (SupabaseService.currentUser == null) {
      return PurchaseMutationStatus.skippedUnauthenticated;
    }
    return null;
  }
}

final purchaseHistorySyncServiceProvider =
    Provider<PurchaseHistorySyncService>((ref) {
  return PurchaseHistorySyncService();
});
