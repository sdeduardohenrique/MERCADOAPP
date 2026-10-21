import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cart_item.dart';
import '../models/community_price.dart';

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
  static User? get currentUser => client.auth.currentUser;
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

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
  static Future<List<Product>> searchProducts(String query, {int limit = 20}) async {
    final normalized = query.toLowerCase().trim();
    final response = await client
        .from('products')
        .select()
        .or('name.ilike.%$normalized%,brand.ilike.%$normalized%,ean.eq.$normalized')
        .limit(limit);
    return (response as List).map((e) => Product.fromJson(e)).toList();
  }

  static Future<Product?> getProductByEan(String ean) async {
    final response = await client
        .from('products')
        .select()
        .eq('ean', ean)
        .maybeSingle();
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
    final response = await client
        .from('stores')
        .select()
        .eq('id', id)
        .maybeSingle();
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
    final response = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
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

  /// Storage
  static Future<String> uploadReceiptPhoto(String path, String fileName) async {
    final userId = currentUser?.id ?? 'anonymous';
    final storagePath = 'receipts/$userId/$fileName';
    await client.storage.from('receipts').upload(storagePath, path);
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
            // Convert payload to alert
            final newRecord = payload.newRecord;
            if (newRecord != null) {
              // Would need to join with stores/products for full alert
              // This is a simplified version
            }
          },
        )
        .subscribe();
  }
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