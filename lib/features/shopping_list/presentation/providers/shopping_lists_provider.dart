import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/shopping_lists_service.dart';
import '../../domain/shopping_list.dart';
import '../../domain/shopping_list_matcher.dart';
import '../../domain/shopping_sector.dart';

final shoppingListsServiceProvider = Provider<ShoppingListsService>((ref) {
  return const ShoppingListsService();
});

/// Lista ativa durante a compra. É definida ao tocar em
/// "Iniciar Compra no Mercado" e limpa ao finalizar/limpar o carrinho.
class ActiveShoppingListNotifier extends StateNotifier<String?> {
  ActiveShoppingListNotifier() : super(null);

  void select(String listId) => state = listId;

  void clear() => state = null;
}

final activeShoppingListIdProvider =
    StateNotifierProvider<ActiveShoppingListNotifier, String?>(
  (ref) => ActiveShoppingListNotifier(),
);

/// Listas e itens, local-first.
final shoppingListsProvider =
    AsyncNotifierProvider<ShoppingListsNotifier, List<ShoppingList>>(
  ShoppingListsNotifier.new,
);

class ShoppingListsNotifier extends AsyncNotifier<List<ShoppingList>> {
  String? _userId;
  int _buildGeneration = 0;
  int _mutationRevision = 0;
  bool _disposed = false;

  // Serializa gravações locais e remotas para que uma reconciliação antiga
  // nunca termine depois de uma mutação mais nova.
  Future<void> _localPersist = Future<void>.value();
  Future<void> _remoteSync = Future<void>.value();

  ShoppingListsService get _service => ref.read(shoppingListsServiceProvider);

  @override
  Future<List<ShoppingList>> build() async {
    _disposed = false;
    final generation = ++_buildGeneration;
    ref.onDispose(() => _disposed = true);

    final isGuest = ref.watch(isGuestProvider);
    final userId = isGuest ? null : SupabaseService.currentUser?.id;
    _userId = userId;

    final local = await _service.loadLocal(userId: userId);

    if (userId != null) {
      unawaited(_reconcileRemote(userId, local, generation));
    }

    return local;
  }

  Future<void> _reconcileRemote(
    String userId,
    List<ShoppingList> local,
    int generation,
  ) async {
    final revision = _mutationRevision;
    try {
      final remote = await _service.fetchRemote(userId);
      if (_disposed ||
          generation != _buildGeneration ||
          revision != _mutationRevision) {
        return;
      }

      final localById = {for (final list in local) list.id: list};
      final remoteById = {for (final list in remote) list.id: list};
      final ids = {...localById.keys, ...remoteById.keys};
      final merged = <String, ShoppingList>{};
      final listsToUpsert = <ShoppingList>[];
      final itemsToUpsert = <ShoppingListItem>[];

      for (final id in ids) {
        final localList = localById[id];
        final remoteList = remoteById[id];

        if (localList == null) {
          merged[id] = remoteList!;
          continue;
        }
        if (remoteList == null) {
          merged[id] = localList;
          listsToUpsert.add(localList);
          itemsToUpsert.addAll(localList.items);
          continue;
        }

        final localNewer = localList.updatedAt.isAfter(remoteList.updatedAt);
        final base = localNewer ? localList : remoteList;
        final localItems = {for (final item in localList.items) item.id: item};
        final remoteItems = {
          for (final item in remoteList.items) item.id: item
        };
        final itemIds = {...localItems.keys, ...remoteItems.keys};
        final items = <ShoppingListItem>[];

        for (final itemId in itemIds) {
          final localItem = localItems[itemId];
          final remoteItem = remoteItems[itemId];
          if (localItem == null) {
            items.add(remoteItem!);
            continue;
          }
          if (remoteItem == null) {
            items.add(localItem);
            itemsToUpsert.add(localItem);
            continue;
          }
          if (localItem.updatedAt.isAfter(remoteItem.updatedAt)) {
            items.add(localItem);
            itemsToUpsert.add(localItem);
          } else {
            items.add(remoteItem);
          }
        }
        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        final mergedList = base.copyWith(items: items);
        merged[id] = mergedList;
        if (localNewer) listsToUpsert.add(mergedList);
      }

      final result = merged.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (_disposed ||
          generation != _buildGeneration ||
          revision != _mutationRevision) {
        return;
      }
      await _persist(result);

      for (final list in listsToUpsert) {
        if (revision != _mutationRevision) break;
        await _enqueueRemote(() => _service.upsertList(list, userId));
      }
      for (final item in itemsToUpsert) {
        if (revision != _mutationRevision) break;
        await _enqueueRemote(() => _service.upsertItem(item, userId));
      }

      if (_disposed ||
          generation != _buildGeneration ||
          revision != _mutationRevision) {
        return;
      }
      state = AsyncData(result);
    } catch (error) {
      // Sem rede o cache local continua sendo a fonte de verdade.
      debugPrint('[SomaAí] Listas remotas indisponíveis: $error');
    }
  }

  Future<ShoppingList?> createList(
    String rawName, {
    String icon = '🛒',
  }) async {
    final name = rawName.trim();
    if (name.isEmpty) return null;

    final current = state.valueOrNull;
    if (current == null) return null;

    final now = DateTime.now().toUtc();
    final list = ShoppingList(
      id: const Uuid().v4(),
      name: name,
      icon: normalizeShoppingListIcon(icon),
      createdAt: now,
      updatedAt: now,
    );
    final updated = [...current, list]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    await _commit(updated);
    await _syncList(list);
    return list;
  }

  Future<ShoppingList?> updateList(
    String id, {
    String? name,
    String? icon,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return null;

    final index = current.indexWhere((list) => list.id == id);
    if (index < 0) return null;

    final trimmed = name?.trim();
    final changed = current[index].copyWith(
      name: trimmed != null && trimmed.isNotEmpty ? trimmed : null,
      icon: icon == null ? null : normalizeShoppingListIcon(icon),
      updatedAt: DateTime.now().toUtc(),
    );
    final updated = [...current]..[index] = changed;

    await _commit(updated);
    await _syncList(changed);
    return changed;
  }

  Future<void> deleteList(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.where((list) => list.id != id).toList();
    if (updated.length == current.length) return;

    await _commit(updated);
    if (ref.read(activeShoppingListIdProvider) == id) {
      ref.read(activeShoppingListIdProvider.notifier).clear();
    }
    await _syncDeleteList(id);
  }

  Future<ShoppingListItem?> addItem(
    String listId, {
    required String name,
    double quantity = 1,
    String unit = 'un',
    double? estimatedPrice,
    ShoppingSector? sector,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return null;

    final index = current.indexWhere((list) => list.id == listId);
    if (index < 0) return null;

    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final now = DateTime.now().toUtc();
    final item = ShoppingListItem(
      id: const Uuid().v4(),
      listId: listId,
      name: trimmed,
      quantity: quantity > 0 ? quantity : 1,
      unit: normalizeShoppingUnit(unit),
      estimatedPrice:
          estimatedPrice != null && estimatedPrice >= 0 ? estimatedPrice : null,
      sector: sector ?? ShoppingSector.categorize(trimmed),
      createdAt: now,
      updatedAt: now,
    );

    final items = [...current[index].items, item]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final changed = current[index].copyWith(items: items, updatedAt: now);
    final updated = [...current]..[index] = changed;

    await _commit(updated);
    await _syncList(changed);
    await _syncItem(item);
    return item;
  }

  Future<ShoppingListItem?> updateItem(
    String listId,
    ShoppingListItem item,
  ) async {
    final current = state.valueOrNull;
    if (current == null) return null;

    final listIndex = current.indexWhere((list) => list.id == listId);
    if (listIndex < 0) return null;

    final itemIndex =
        current[listIndex].items.indexWhere((entry) => entry.id == item.id);
    if (itemIndex < 0) return null;

    final now = DateTime.now().toUtc();
    final changed = item.copyWith(
      listId: listId,
      quantity: item.quantity > 0 ? item.quantity : 1,
      unit: normalizeShoppingUnit(item.unit),
      estimatedPrice: item.estimatedPrice,
      sector: item.sector,
      updatedAt: now,
    );
    final items = [...current[listIndex].items]..[itemIndex] = changed;
    final changedList =
        current[listIndex].copyWith(items: items, updatedAt: now);
    final updated = [...current]..[listIndex] = changedList;

    await _commit(updated);
    await _syncList(changedList);
    await _syncItem(changed);
    return changed;
  }

  Future<ShoppingListItem?> toggleItem(String listId, String itemId) async {
    final current = state.valueOrNull;
    if (current == null) return null;

    final listIndex = current.indexWhere((list) => list.id == listId);
    if (listIndex < 0) return null;

    final itemIndex =
        current[listIndex].items.indexWhere((item) => item.id == itemId);
    if (itemIndex < 0) return null;

    final now = DateTime.now().toUtc();
    final changed = current[listIndex].items[itemIndex].copyWith(
          isBought: !current[listIndex].items[itemIndex].isBought,
          updatedAt: now,
        );
    final items = [...current[listIndex].items]..[itemIndex] = changed;
    final changedList =
        current[listIndex].copyWith(items: items, updatedAt: now);
    final updated = [...current]..[listIndex] = changedList;

    await _commit(updated);
    await _syncList(changedList);
    await _syncItem(changed);
    return changed;
  }

  Future<void> removeItem(String listId, String itemId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final listIndex = current.indexWhere((list) => list.id == listId);
    if (listIndex < 0) return;

    final items =
        current[listIndex].items.where((item) => item.id != itemId).toList();
    if (items.length == current[listIndex].items.length) return;

    final now = DateTime.now().toUtc();
    final changedList =
        current[listIndex].copyWith(items: items, updatedAt: now);
    final updated = [...current]..[listIndex] = changedList;

    await _commit(updated);
    await _syncList(changedList);
    await _syncDeleteItem(itemId);
  }

  Future<void> clearBought(String listId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final listIndex = current.indexWhere((list) => list.id == listId);
    if (listIndex < 0) return;

    final removed =
        current[listIndex].items.where((item) => item.isBought).toList();
    if (removed.isEmpty) return;

    final items =
        current[listIndex].items.where((item) => !item.isBought).toList();
    final now = DateTime.now().toUtc();
    final changedList =
        current[listIndex].copyWith(items: items, updatedAt: now);
    final updated = [...current]..[listIndex] = changedList;

    await _commit(updated);
    await _syncList(changedList);
    for (final item in removed) {
      await _syncDeleteItem(item.id);
    }
  }

  /// Risca o item pendente mais parecido na lista ativa (ou em [listId]).
  Future<ShoppingListItem?> markBoughtMatching(
    String productName, {
    String? listId,
  }) async {
    final targetId = listId ?? ref.read(activeShoppingListIdProvider);
    if (targetId == null) return null;

    final current = state.valueOrNull;
    if (current == null) return null;

    final listIndex = current.indexWhere((list) => list.id == targetId);
    if (listIndex < 0) return null;

    final match = bestShoppingListItemMatch(
      productName,
      current[listIndex].items,
    );
    if (match == null) return null;

    final now = DateTime.now().toUtc();
    final changed = match.copyWith(isBought: true, updatedAt: now);
    final items = [...current[listIndex].items]
      ..[current[listIndex].items.indexWhere((item) => item.id == match.id)] =
          changed;
    final changedList =
        current[listIndex].copyWith(items: items, updatedAt: now);
    final updated = [...current]..[listIndex] = changedList;

    await _commit(updated);
    await _syncList(changedList);
    await _syncItem(changed);
    return changed;
  }

  Future<void> _commit(List<ShoppingList> lists) async {
    _mutationRevision++;
    state = AsyncData(lists);
    await _persist(lists);
  }

  Future<void> _persist(List<ShoppingList> lists) {
    final userId = _userId;
    final next = _localPersist.then(
      (_) => _service.saveLocal(lists, userId: userId),
    );
    _localPersist = next;
    return next;
  }

  Future<void> _syncList(ShoppingList list) {
    final userId = _userId;
    if (userId == null) return Future<void>.value();
    return _enqueueRemote(() => _service.upsertList(list, userId));
  }

  Future<void> _syncItem(ShoppingListItem item) {
    final userId = _userId;
    if (userId == null) return Future<void>.value();
    return _enqueueRemote(() => _service.upsertItem(item, userId));
  }

  Future<void> _syncDeleteList(String id) {
    final userId = _userId;
    if (userId == null) return Future<void>.value();
    return _enqueueRemote(() => _service.deleteList(id, userId));
  }

  Future<void> _syncDeleteItem(String id) {
    final userId = _userId;
    if (userId == null) return Future<void>.value();
    return _enqueueRemote(() => _service.deleteItem(id, userId));
  }

  Future<void> _enqueueRemote(Future<void> Function() task) {
    final next = _remoteSync.then((_) => task()).catchError((error) {
      debugPrint('[SomaAí] Listas: falha ao sincronizar: $error');
    });
    _remoteSync = next;
    return next;
  }
}

/// Lista correspondente ao id ativo, se ainda existir.
final activeShoppingListProvider = Provider<ShoppingList?>((ref) {
  final id = ref.watch(activeShoppingListIdProvider);
  if (id == null) return null;
  final lists = ref.watch(shoppingListsProvider).valueOrNull;
  if (lists == null) return null;
  for (final list in lists) {
    if (list.id == id) return list;
  }
  return null;
});

final shoppingListByIdProvider =
    Provider.family<ShoppingList?, String>((ref, id) {
  final lists = ref.watch(shoppingListsProvider).valueOrNull;
  if (lists == null) return null;
  for (final list in lists) {
    if (list.id == id) return list;
  }
  return null;
});

class ShoppingListsSummary {
  final int listCount;
  final int totalItems;
  final int pendingItems;
  final int boughtItems;
  final double estimatedTotal;
  final bool hasEstimates;

  const ShoppingListsSummary({
    required this.listCount,
    required this.totalItems,
    required this.pendingItems,
    required this.boughtItems,
    required this.estimatedTotal,
    required this.hasEstimates,
  });

  const ShoppingListsSummary.empty()
      : listCount = 0,
        totalItems = 0,
        pendingItems = 0,
        boughtItems = 0,
        estimatedTotal = 0,
        hasEstimates = false;
}

final shoppingListsSummaryProvider = Provider<ShoppingListsSummary>((ref) {
  final lists =
      ref.watch(shoppingListsProvider).valueOrNull ?? const <ShoppingList>[];
  if (lists.isEmpty) return const ShoppingListsSummary.empty();

  var total = 0;
  var bought = 0;
  var estimated = 0.0;
  var hasEstimates = false;
  for (final list in lists) {
    total += list.totalItems;
    bought += list.boughtItems;
    estimated += list.estimatedTotal;
    hasEstimates = hasEstimates || list.hasEstimates;
  }

  return ShoppingListsSummary(
    listCount: lists.length,
    totalItems: total,
    pendingItems: total - bought,
    boughtItems: bought,
    estimatedTotal: estimated,
    hasEstimates: hasEstimates,
  );
});
