import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/mercado.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/tomtom_service.dart';

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
  double radiusMeters,
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
    NearbyMarketsFetcher? nearbyFetcher,
    MarketNameSearcher? nameSearcher,
    MarketCreator? creator,
    TomTomService? tomTomService,
    bool allowRemote = true,
  })  : _locationService = locationService ?? LocationService(),
        _nearbyFetcher = nearbyFetcher,
        _nameSearcher = nameSearcher,
        _creator = creator,
        _tomTomService = tomTomService,
        _allowRemote = allowRemote;

  final LocationService _locationService;
  final NearbyMarketsFetcher? _nearbyFetcher;
  final MarketNameSearcher? _nameSearcher;
  final MarketCreator? _creator;
  final TomTomService? _tomTomService;

  /// `false` no modo visitante: o app não lê nem grava na comunidade.
  final bool _allowRemote;

  /// Busca híbrida de mercados próximos:
  ///
  /// 1. base interna (PostGIS / RPC `buscar_mercados_proximos`);
  /// 2. fallback TomTom Places API quando a base interna não retorna nada;
  /// 3. deduplicação por nome e por `external_id`.
  ///
  /// Passe [includeExternal] `false` para consultar apenas a base interna
  /// (usado no match exato de 100 m).
  Future<List<Mercado>> findNearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
    int limit = 20,
    bool includeExternal = true,
  }) async {
    final fetcher = _nearbyFetcher;

    final results = <Mercado>[];
    final chaves = <String>{};
    MarketServiceException? localError;

    try {
      // No modo visitante a comunidade é ignorada por completo: nenhuma
      // leitura vai para o Supabase (evita RLS e mistura de identidades).
      if (!_allowRemote) {
        debugPrint('[MarketService] visitante: base interna ignorada.');
      } else {
        final local = fetcher != null
            ? await fetcher(
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
                limit: limit,
              )
            : await _fetchNearbyFromSupabase(
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
                limit: limit,
              );
        for (final mercado in local) {
          final externo = mercado.externalId;
          if (externo != null &&
              externo.isNotEmpty &&
              !chaves.add('e:$externo')) {
            continue;
          }
          if (!chaves.add('n:${_normalizeName(mercado.nome)}')) continue;
          results.add(mercado);
        }
      }
    } on MarketServiceException catch (error) {
      localError = error;
    } catch (error) {
      localError = const MarketServiceException(
        'Não foi possível carregar os mercados próximos agora.',
      );
      debugPrint('[MarketService] falha na base interna: $error');
    }

    final tomTom = _tomTomService;
    // A TomTom só entra quando a base interna não tem nada no raio — evita
    // gastar cota da API e mantém a busca rápida quando a comunidade já cobre
    // a região.
    if (includeExternal &&
        results.isEmpty &&
        tomTom != null &&
        tomTom.isConfigured) {
      try {
        final places = await tomTom.searchNearby(
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
          limit: limit,
        );
        for (final place in places) {
          // IDs da TomTom são únicos; lojas diferentes com o mesmo nome
          // (ex.: filiais "Carrefour") devem continuar aparecendo.
          if (!chaves.add('e:${place.id}')) continue;
          results.add(place.toMercado());
        }
      } catch (error) {
        // A TomTom é opcional: falha silenciosa, a base interna continua.
        debugPrint('[MarketService] TomTom indisponível: $error');
      }
    }

    if (results.isEmpty && localError != null) {
      throw localError;
    }

    results.sort((a, b) {
      final da = a.distanciaMetros ?? double.infinity;
      final db = b.distanciaMetros ?? double.infinity;
      return da.compareTo(db);
    });

    return results.take(limit).toList(growable: false);
  }

  /// Busca por nome ancorada na posição atual.
  ///
  /// No modo visitante consulta apenas a TomTom; para utilizadores logados
  /// combina a base da comunidade com a Places API. [radiusMeters] limita os
  /// resultados à região real do utilizador.
  Future<List<Mercado>> searchByName(
    String query, {
    double? latitude,
    double? longitude,
    double radiusMeters = 5000,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final searcher = _nameSearcher;

    final results = <Mercado>[];
    final chaves = <String>{};
    // Nome -> distância dos resultados locais, para não duplicar na TomTom
    // exatamente o mesmo mercado já listado pela comunidade.
    final nomesLocais = <String, double?>{};
    Object? localError;

    try {
      if (!_allowRemote) {
        debugPrint('[MarketService] visitante: busca interna ignorada.');
      } else {
        final local = searcher != null
            ? await searcher(
                trimmed,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
              )
            : await _searchFromSupabase(
                trimmed,
                latitude: latitude,
                longitude: longitude,
              );
        for (final mercado in local) {
          // The RPC da comunidade não recebe raio; filtramos aqui para não
          // mostrar mercados de outra cidade.
          final distancia = mercado.distanciaMetros;
          if (distancia != null && distancia > radiusMeters) continue;
          final nomeNormalizado = _normalizeName(mercado.nome);
          if (!chaves.add('n:$nomeNormalizado')) continue;
          nomesLocais.putIfAbsent(nomeNormalizado, () => distancia);
          results.add(mercado);
        }
      }
    } catch (error) {
      localError = error;
    }

    final tomTom = _tomTomService;
    if (tomTom != null && tomTom.isConfigured) {
      try {
        final places = await tomTom.searchByName(
          trimmed,
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
        );
        for (final place in places) {
          if (!chaves.add('e:${place.id}')) continue;
          // Só descarta se for claramente o mesmo mercado local (mesmo nome e
          // distância parecida). Filiais com o mesmo nome continuam visíveis.
          final nomeNormalizado = _normalizeName(place.nome);
          final distanciaLocal = nomesLocais[nomeNormalizado];
          final distanciaTomTom = place.distanciaMetros;
          if (distanciaLocal != null &&
              distanciaTomTom != null &&
              (distanciaLocal - distanciaTomTom).abs() < 200) {
            continue;
          }
          results.add(place.toMercado());
        }
      } catch (error) {
        debugPrint('[MarketService] busca TomTom indisponível: $error');
      }
    }

    if (results.isEmpty && localError is MarketServiceException) {
      throw localError;
    }

    return results;
  }

  /// Sincronização invisível de um mercado vindo da TomTom.
  ///
  /// Faz upsert por `external_id` (nunca duplica) e devolve o mercado já
  /// persistido (com `id` real do Supabase). Se a nuvem falhar, devolve o
  /// próprio mercado local para a compra continuar funcionando offline.
  Future<MarketCreationResult> persistExternalMarket(Mercado market) async {
    final externalId = market.externalId;
    if (externalId == null || externalId.isEmpty) {
      return MarketCreationResult(market);
    }

    // Visitante: nada é enviado para a nuvem.
    if (!_allowRemote) return MarketCreationResult(market);

    if (!SupabaseService.isReady) {
      return MarketCreationResult(market);
    }

    try {
      final response = await SupabaseService.client.rpc(
        'upsert_mercado_by_external_id',
        params: {
          'p_external_id': externalId,
          'p_nome': market.nome,
          'p_lat': market.latitude,
          'p_lng': market.longitude,
          'p_cidade': market.cidade,
          'p_bairro': market.bairro,
          'p_endereco': market.endereco,
        },
      );
      final rows = _mapRows(response);
      if (rows.isEmpty) {
        return MarketCreationResult(market);
      }
      return MarketCreationResult(rows.first.copyWith(externalId: externalId));
    } catch (error) {
      debugPrint('[MarketService] upsert do mercado externo falhou: $error');
      return MarketCreationResult(market, error: error);
    }
  }

  /// Chave de comparação tolerante a acentos, caixa e pontuação.
  static String _normalizeName(String value) {
    const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const semAcento = 'aaaaaeeeeiiiiooooouuuucn';
    var texto = value.toLowerCase().trim();
    for (var i = 0; i < comAcento.length; i++) {
      texto = texto.replaceAll(comAcento[i], semAcento[i]);
    }
    return texto.replaceAll(RegExp(r'[^a-z0-9]'), '');
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

    if (!_allowRemote) {
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
    tomTomService: ref.watch(tomTomServiceProvider),
    allowRemote: !ref.watch(isGuestProvider),
  );
});

final tomTomServiceProvider = Provider<TomTomService>((ref) {
  final service = TomTomService(
    apiKey: const String.fromEnvironment('TOMTOM_API_KEY'),
  );
  ref.onDispose(service.dispose);
  return service;
});
