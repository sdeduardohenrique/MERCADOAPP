import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/shopping_list.dart';
import '../domain/shopping_sector.dart';

/// Persistência das listas de compras.
///
/// Estratégia offline-first:
/// - visitante: somente SharedPreferences;
/// - autenticado: cache local + tabelas `listas_compras` e `itens_lista`.
class ShoppingListsService {
  const ShoppingListsService();

  static const String listsTable = 'listas_compras';
  static const String itemsTable = 'itens_lista';

  static const String _localPrefix = 'somaai.shopping_lists.v2';
  static const String _legacyGuestKey = 'somaai.pre_shopping_list.v1.guest';

  String localKey(String? userId) => '$_localPrefix.${userId ?? 'guest'}';

  Future<List<ShoppingList>> loadLocal({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(localKey(userId));
      if (raw != null && raw.isNotEmpty) {
        return _decodeLists(raw);
      }

      // Migração única da lista antiga do visitante. Usuários logados são
      // migrados no banco pela migration 010 (evita duplicar a lista).
      if (userId == null) {
        final migrated = await _migrateLegacyGuest(prefs);
        if (migrated.isNotEmpty) {
          await saveLocal(migrated, userId: userId);
          return migrated;
        }
      }
      return const [];
    } catch (error) {
      debugPrint('[SomaAí] Listas locais indisponíveis: $error');
      return const [];
    }
  }

  Future<void> saveLocal(
    List<ShoppingList> lists, {
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(lists.map((list) => list.toJson()).toList());
      await prefs.setString(localKey(userId), raw);
    } catch (error) {
      debugPrint('[SomaAí] Não foi possível salvar as listas: $error');
    }
  }

  Future<List<ShoppingList>> fetchRemote(String userId) async {
    if (!SupabaseService.isReady) return const [];

    final listRows = await SupabaseService.client
        .from(listsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    final itemRows = await SupabaseService.client
        .from(itemsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    final itemsByList = <String, List<ShoppingListItem>>{};
    for (final row in itemRows) {
      final item = ShoppingListItem.fromRemote(
        Map<String, dynamic>.from(row),
      );
      itemsByList.putIfAbsent(item.listId, () => []).add(item);
    }

    return listRows.map((row) {
      final json = Map<String, dynamic>.from(row);
      final id = json['id'] as String? ?? '';
      return ShoppingList.fromRemote(
        json,
        items: itemsByList[id] ?? const <ShoppingListItem>[],
      );
    }).toList();
  }

  Future<void> upsertList(ShoppingList list, String userId) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client.from(listsTable).upsert(list.toRemote(userId));
  }

  Future<void> upsertItem(ShoppingListItem item, String userId) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client.from(itemsTable).upsert(item.toRemote(userId));
  }

  Future<void> deleteList(String id, String userId) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client
        .from(listsTable)
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<void> deleteItem(String id, String userId) async {
    if (!SupabaseService.isReady) return;
    await SupabaseService.client
        .from(itemsTable)
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  List<ShoppingList> _decodeLists(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final lists = decoded
        .whereType<Map>()
        .map(
          (item) => ShoppingList.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return lists;
  }

  Future<List<ShoppingList>> _migrateLegacyGuest(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_legacyGuestKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    final now = DateTime.now().toUtc();
    final listId = const Uuid().v4();
    final items = <ShoppingListItem>[];
    for (final entry in decoded.whereType<Map>()) {
      final json = Map<String, dynamic>.from(entry);
      final name = (json['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final createdAt =
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now;
      items.add(
        ShoppingListItem(
          id: json['id'] as String? ?? const Uuid().v4(),
          listId: listId,
          name: name,
          quantity: 1,
          unit: 'un',
          sector: ShoppingSector.categorize(name),
          isBought: json['isBought'] as bool? ?? false,
          createdAt: createdAt,
          updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
              createdAt,
        ),
      );
    }
    if (items.isEmpty) return const [];

    return [
      ShoppingList(
        id: listId,
        name: 'Minha Lista',
        icon: '🛒',
        items: items,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
