import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/models/purchase.dart';
import '../../data/demo_purchases.dart';

/// Histórico de compras persistido localmente (SharedPreferences).
///
/// No primeiro arranque semeia dados de demonstração para o Dashboard não
/// nascer vazio. O utilizador pode limpar tudo na aba Perfil.
class PurchaseHistoryNotifier extends StateNotifier<List<Purchase>> {
  PurchaseHistoryNotifier() : super(const []) {
    _load();
  }

  static const storageKey = 'somaai.purchase_history.v1';

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
      _loaded = true;
    }
  }

  Future<void> addPurchase(Purchase purchase) async {
    state = [purchase, ...state]..sort((a, b) => b.date.compareTo(a.date));
    await _persist();
  }

  Future<void> removePurchase(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _persist();
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
  return PurchaseHistoryNotifier();
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
