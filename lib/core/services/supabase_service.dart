import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_price.dart';
import '../models/purchase.dart';

/// Supabase service for database operations
class SupabaseService {
  /// `true` quando o Supabase já foi inicializado (modo online disponível).
  static bool get isReady {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient get client {
    if (!isReady) {
      throw StateError(
        'Supabase não inicializado. O app está em modo offline.',
      );
    }
    return Supabase.instance.client;
  }

  /// Auth
  ///
  /// O app pode arrancar em modo offline. Nesse caso não existe cliente
  /// Supabase e o histórico local continua sendo a fonte de verdade.
  static User? get currentUser {
    if (!isReady) return null;
    return client.auth.currentUser;
  }

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static Future<void> signUp(String email, String password) async {
    await client.auth.signUp(email: email, password: password);
  }

  static Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Products
  static Future<List<Product>> searchProducts(String query,
      {int limit = 20}) async {
    final normalized = query.toLowerCase().trim();
    final response = await client
        .from('products')
        .select()
        .or('name.ilike.%$normalized%,brand.ilike.%$normalized%,ean.eq.$normalized')
        .limit(limit);
    return (response as List).map((e) => Product.fromJson(e)).toList();
  }

  static Future<Product?> getProductByEan(String ean) async {
    final response =
        await client.from('products').select().eq('ean', ean).maybeSingle();
    return response != null ? Product.fromJson(response) : null;
  }

  static Future<Product> createProduct({
    required String name,
    String? ean,
    String? brand,
    String? category,
    String? unit,
  }) async {
    final response = await client
        .from('products')
        .insert({
          'ean': ean,
          'name': name,
          'brand': brand,
          'category': category,
          'unit': unit,
        })
        .select()
        .single();
    return Product.fromJson(response);
  }

  /// Stores
  static Future<List<Store>> getNearbyStores({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int limit = 20,
  }) async {
    final response = await client.rpc('find_stores_nearby', params: {
      'p_lat': latitude,
      'p_lon': longitude,
      'p_radius_km': radiusKm,
      'p_limit': limit,
    });
    return (response as List).map((e) => Store.fromJson(e)).toList();
  }

  static Future<Store?> getStoreById(String id) async {
    final response =
        await client.from('mercados').select().eq('id', id).maybeSingle();
    return response != null ? Store.fromJson(response) : null;
  }

  /// Community Prices
  static Future<List<CommunityPriceAlert>> getBetterPrices({
    required String ean,
    required double latitude,
    required double longitude,
    double radiusKm = 15,
    int limit = 5,
    double currentPrice = 0,
  }) async {
    final response = await client.rpc('find_better_prices_nearby', params: {
      'p_ean': ean,
      'p_user_lat': latitude,
      'p_user_lon': longitude,
      'p_current_price': currentPrice,
      'p_radius_km': radiusKm,
      'p_limit': limit,
    });
    return (response as List)
        .map((e) => CommunityPriceAlert.fromRpc(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> submitPrice({
    required String productId,
    required String storeId,
    required double price,
    double? quantity,
    String? unit,
    bool isPromo = false,
    DateTime? promoEndsAt,
    String? receiptPhotoPath,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await client.from('community_prices').insert({
      'product_id': productId,
      'store_id': storeId,
      'user_id': userId,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'is_promo': isPromo,
      'promo_ends_at': promoEndsAt?.toIso8601String(),
      'receipt_photo_path': receiptPhotoPath,
    });
  }

  /// User Profile
  static Future<Profile?> getProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    final response =
        await client.from('profiles').select().eq('id', userId).maybeSingle();
    return response != null ? Profile.fromJson(response) : null;
  }

  static Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await client.from('profiles').upsert({
      'id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Purchases
  ///
  /// O histórico local é gravado primeiro. Quando há um utilizador Supabase
  /// autenticado, o resumo é espelhado na nuvem; o total do mês é derivado
  /// pela view `monthly_spending` (migration 002).
  static Future<void> savePurchase(Purchase purchase) async {
    if (!isReady) {
      throw StateError('Supabase não inicializado. Compra mantida localmente.');
    }
    if (currentUser == null) {
      throw StateError('Sem sessão Supabase. Compra mantida localmente.');
    }
    if (purchase.items.isEmpty) {
      throw ArgumentError('Uma compra precisa de pelo menos um item.');
    }

    // The RPC creates or updates the summary and replaces the items in one
    // transaction, preventing a purchase without items after a network drop.
    await client.rpc(
      'save_purchase_with_items',
      params: {
        'p_id': purchase.id,
        'p_store_name': purchase.storeName,
        'p_savings': purchase.savings,
        'p_purchased_at': purchase.date.toUtc().toIso8601String(),
        'p_items': purchase.items
            .map(
              (item) => {
                'name': item.name,
                'unit': item.unit,
                // The current schema only stores an integer quantity. For
                // weighted items we persist the line total with quantity 1 so
                // the remote monthly total remains correct.
                'unit_price':
                    item.isByWeight ? item.totalPrice : item.unitPrice,
                'quantity': item.isByWeight ? 1 : item.quantity,
              },
            )
            .toList(),
        if (purchase.marketId != null) 'p_mercado_id': purchase.marketId,
      },
    );
  }

  /// Edits a purchase already mirrored in Supabase.
  ///
  /// Uses the same atomic RPC as [savePurchase], so a purchase that was created
  /// locally while offline is uploaded on the first edit after login.
  static Future<void> updatePurchase(Purchase purchase) async {
    await savePurchase(purchase);
  }

  /// Deletes a purchase and (by cascade) all of its items.
  static Future<void> deletePurchase(String id) async {
    if (!isReady) {
      throw StateError(
          'Supabase não inicializado. Exclusão mantida localmente.');
    }
    final userId = currentUser?.id;
    if (userId == null) {
      throw StateError('Sem sessão Supabase. Exclusão mantida localmente.');
    }

    await client.from('purchases').delete().eq('id', id).eq('user_id', userId);
  }

  /// Total gasto pelo utilizador no mês indicado (ou no mês corrente).
  ///
  /// Retorna `0` em modo offline/sem sessão para a UI nunca falhar.
  static Future<double> getMonthlySpending({DateTime? month}) async {
    if (!isReady || currentUser == null) return 0;

    final reference = month ?? DateTime.now();
    final start = DateTime(reference.year, reference.month, 1);
    final end = DateTime(reference.year, reference.month + 1, 1);

    final response = await client
        .from('purchases')
        .select('total')
        .eq('user_id', currentUser!.id)
        .gte('purchased_at', start.toUtc().toIso8601String())
        .lt('purchased_at', end.toUtc().toIso8601String());

    return (response as List).fold<double>(
      0,
      (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0),
    );
  }

  /// Resumo (total gasto, economia e nº de compras) num intervalo inclusivo.
  ///
  /// O Dashboard usa o histórico local como fonte de verdade, mas esta consulta
  /// mantém a mesma regra de datas disponível para a sessão autenticada sem
  /// duplicar somas: `purchased_at >= início AND purchased_at < fim do dia`.
  static Future<PurchaseRangeSummary> getPurchaseSummaryInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!isReady || currentUser == null) {
      return const PurchaseRangeSummary.empty();
    }

    final startDate = DateTime(start.year, start.month, start.day);
    final endExclusive = DateTime(end.year, end.month, end.day + 1);

    final response = await client
        .from('purchases')
        .select('total, savings')
        .eq('user_id', currentUser!.id)
        .gte('purchased_at', startDate.toUtc().toIso8601String())
        .lt('purchased_at', endExclusive.toUtc().toIso8601String());

    var total = 0.0;
    var savings = 0.0;
    var count = 0;
    for (final row in (response as List)) {
      final map = row as Map<String, dynamic>;
      total += (map['total'] as num?)?.toDouble() ?? 0;
      savings += (map['savings'] as num?)?.toDouble() ?? 0;
      count++;
    }

    return PurchaseRangeSummary(
      total: total,
      savings: savings,
      purchaseCount: count,
    );
  }

  /// Storage
  static Future<String> uploadReceiptPhoto(String path, String fileName) async {
    final userId = currentUser?.id ?? 'anonymous';
    final storagePath = 'receipts/$userId/$fileName';
    await client.storage.from('receipts').upload(storagePath, File(path));
    return storagePath;
  }

  static String getReceiptPhotoUrl(String path) {
    return client.storage.from('receipts').getPublicUrl(path);
  }

  /// Realtime subscription for price updates
  static RealtimeChannel subscribeToPriceUpdates(
    String productId,
    void Function(CommunityPriceAlert) onPriceUpdate,
  ) {
    return client
        .channel('price_updates:$productId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_prices',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'product_id',
            value: productId,
          ),
          callback: (payload) {
            // The record is available in payload.newRecord. A full alert
            // needs a join with stores/products, done when this realtime path
            // is wired to the UI.
          },
        )
        .subscribe();
  }
}

/// Resumo de compras num intervalo de datas.
class PurchaseRangeSummary {
  final double total;
  final double savings;
  final int purchaseCount;

  const PurchaseRangeSummary({
    required this.total,
    required this.savings,
    required this.purchaseCount,
  });

  const PurchaseRangeSummary.empty()
      : total = 0,
        savings = 0,
        purchaseCount = 0;
}

/// Profile model
class Profile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final int trustScore;
  final DateTime createdAt;

  Profile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    required this.trustScore,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      trustScore: json['trust_score'] as int? ?? 100,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
