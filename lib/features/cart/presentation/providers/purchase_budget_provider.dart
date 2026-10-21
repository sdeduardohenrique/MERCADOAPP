import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Optional spending ceiling for the purchase currently in progress.
///
/// The cart itself stays independent from the budget: clearing/replacing items
/// only changes the comparison, never the limit. The cart screen clears it when
/// a purchase is finalized or abandoned.
class PurchaseBudgetNotifier extends StateNotifier<double?> {
  PurchaseBudgetNotifier() : super(null);

  void setBudget(double? value) {
    if (value == null || value <= 0) {
      state = null;
      return;
    }
    state = double.parse(value.toStringAsFixed(2));
  }

  void clear() => state = null;
}

final purchaseBudgetProvider =
    StateNotifierProvider<PurchaseBudgetNotifier, double?>((ref) {
  return PurchaseBudgetNotifier();
});
