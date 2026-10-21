import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soma_ai/core/models/purchase.dart';
import 'package:soma_ai/features/home/domain/purchase_history_sync_service.dart';
import 'package:soma_ai/features/home/presentation/providers/dashboard_period_provider.dart';
import 'package:soma_ai/features/home/presentation/providers/purchase_history_provider.dart';

const _idPrefix = '00000000-0000-4000-8000-00000000000';

Purchase _purchase({
  required int index,
  required DateTime date,
  required double total,
  required double savings,
}) {
  return Purchase(
    id: '$_idPrefix$index',
    storeName: 'Mercado $index',
    date: date,
    savings: savings,
    items: [
      PurchaseItem(name: 'Item $index', unitPrice: total, quantity: 1),
    ],
  );
}

Future<ProviderContainer> _container(List<Purchase> purchases) async {
  SharedPreferences.setMockInitialValues({
    PurchaseHistoryNotifier.storageKey:
        jsonEncode(purchases.map((purchase) => purchase.toJson()).toList()),
  });

  final container = ProviderContainer(
    overrides: [
      purchaseHistorySyncServiceProvider.overrideWithValue(
        PurchaseHistorySyncService(
          syncGate: () => null,
          remoteUpdater: (_) async {},
          remoteDeleter: (_) async {},
        ),
      ),
    ],
  );

  final notifier = container.read(purchaseHistoryProvider.notifier);
  for (var i = 0; i < 50 && !notifier.isLoaded; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return container;
}

void main() {
  test('filtra gastos e economia por mês, trimestre, ano e período custom',
      () async {
    final now = DateTime.now();
    final current = _purchase(
      index: 1,
      date: DateTime(now.year, now.month, 1),
      total: 10,
      savings: 1,
    );
    final oneMonthAgoDate = DateTime(now.year, now.month - 1, 1);
    final twoMonthsAgoDate = DateTime(now.year, now.month - 2, 1);
    final oneMonthAgo = _purchase(
      index: 2,
      date: oneMonthAgoDate,
      total: 20,
      savings: 2,
    );
    final twoMonthsAgo = _purchase(
      index: 3,
      date: twoMonthsAgoDate,
      total: 30,
      savings: 3,
    );
    final lastYear = _purchase(
      index: 4,
      date: DateTime(now.year - 1, 6, 1),
      total: 40,
      savings: 4,
    );

    final container = await _container([
      current,
      oneMonthAgo,
      twoMonthsAgo,
      lastYear,
    ]);
    addTearDown(container.dispose);

    expect(container.read(dashboardPeriodProvider).period,
        DashboardPeriod.thisMonth);
    expect(container.read(periodSpendingProvider), 10);
    expect(container.read(periodSavingsProvider), 1);
    expect(
        container.read(periodPurchasesProvider), [_purchaseMatcher(current)]);

    container
        .read(dashboardPeriodProvider.notifier)
        .select(DashboardPeriod.lastThreeMonths);
    expect(container.read(periodSpendingProvider), 60);
    expect(container.read(periodSavingsProvider), 6);
    expect(container.read(periodPurchasesProvider).length, 3);

    container
        .read(dashboardPeriodProvider.notifier)
        .select(DashboardPeriod.thisYear);
    final expectedYear = 10 +
        (oneMonthAgoDate.year == now.year ? 20 : 0) +
        (twoMonthsAgoDate.year == now.year ? 30 : 0);
    expect(container.read(periodSpendingProvider), expectedYear);

    container.read(dashboardPeriodProvider.notifier).selectCustom(
          DateTimeRange(
            start: DateTime(
              oneMonthAgoDate.year,
              oneMonthAgoDate.month,
              1,
            ),
            end: DateTime(
              oneMonthAgoDate.year,
              oneMonthAgoDate.month + 1,
              0,
            ),
          ),
        );
    expect(
        container.read(dashboardPeriodProvider).period, DashboardPeriod.custom);
    expect(container.read(periodSpendingProvider), 20);
    expect(container.read(periodSavingsProvider), 2);
    expect(container.read(periodPurchasesProvider).length, 1);
  });
}

Matcher _purchaseMatcher(Purchase purchase) {
  return isA<Purchase>()
      .having((value) => value.id, 'id', purchase.id)
      .having((value) => value.total, 'total', purchase.total);
}
