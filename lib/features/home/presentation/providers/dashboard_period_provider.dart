import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/purchase.dart';
import '../../../../core/utils/formatters.dart';
import 'purchase_history_provider.dart';

/// Períodos disponíveis no resumo financeiro do Dashboard.
enum DashboardPeriod {
  thisMonth,
  lastThreeMonths,
  thisYear,
  custom,
}

/// Filtro selecionado. Guarda o intervalo personalizado para que a escolha
/// continue visível ao navegar entre abas.
@immutable
class DashboardPeriodFilter {
  final DashboardPeriod period;
  final DateTimeRange? customRange;

  const DashboardPeriodFilter({
    this.period = DashboardPeriod.thisMonth,
    this.customRange,
  });

  /// Intervalo inclusivo (o último dia inteiro faz parte do filtro).
  DateTimeRange get effectiveRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case DashboardPeriod.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0),
        );
      case DashboardPeriod.lastThreeMonths:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: today,
        );
      case DashboardPeriod.thisYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: today,
        );
      case DashboardPeriod.custom:
        final custom = customRange;
        if (custom != null) {
          return DateTimeRange(
            start: DateTime(
                custom.start.year, custom.start.month, custom.start.day),
            end: DateTime(custom.end.year, custom.end.month, custom.end.day),
          );
        }
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: today,
        );
    }
  }

  bool contains(DateTime date) {
    final range = effectiveRange;
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  String get shortLabel {
    switch (period) {
      case DashboardPeriod.thisMonth:
        return 'Este mês';
      case DashboardPeriod.lastThreeMonths:
        return 'Últimos 3 meses';
      case DashboardPeriod.thisYear:
        return 'Este ano';
      case DashboardPeriod.custom:
        final range = effectiveRange;
        return '${_shortDate(range.start)} a ${_shortDate(range.end)}';
    }
  }

  /// Rótulo curto usado no card de gastos.
  String get spendingLabel {
    switch (period) {
      case DashboardPeriod.thisMonth:
        return 'Gastos em ${Formatters.monthName(DateTime.now())}';
      case DashboardPeriod.lastThreeMonths:
        return 'Gastos em 3 meses';
      case DashboardPeriod.thisYear:
        return 'Gastos no ano';
      case DashboardPeriod.custom:
        return 'Gastos no período';
    }
  }

  static String _shortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  DashboardPeriodFilter copyWith({
    DashboardPeriod? period,
    DateTimeRange? customRange,
  }) {
    return DashboardPeriodFilter(
      period: period ?? this.period,
      customRange: customRange ?? this.customRange,
    );
  }
}

class DashboardPeriodNotifier extends StateNotifier<DashboardPeriodFilter> {
  DashboardPeriodNotifier() : super(const DashboardPeriodFilter());

  void select(DashboardPeriod period) {
    if (period == DashboardPeriod.custom) return;
    state = DashboardPeriodFilter(period: period);
  }

  void selectCustom(DateTimeRange range) {
    final normalized = DateTimeRange(
      start: DateTime(range.start.year, range.start.month, range.start.day),
      end: DateTime(range.end.year, range.end.month, range.end.day),
    );
    state = DashboardPeriodFilter(
      period: DashboardPeriod.custom,
      customRange: normalized,
    );
  }

  void reset() => state = const DashboardPeriodFilter();
}

final dashboardPeriodProvider =
    StateNotifierProvider<DashboardPeriodNotifier, DashboardPeriodFilter>(
        (ref) {
  return DashboardPeriodNotifier();
});

final selectedPeriodRangeProvider = Provider<DateTimeRange>((ref) {
  return ref.watch(dashboardPeriodProvider).effectiveRange;
});

/// Compras do histórico dentro do período selecionado.
final periodPurchasesProvider = Provider<List<Purchase>>((ref) {
  final filter = ref.watch(dashboardPeriodProvider);
  return ref
      .watch(purchaseHistoryProvider)
      .where((purchase) => filter.contains(purchase.date))
      .toList();
});

final periodSpendingProvider = Provider<double>((ref) {
  return ref
      .watch(periodPurchasesProvider)
      .fold(0.0, (sum, purchase) => sum + purchase.total);
});

final periodSavingsProvider = Provider<double>((ref) {
  return ref
      .watch(periodPurchasesProvider)
      .fold(0.0, (sum, purchase) => sum + purchase.savings);
});
