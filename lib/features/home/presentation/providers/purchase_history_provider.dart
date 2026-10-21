import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/models/purchase.dart';
import '../../data/demo_purchases.dart';
import '../../domain/purchase_history_sync_service.dart';

/// Histórico de compras persistido localmente (SharedPreferences).
///
/// No primeiro arranque semeia dados de demonstração para o Dashboard não
/// nascer vazio. O utilizador pode limpar tudo na aba Perfil.
class PurchaseHistoryNotifier extends StateNotifier<List<Purchase>> {
  PurchaseHistoryNotifier({PurchaseHistorySyncService? syncService})
      : _syncService = syncService ?? PurchaseHistorySyncService(),
        super(const []) {
    _load();
  }

  static const storageKey = 'somaai.purchase_history.v1';

  final PurchaseHistorySyncService _syncService;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);

      if (raw == null) {
        state = DemoPurchases.build();
        await _persist();
      } else {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          state = decoded
              .whereType<Map<String, dynamic>>()
              .map(Purchase.fromJson)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
        }
      }
    } catch (e, stack) {
      // Ambiente de teste/sem plugin: mantém os dados de demonstração em memória.
      debugPrint('[SomaAí] Histórico indisponível: $e');
      debugPrintStack(stackTrace: stack);
      if (state.isEmpty) state = DemoPurchases.build();
    } finally {
      if (mounted) {
        _loaded = true;
      }
    }
  }

  Future<void> addPurchase(Purchase purchase) async {
    state = [purchase, ...state]..sort((a, b) => b.date.compareTo(a.date));
    await _persist();
  }

  /// Atualiza a compra local imediatamente e tenta espelhar no Supabase.
  ///
  /// A fonte de verdade continua sendo o dispositivo: mesmo sem sessão/rede o
  /// Dashboard e o total do mês refletem a edição na hora.
  Future<PurchaseMutationResult> updatePurchase(Purchase purchase) async {
    final index = state.indexWhere((item) => item.id == purchase.id);
    if (index < 0) {
      return const PurchaseMutationResult(
        PurchaseMutationStatus.skippedLocalOnly,
      );
    }

    final updated = [...state];
    updated[index] = purchase;
    updated.sort((a, b) => b.date.compareTo(a.date));
    state = updated;
    await _persist();

    return _syncService.update(purchase);
  }

  /// Remove localmente e depois tenta apagar no Supabase.
  ///
  /// O retorno permite que a UI avise quando a nuvem ficou pendente, sem
  /// reintroduzir a compra na lista (o utilizador já confirmou a exclusão).
  Future<PurchaseMutationResult> removePurchase(String id) async {
    final existed = state.any((purchase) => purchase.id == id);
    if (!existed) {
      return const PurchaseMutationResult(
        PurchaseMutationStatus.skippedLocalOnly,
      );
    }

    state = state.where((purchase) => purchase.id != id).toList();
    await _persist();

    return _syncService.delete(id);
  }

  Future<void> clearHistory() async {
    state = const [];
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(state.map((p) => p.toJson()).toList());
      await prefs.setString(storageKey, raw);
    } catch (e) {
      debugPrint('[SomaAí] Não foi possível salvar o histórico: $e');
    }
  }
}

final purchaseHistoryProvider =
    StateNotifierProvider<PurchaseHistoryNotifier, List<Purchase>>((ref) {
  return PurchaseHistoryNotifier(
    syncService: ref.watch(purchaseHistorySyncServiceProvider),
  );
});

/// Compra atualizada por id, usada pela tela de detalhes após uma edição.
final purchaseByIdProvider = Provider.family<Purchase?, String>((ref, id) {
  for (final purchase in ref.watch(purchaseHistoryProvider)) {
    if (purchase.id == id) return purchase;
  }
  return null;
});

/// Compras do mês corrente.
final monthlyPurchasesProvider = Provider<List<Purchase>>((ref) {
  final now = DateTime.now();
  return ref.watch(purchaseHistoryProvider).where((p) {
    return p.date.year == now.year && p.date.month == now.month;
  }).toList();
});

/// Total gasto no mês corrente.
final monthlySpendingProvider = Provider<double>((ref) {
  return ref
      .watch(monthlyPurchasesProvider)
      .fold(0.0, (sum, purchase) => sum + purchase.total);
});

/// Total economizado no mês corrente (somatório dos alertas).
final monthlySavingsProvider = Provider<double>((ref) {
  return ref
      .watch(monthlyPurchasesProvider)
      .fold(0.0, (sum, purchase) => sum + purchase.savings);
});

/// Compras mais recentes para o Dashboard.
final recentPurchasesProvider = Provider<List<Purchase>>((ref) {
  final all = ref.watch(purchaseHistoryProvider);
  return all.take(4).toList();
});

/// Total gasto de sempre (usado no Perfil).
final lifetimeSpendingProvider = Provider<double>((ref) {
  return ref
      .watch(purchaseHistoryProvider)
      .fold(0.0, (sum, purchase) => sum + purchase.total);
});

/// Total economizado de sempre (usado no Perfil).
final lifetimeSavingsProvider = Provider<double>((ref) {
  return ref
      .watch(purchaseHistoryProvider)
      .fold(0.0, (sum, purchase) => sum + purchase.savings);
});
