import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/mercado.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';

class MarketServiceException implements Exception {
  final String message;

  const MarketServiceException(this.message);

  @override
  String toString() => message;
}

class MarketCreationResult {
  final Mercado market;
  final Object? error;

  const MarketCreationResult(this.market, {this.error});

  bool get isRemote => market.isRemoto;
}

typedef MarketLocationResolver = Future<LocationAccessResult> Function({
  bool forceRefresh,
});
typedef NearbyMarketsFetcher = Future<List<Mercado>> Function({
  required double latitude,
  required double longitude,
  required double radiusMeters,
  int limit,
});
typedef MarketNameSearcher = Future<List<Mercado>> Function(
  String query, {
  double? latitude,
  double? longitude,
});
typedef MarketCreator = Future<MarketCreationResult> Function({
  required String name,
  double? latitude,
  double? longitude,
  String? city,
  String? neighborhood,
});

/// Fala com as RPCs de mercado e mantém um fallback local quando a nuvem
/// não está disponível.
///
/// Os callbacks existem para testes e para permitir trocar Supabase por Places
/// API no futuro sem tocar na UI.
class MarketService {
  MarketService({
    LocationService? locationService,
    MarketLocationResolver? locationResolver,
    NearbyMarketsFetcher? nearbyFetcher,
    MarketNameSearcher? nameSearcher,
    MarketCreator? creator,
  })  : _locationService = locationService ?? LocationService(),
        _locationResolver = locationResolver,
        _nearbyFetcher = nearbyFetcher,
        _nameSearcher = nameSearcher,
        _creator = creator;

  final LocationService _locationService;
  final MarketLocationResolver? _locationResolver;
  final NearbyMarketsFetcher? _nearbyFetcher;
  final MarketNameSearcher? _nameSearcher;
  final MarketCreator? _creator;

  Future<LocationAccessResult> resolveLocation({bool forceRefresh = true}) {
    final resolver = _locationResolver;
    if (resolver != null) return resolver(forceRefresh: forceRefresh);
    return _locationService.resolveCurrentPosition(
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Mercado>> findNearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
    int limit = 20,
  }) async {
    final fetcher = _nearbyFetcher;
    if (fetcher != null) {
      return fetcher(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        limit: limit,
      );
    }
    return _fetchNearbyFromSupabase(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      limit: limit,
    );
  }

  Future<List<Mercado>> searchByName(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final searcher = _nameSearcher;
    if (searcher != null) {
      return searcher(
        trimmed,
        latitude: latitude,
        longitude: longitude,
      );
    }
    return _searchFromSupabase(
      trimmed,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<MarketCreationResult> createMarket({
    required String name,
    double? latitude,
    double? longitude,
    String? city,
    String? neighborhood,
  }) async {
    final creator = _creator;
    if (creator != null) {
      return creator(
        name: name,
        latitude: latitude,
        longitude: longitude,
        city: city,
        neighborhood: neighborhood,
      );
    }
    return _createInSupabase(
      name: name,
      latitude: latitude,
      longitude: longitude,
      city: city,
      neighborhood: neighborhood,
    );
  }

  Future<bool> openAppSettings() => _locationService.openAppSettingsPage();

  Future<bool> openLocationSettings() =>
      _locationService.openLocationSettingsPage();

  Future<List<Mercado>> _fetchNearbyFromSupabase({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required int limit,
  }) async {
    if (!SupabaseService.isReady) {
      throw const MarketServiceException(
        'Sem conexão com a comunidade. Você pode buscar pelo nome ou cadastrar o mercado.',
      );
    }

    try {
      final response = await SupabaseService.client.rpc(
        'buscar_mercados_proximos',
        params: {
          'p_lat': latitude,
          'p_lng': longitude,
          'p_raio_metros': radiusMeters,
          'p_limit': limit,
        },
      );
      return _mapRows(response);
    } catch (error) {
      throw const MarketServiceException(
        'Não foi possível carregar os mercados próximos agora.',
      );
    }
  }

  Future<List<Mercado>> _searchFromSupabase(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    if (!SupabaseService.isReady) {
      throw const MarketServiceException(
        'A busca precisa de conexão. Cadastre o mercado manualmente.',
      );
    }

    try {
      final response = await SupabaseService.client.rpc(
        'buscar_mercados_por_nome',
        params: {
          'p_query': query,
          'p_lat': latitude,
          'p_lng': longitude,
          'p_limit': 20,
        },
      );
      return _mapRows(response);
    } catch (_) {
      throw const MarketServiceException(
        'Não foi possível buscar mercados agora. Tente novamente.',
      );
    }
  }

  Future<MarketCreationResult> _createInSupabase({
    required String name,
    double? latitude,
    double? longitude,
    String? city,
    String? neighborhood,
  }) async {
    if (!SupabaseService.isReady) {
      return MarketCreationResult(
        _localMarket(
          name: name,
          latitude: latitude,
          longitude: longitude,
          city: city,
          neighborhood: neighborhood,
        ),
      );
    }

    try {
      final response = await SupabaseService.client.rpc(
        'criar_mercado',
        params: {
          'p_nome': name.trim(),
          'p_lat': latitude,
          'p_lng': longitude,
          'p_cidade': city,
          'p_bairro': neighborhood,
        },
      );
      final rows = _mapRows(response);
      if (rows.isEmpty) {
        throw const MarketServiceException(
          'O mercado não foi retornado pelo servidor.',
        );
      }
      return MarketCreationResult(rows.first);
    } catch (error) {
      return MarketCreationResult(
        _localMarket(
          name: name,
          latitude: latitude,
          longitude: longitude,
          city: city,
          neighborhood: neighborhood,
        ),
        error: error,
      );
    }
  }

  static List<Mercado> _mapRows(dynamic response) {
    if (response == null) return const [];
    final rows = response as List;
    return rows.whereType<Map<String, dynamic>>().map(Mercado.fromRpc).toList();
  }

  static Mercado _localMarket({
    required String name,
    double? latitude,
    double? longitude,
    String? city,
    String? neighborhood,
  }) {
    return Mercado(
      id: const Uuid().v4(),
      nome: name.trim(),
      latitude: latitude,
      longitude: longitude,
      cidade: city,
      bairro: neighborhood,
      isRemoto: false,
    );
  }
}

final marketServiceProvider = Provider<MarketService>((ref) {
  return MarketService(
    locationService: ref.watch(locationServiceProvider),
  );
});
