import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/mercado.dart';

/// Erro de integração com a TomTom Places Search API.
class TomTomServiceException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const TomTomServiceException(
    this.message, {
    this.statusCode,
    this.code,
  });

  @override
  String toString() => 'TomTomServiceException: $message'
      '${statusCode != null ? ' (HTTP $statusCode)' : ''}'
      '${code != null ? ' [$code]' : ''}';
}

/// POI devolvido pela Places Search API (versão 3).
class TomTomPlace {
  /// `id` único do lugar — gravado em `mercados.external_id`.
  final String id;
  final String nome;
  final double latitude;
  final double longitude;
  final String? endereco;
  final String? cidade;
  final String? bairro;
  final double? distanciaMetros;
  final List<String> poiTypes;

  const TomTomPlace({
    required this.id,
    required this.nome,
    required this.latitude,
    required this.longitude,
    this.endereco,
    this.cidade,
    this.bairro,
    this.distanciaMetros,
    this.poiTypes = const [],
  });

  /// Converte o resultado da API para o modelo interno do app.
  ///
  /// `isRemoto` fica `false` porque o mercado ainda não existe no Supabase —
  /// o upsert acontece só quando o usuário confirma a seleção.
  Mercado toMercado() {
    return Mercado(
      id: const Uuid().v4(),
      nome: nome,
      latitude: latitude,
      longitude: longitude,
      distanciaMetros: distanciaMetros,
      endereco: endereco,
      cidade: cidade,
      bairro: bairro,
      externalId: id,
      isRemoto: false,
    );
  }

  factory TomTomPlace.fromJson(Map<String, dynamic> json) {
    final position = json['position'];
    final coordinates =
        position is Map ? (position['coordinates'] as List<dynamic>?) : null;

    double? coordinate(int index) {
      if (coordinates == null || coordinates.length <= index) return null;
      final value = coordinates[index];
      return value is num ? value.toDouble() : null;
    }

    final address = json['address'] is Map<String, dynamic>
        ? json['address'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final street = _clean(address['street']);
    final number = _clean(address['houseNumber']);
    final endereco = [
      if (street != null) street,
      if (number != null) number,
    ].join(', ');

    final poiTypesJson = json['poiTypes'];
    final poiTypes = poiTypesJson is List
        ? poiTypesJson
            .whereType<Map<String, dynamic>>()
            .map((item) => _clean(item['id']))
            .whereType<String>()
            .toList()
        : const <String>[];

    return TomTomPlace(
      id: _clean(json['id']) ?? '',
      nome: _clean(json['title']) ?? 'Mercado',
      latitude: coordinate(1) ?? 0,
      longitude: coordinate(0) ?? 0,
      endereco: endereco.isEmpty ? null : endereco,
      cidade: _clean(address['municipality']),
      bairro: _clean(address['municipalitySubdivision']) ??
          _clean(address['neighborhood']),
      distanciaMetros: (json['distanceInMeters'] as num?)?.toDouble(),
      poiTypes: poiTypes,
    );
  }

  static String? _clean(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

/// Cliente da TomTom Places Search API (v3 — Orbis Maps).
///
/// Documentação:
/// https://docs.tomtom.com/places-search-api/documentation/product-information/introduction
///
/// A chave é lida de `--dart-define=TOMTOM_API_KEY=...`. Sem chave, o serviço
/// fica desativado e o app segue apenas com a base interna (PostGIS) + cadastro
/// manual.
class TomTomService {
  static const String _baseUrl = 'https://api.tomtom.com/maps/orbis/places';

  /// Tipos de POI considerados "mercado" pela Places Search API v3.
  static const List<String> marketPoiTypes = [
    'supermarket',
    'grocery_store',
    'food_market',
    'convenience_store',
    'greengrocer',
    'delicatessen',
    'public_market',
    'farmers_market',
    'marketplace',
  ];

  static const Duration _defaultTimeout = Duration(seconds: 8);
  static const Duration _cacheTtl = Duration(minutes: 5);
  static const int _maxCacheEntries = 40;

  final String _apiKey;
  final http.Client _httpClient;
  final Duration _timeout;
  final bool _ownsClient;

  final Map<String, _CacheEntry> _cache = {};

  TomTomService({
    String? apiKey,
    http.Client? httpClient,
    Duration timeout = _defaultTimeout,
  })  : _apiKey = (apiKey ?? _apiKeyFromEnvironment()).trim(),
        _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _timeout = timeout;

  static String _apiKeyFromEnvironment() {
    return const String.fromEnvironment('TOMTOM_API_KEY', defaultValue: '');
  }

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Busca mercados próximos a [latitude]/[longitude].
  ///
  /// Usa o endpoint `discover` com filtro circular e tipos de POI de mercado.
  /// Retorna lista vazia (sem lançar) quando a chave não está configurada,
  /// porque este é sempre um caminho de fallback.
  Future<List<TomTomPlace>> searchNearby({
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
    int limit = 20,
  }) async {
    if (!isConfigured) return const [];

    final radius = radiusMeters.clamp(100, 50000).round();
    final cacheKey = 'nearby:'
        '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)},'
        '$radius,$limit';

    final cached = _readCache(cacheKey);
    if (cached != null) return cached;

    final body = <String, dynamic>{
      'query': 'supermercado',
      'origin': _point(latitude, longitude),
      'preferences': {'geometry': _point(latitude, longitude)},
      'maxResults': limit.clamp(1, 100),
      'filters': {
        'types': ['poi'],
        'countryCodesIso2': ['BR'],
        'poiTypes': marketPoiTypes,
        'geometry': {
          'type': 'circle',
          // A API exige o centro como par [longitude, latitude].
          'center': [longitude, latitude],
          'radiusInMeters': radius,
        },
      },
    };

    final results = await _post(body, cacheKey: cacheKey);
    final places = results
        .where((place) => place.id.isNotEmpty && place.nome.isNotEmpty)
        .toList(growable: false);

    _writeCache(cacheKey, places);
    return places;
  }

  /// Busca mercados por nome (usada na pesquisa manual do BottomSheet).
  ///
  /// Quando [latitude]/[longitude] são informados, a busca é ancorada no ponto
  /// atual e restrita a um círculo de [radiusMeters]. Sem esse filtro a TomTom
  /// devolve redes de outras cidades/estados, o que confundia o utilizador.
  Future<List<TomTomPlace>> searchByName(
    String query, {
    double? latitude,
    double? longitude,
    double radiusMeters = 5000,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (!isConfigured || trimmed.length < 2) return const [];

    final hasOrigin = latitude != null && longitude != null;
    final radius = radiusMeters.clamp(100, 50000).round();

    final cacheKey = 'name:${trimmed.toLowerCase()}:'
        '${latitude?.toStringAsFixed(3) ?? '-'},'
        '${longitude?.toStringAsFixed(3) ?? '-'}:$radius:$limit';

    final cached = _readCache(cacheKey);
    if (cached != null) return cached;

    final origin = hasOrigin ? _point(latitude, longitude) : null;

    final body = <String, dynamic>{
      'query': trimmed,
      'maxResults': limit.clamp(1, 100),
      'filters': {
        'types': ['poi'],
        'countryCodesIso2': ['BR'],
        // Sem o filtro de categoria a busca por nome devolve farmácias e
        // postos com a mesma marca (ex.: "Drogaria Carrefour").
        'poiTypes': marketPoiTypes,
        // Âncora + raio: limita a busca à região real do utilizador.
        if (hasOrigin)
          'geometry': {
            'type': 'circle',
            'center': [longitude, latitude],
            'radiusInMeters': radius,
          },
      },
      if (origin != null) ...{
        'origin': origin,
        'preferences': {'geometry': origin},
      },
    };

    final results = await _post(body, cacheKey: cacheKey);
    final filtered = results
        .where((place) => place.id.isNotEmpty && place.nome.isNotEmpty)
        .toList()
      ..sort(_byDistance);

    _writeCache(cacheKey, filtered);
    return filtered;
  }

  /// Libera o `http.Client` apenas quando ele foi criado internamente.
  void dispose() {
    _cache.clear();
    if (_ownsClient) _httpClient.close();
  }

  // ==================== Helpers ====================

  static Map<String, dynamic> _point(double latitude, double longitude) {
    return {
      'type': 'point',
      'coordinates': [longitude, latitude],
    };
  }

  /// Mais próximos primeiro; resultados sem distância vão para o fim.
  static int _byDistance(TomTomPlace a, TomTomPlace b) {
    return (a.distanciaMetros ?? double.infinity)
        .compareTo(b.distanciaMetros ?? double.infinity);
  }

  Future<List<TomTomPlace>> _post(
    Map<String, dynamic> body, {
    required String cacheKey,
  }) async {
    final uri = Uri.parse('$_baseUrl/discover');

    http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'TomTom-Api-Key': _apiKey,
              'TomTom-Api-Version': '3',
              // Obrigatório na v3: sem este header a API responde 400.
              'Attributes': 'results',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Accept-Language': 'pt-BR',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const TomTomServiceException(
        'A busca de mercados demorou demais para responder.',
      );
    } on Exception catch (error) {
      debugPrint('[TomTomService] falha de rede: $error');
      throw const TomTomServiceException(
        'Não foi possível consultar a TomTom agora.',
      );
    }

    if (response.statusCode != 200) {
      throw _errorFrom(response);
    }

    try {
      final decoded = jsonDecode(response.body);
      final results =
          decoded is Map<String, dynamic> ? decoded['results'] : null;
      if (results is! List) return const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map(TomTomPlace.fromJson)
          .toList(growable: false);
    } on FormatException catch (error) {
      debugPrint('[TomTomService] resposta inválida ($cacheKey): $error');
      throw const TomTomServiceException(
        'A TomTom devolveu uma resposta inesperada.',
      );
    }
  }

  TomTomServiceException _errorFrom(http.Response response) {
    String? code;
    String? detail;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['detailedError'];
        if (error is Map<String, dynamic>) {
          code = error['code']?.toString();
          detail = error['message']?.toString();
        }
      }
    } catch (_) {
      // Corpo não-JSON: mantém a mensagem genérica.
    }

    final message = switch (response.statusCode) {
      400 => 'A busca de mercados enviou dados inválidos.',
      401 || 403 => 'Chave da TomTom inválida ou sem permissão.',
      404 => 'Serviço de busca da TomTom não encontrado.',
      429 => 'Muitas buscas em pouco tempo. Tente novamente em instantes.',
      >= 500 => 'A TomTom está indisponível no momento.',
      _ =>
        detail ?? 'Falha ao consultar a TomTom (HTTP ${response.statusCode}).',
    };

    debugPrint(
      '[TomTomService] HTTP ${response.statusCode} '
      'code=$code detail=$detail',
    );

    return TomTomServiceException(
      message,
      statusCode: response.statusCode,
      code: code,
    );
  }

  List<TomTomPlace>? _readCache(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.createdAt) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }
    return entry.places;
  }

  void _writeCache(String key, List<TomTomPlace> places) {
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CacheEntry(places);
  }
}

class _CacheEntry {
  final List<TomTomPlace> places;
  final DateTime createdAt = DateTime.now();

  _CacheEntry(this.places);
}
