import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/cart_item.dart';

/// Cart state notifier
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  /// Adds item to cart, merging if same EAN exists
  void addItem(CartItem item) {
    if (item.ean != null && item.ean!.isNotEmpty) {
      final existingIndex = state.indexWhere(
        (i) => i.ean == item.ean && i.ean != null,
      );
      if (existingIndex >= 0) {
        final existing = state[existingIndex];
        state = [
          ...state.sublist(0, existingIndex),
          existing.copyWith(
            quantity: existing.quantity + item.quantity,
            totalPrice: (existing.quantity + item.quantity) * existing.unitPrice,
            addedAt: DateTime.now(), // Update timestamp
          ),
          ...state.sublist(existingIndex + 1),
        ];
        return;
      }
    }
    state = [...state, item];
  }

  /// Removes item from cart
  void removeItem(String id) {
    state = state.where((i) => i.id != id).toList();
  }

  /// Updates item quantity
  void updateQuantity(String id, int quantity) {
    if (quantity <= 0) {
      removeItem(id);
      return;
    }
    state = state.map((i) {
      if (i.id == id) {
        return i.copyWith(
          quantity: quantity,
          totalPrice: i.unitPrice * quantity,
        );
      }
      return i;
    }).toList();
  }

  /// Increments item quantity
  void incrementQuantity(String id) {
    final index = state.indexWhere((i) => i.id == id);
    if (index >= 0) {
      final item = state[index];
      updateQuantity(id, item.quantity + 1);
    }
  }

  /// Decrements item quantity
  void decrementQuantity(String id) {
    final index = state.indexWhere((i) => i.id == id);
    if (index >= 0) {
      final item = state[index];
      updateQuantity(id, item.quantity - 1);
    }
  }

  /// Clears entire cart
  void clear() => state = [];

  /// Gets total price
  double get totalPrice => state.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Gets total item count
  int get totalItems => state.fold(0, (sum, item) => sum + item.quantity);

  /// Gets unique item count
  int get uniqueItems => state.length;

  /// Checks if cart is empty
  bool get isEmpty => state.isEmpty;
}

/// Cart provider
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

/// Derived providers for cart totals
final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.totalPrice);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});