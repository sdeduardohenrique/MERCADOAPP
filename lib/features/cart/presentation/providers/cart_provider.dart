import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/cart_item.dart';
import '../../../shopping_list/presentation/providers/shopping_lists_provider.dart';

/// Cart state notifier
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier({Ref? ref})
      : _ref = ref,
        super([]);

  final Ref? _ref;

  /// Adds item to cart, merging when the same EAN, pricing mode and price
  /// match. Different prices stay as separate lines so the receipt is honest.
  ///
  /// Depois de inserir, tenta riscar automaticamente o item correspondente
  /// na lista ativa da compra (quando o provider está disponível).
  void addItem(CartItem item) {
    if (item.ean != null && item.ean!.isNotEmpty) {
      final existingIndex = state.indexWhere(
        (i) =>
            i.ean == item.ean &&
            i.kind == item.kind &&
            (i.unitPrice - item.unitPrice).abs() < 0.005,
      );
      if (existingIndex >= 0) {
        final existing = state[existingIndex];
        final merged = item.isByWeight
            ? existing.copyWith(
                weightKg: existing.weightKg + item.weightKg,
                photoPath: existing.photoPath ?? item.photoPath,
                addedAt: DateTime.now(),
              )
            : existing.copyWith(
                quantity: existing.quantity + item.quantity,
                photoPath: existing.photoPath ?? item.photoPath,
                addedAt: DateTime.now(),
              );
        state = [
          ...state.sublist(0, existingIndex),
          merged.withCalculatedTotal(),
          ...state.sublist(existingIndex + 1),
        ];
        _markActiveShoppingList(merged.name);
        return;
      }
    }
    state = [...state, item.withCalculatedTotal()];
    _markActiveShoppingList(item.name);
  }

  void _markActiveShoppingList(String productName) {
    final ref = _ref;
    if (ref == null) return;

    unawaited(
      ref
          .read(shoppingListsProvider.notifier)
          .markBoughtMatching(productName)
          .catchError((Object error) {
        debugPrint('[SomaAí] Não foi possível riscar a lista ativa: $error');
        return null;
      }),
    );
  }

  /// Removes item from cart
  void removeItem(String id) {
    state = state.where((i) => i.id != id).toList();
  }

  /// Replaces an item after the edit sheet, keeping the same position.
  void updateItem(CartItem item) {
    final index = state.indexWhere((i) => i.id == item.id);
    if (index < 0) return;

    state = [
      ...state.sublist(0, index),
      item.withCalculatedTotal(),
      ...state.sublist(index + 1),
    ];
  }

  /// Updates item quantity (unit-priced items only).
  void updateQuantity(String id, int quantity) {
    if (quantity <= 0) {
      removeItem(id);
      return;
    }
    state = state.map((i) {
      if (i.id == id && !i.isByWeight) {
        return i
            .copyWith(
              quantity: quantity,
            )
            .withCalculatedTotal();
      }
      return i;
    }).toList();
  }

  /// Updates the weight of a per-kilogram item.
  void updateWeight(String id, double weightKg) {
    final safeWeight =
        double.parse(weightKg.clamp(0.01, 100).toStringAsFixed(3));
    state = state.map((i) {
      if (i.id == id && i.isByWeight) {
        return i
            .copyWith(
              weightKg: safeWeight,
              quantity: 1,
            )
            .withCalculatedTotal();
      }
      return i;
    }).toList();
  }

  /// Increments quantity for unit items or 100 g for weighted items.
  void incrementQuantity(String id) {
    final index = state.indexWhere((i) => i.id == id);
    if (index < 0) return;

    final item = state[index];
    if (item.isByWeight) {
      updateWeight(id, item.weightKg + 0.1);
    } else {
      updateQuantity(id, item.quantity + 1);
    }
  }

  /// Decrements quantity for unit items or 100 g for weighted items.
  void decrementQuantity(String id) {
    final index = state.indexWhere((i) => i.id == id);
    if (index < 0) return;

    final item = state[index];
    if (item.isByWeight) {
      updateWeight(id, item.weightKg - 0.1);
    } else {
      updateQuantity(id, item.quantity - 1);
    }
  }

  /// Clears entire cart
  void clear() => state = [];

  /// Gets total price
  double get totalPrice =>
      state.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Gets total item count. A weighted line counts as one entry.
  int get totalItems => state.fold(0, (sum, item) => sum + item.itemCount);

  /// Gets unique item count
  int get uniqueItems => state.length;

  /// Checks if cart is empty
  bool get isEmpty => state.isEmpty;
}

/// Cart provider
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier(ref: ref);
});

/// Derived providers for cart totals
final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.totalPrice);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.itemCount);
});
