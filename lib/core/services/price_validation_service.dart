import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../models/community_price.dart';
import '../utils/text_normalizer.dart';
import 'location_service.dart';

class PriceValidationService {
  // Lazy: só toca em Supabase.instance quando for realmente usar a rede.
  // Assim a tela abre normalmente em modo offline.
  late final SupabaseClient _supabase = Supabase.instance.client;
  final LocationService _locationService;

  // In-memory cache for price validation results
  final Map<String, CachedAlert> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  PriceValidationService(this._locationService);

  /// `true` quando o Supabase terminou de inicializar.
  bool get isOnline {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  /// Checks if there's a better price in the community for a scanned item
  Future<CommunityPriceAlert?> checkBetterPrice({
    required CartItem item,
    required double currentPrice,
  }) async {
    if (!isOnline) return null;

    final ean = item.ean?.trim();
    if (ean == null || ean.isEmpty) return null;

    // Check cache first
    final cacheKey = '$ean-$currentPrice';
    final cached = _cache[cacheKey];
    if (cached != null && cached.isValid) {
      return cached.alert;
    }

    try {
      // Get current location
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        _cacheResult(cacheKey, null);
        return null;
      }

      // Call Supabase RPC function
      final response = await _supabase.rpc(
        'find_better_prices_nearby',
        params: {
          'p_ean': ean,
          'p_user_lat': position.latitude,
          'p_user_lon': position.longitude,
          'p_current_price': currentPrice,
          'p_radius_km': 15,
          'p_limit': 3,
        },
      );

      if (response == null || (response as List).isEmpty) {
        _cacheResult(cacheKey, null);
        return null;
      }

      // Find best alert (lowest unit price with actual savings)
      final alerts = response
          .map((e) => CommunityPriceAlert.fromRpc(e as Map<String, dynamic>))
          .where((alert) => alert.savings > 0.01)
          .toList();

      if (alerts.isEmpty) {
        _cacheResult(cacheKey, null);
        return null;
      }

      // Sort by unit price ascending, then by recency
      alerts.sort((a, b) {
        final priceCompare = a.unitPrice.compareTo(b.unitPrice);
        if (priceCompare != 0) return priceCompare;
        return b.capturedAt.compareTo(a.capturedAt);
      });

      final bestAlert = alerts.first;
      _cacheResult(cacheKey, bestAlert);
      return bestAlert;
    } catch (e) {
      // Log error but don't break UX
      debugPrint('PriceValidationService error: $e');
      _cacheResult(cacheKey, null);
      return null;
    }
  }

  /// Submits a new community price (when user confirms)
  Future<bool> submitCommunityPrice({
    required CartItem item,
    required String storeId,
    required double price,
    double? quantity,
    String? unit,
    bool isPromo = false,
    DateTime? promoEndsAt,
    String? receiptPhotoPath,
  }) async {
    if (!isOnline) return false;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Resolve or create product
      String productId;
      if (item.ean != null && item.ean!.isNotEmpty) {
        final existing = await _supabase
            .from('products')
            .select('id')
            .eq('ean', item.ean!)
            .maybeSingle();

        if (existing != null) {
          productId = existing['id'] as String;
        } else {
          final inserted = await _supabase
              .from('products')
              .insert({
                'ean': item.ean,
                'name': item.name,
                'brand': item.brand,
                'unit': item.unit,
              })
              .select('id')
              .single();
          productId = inserted['id'] as String;
        }
      } else {
        productId = await _resolveOrCreateProduct(item);
      }

      await _supabase.from('community_prices').insert({
        'product_id': productId,
        'store_id': storeId,
        'user_id': userId,
        'price': price,
        'quantity': quantity,
        'unit': unit ?? item.unit,
        'is_promo': isPromo,
        'promo_ends_at': promoEndsAt?.toIso8601String(),
        'receipt_photo_path': receiptPhotoPath,
      });

      // Invalidate cache for this EAN
      _invalidateCacheForEan(item.ean ?? '');

      return true;
    } catch (e) {
      debugPrint('Submit community price error: $e');
      return false;
    }
  }

  /// Resolves existing product by fuzzy name match or creates new
  Future<String> _resolveOrCreateProduct(CartItem item) async {
    final normalized = TextNormalizer.normalize(item.name);
    final results = await _supabase
        .from('products')
        .select('id, name')
        .textSearch('normalized_name', normalized)
        .limit(5);

    for (final r in results) {
      final similarity = _calculateSimilarity(
          normalized, TextNormalizer.normalize(r['name'] as String));
      if (similarity > 0.85) return r['id'] as String;
    }

    // Create new product
    final inserted = await _supabase
        .from('products')
        .insert({'name': item.name, 'brand': item.brand, 'unit': item.unit})
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;
    final longerLength = longer.length;
    if (longerLength == 0) return 1.0;
    return (longerLength - _editDistance(longer, shorter)) / longerLength;
  }

  int _editDistance(String a, String b) {
    final costs = List<int>.filled(b.length + 1, 0);
    for (int j = 0; j <= b.length; j++) {
      costs[j] = j;
    }
    for (int i = 1; i <= a.length; i++) {
      costs[0] = i;
      int nw = i - 1;
      for (int j = 1; j <= b.length; j++) {
        int cj = _min3(
          costs[j] + 1,
          costs[j - 1] + 1,
          nw + (a[i - 1] == b[j - 1] ? 0 : 1),
        );
        nw = costs[j];
        costs[j] = cj;
      }
    }
    return costs[b.length];
  }

  int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);

  /// Caches a validation result
  void _cacheResult(String key, CommunityPriceAlert? alert) {
    _cache[key] = CachedAlert(alert: alert, timestamp: DateTime.now());
  }

  /// Invalidates cache entries for a specific EAN
  void _invalidateCacheForEan(String ean) {
    _cache.removeWhere((key, _) => key.startsWith('$ean-'));
  }

  /// Clears all cache
  void clearCache() {
    _cache.clear();
  }
}

class CachedAlert {
  final CommunityPriceAlert? alert;
  final DateTime timestamp;

  CachedAlert({required this.alert, required this.timestamp});

  bool get isValid =>
      DateTime.now().difference(timestamp) < PriceValidationService._cacheTtl;
}

/// Riverpod provider
final priceValidationServiceProvider = Provider<PriceValidationService>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return PriceValidationService(locationService);
});
