import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/community_offer.dart';
import '../../../core/services/supabase_service.dart';

class CommunityServiceException implements Exception {
  final String message;

  const CommunityServiceException(this.message);

  @override
  String toString() => message;
}

typedef CommunityOffersFetcher = Future<List<CommunityOffer>> Function({
  double? latitude,
  double? longitude,
  required double radiusKm,
  String? city,
  String? query,
  int limit,
});

typedef CommunityOfferPublisher = Future<String> Function({
  required String productName,
  required double price,
  required String marketId,
  String? ean,
  double? oldPrice,
  String? unit,
  String? imageUrl,
  String? contributorName,
});

typedef OfferPhotoUploader = Future<String> Function({
  required Uint8List bytes,
  required String contentType,
  required String extension,
});

/// Acesso às ofertas comunitárias.
///
/// A leitura usa PostGIS/RPC para trazer distância e endereço já resolvidos.
/// A publicação resolve/cria o produto e insere o preço numa única função
/// atômica, evitando registros de oferta incompletos.
class CommunityService {
  CommunityService({
    CommunityOffersFetcher? offersFetcher,
    CommunityOfferPublisher? publisher,
    OfferPhotoUploader? photoUploader,
  })  : _offersFetcher = offersFetcher,
        _publisher = publisher,
        _photoUploader = photoUploader;

  final CommunityOffersFetcher? _offersFetcher;
  final CommunityOfferPublisher? _publisher;
  final OfferPhotoUploader? _photoUploader;

  Future<List<CommunityOffer>> listOffers({
    double? latitude,
    double? longitude,
    double radiusKm = 10,
    String? city,
    String? query,
    int limit = 30,
  }) async {
    final fetcher = _offersFetcher;
    if (fetcher != null) {
      return fetcher(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        city: city,
        query: query,
        limit: limit,
      );
    }

    if (!SupabaseService.isReady) {
      throw const CommunityServiceException(
        'Sem conexão com a comunidade. Verifique a internet e tente novamente.',
      );
    }

    try {
      final response = await SupabaseService.client.rpc(
        'listar_ofertas_comunidade',
        params: {
          'p_lat': latitude,
          'p_lng': longitude,
          'p_raio_km': radiusKm,
          'p_cidade': _clean(city),
          'p_query': _clean(query),
          'p_limit': limit,
        },
      );

      if (response == null) return const [];
      return (response as List)
          .whereType<Map<String, dynamic>>()
          .map(CommunityOffer.fromRpc)
          .toList();
    } on CommunityServiceException {
      rethrow;
    } catch (_) {
      throw const CommunityServiceException(
        'Não foi possível carregar as ofertas agora. Tente novamente.',
      );
    }
  }

  Future<String> createOffer({
    required String productName,
    required double price,
    required String marketId,
    String? ean,
    double? oldPrice,
    String? unit,
    String? imageUrl,
    String? contributorName,
  }) async {
    final publisher = _publisher;
    if (publisher != null) {
      return publisher(
        productName: productName,
        price: price,
        marketId: marketId,
        ean: ean,
        oldPrice: oldPrice,
        unit: unit,
        imageUrl: imageUrl,
        contributorName: contributorName,
      );
    }

    if (!SupabaseService.isReady) {
      throw const CommunityServiceException(
        'É preciso conexão para publicar uma oferta.',
      );
    }

    try {
      final response = await SupabaseService.client.rpc(
        'publicar_oferta_comunidade',
        params: {
          'p_produto_nome': productName.trim(),
          'p_preco': price,
          'p_preco_antigo': oldPrice,
          'p_unidade': _clean(unit) ?? 'un',
          'p_mercado_id': marketId,
          'p_imagem_url': _clean(imageUrl),
          'p_contribuidor': _clean(contributorName),
          'p_ean': _clean(ean),
        },
      );
      return response.toString();
    } catch (error) {
      if (error is CommunityServiceException) rethrow;
      throw const CommunityServiceException(
        'Não foi possível publicar a oferta. Tente novamente.',
      );
    }
  }

  Future<String> uploadOfferPhoto({
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    final uploader = _photoUploader;
    if (uploader != null) {
      return uploader(
        bytes: bytes,
        contentType: contentType,
        extension: extension,
      );
    }

    if (!SupabaseService.isReady) {
      throw const CommunityServiceException(
        'É preciso conexão para enviar a foto da oferta.',
      );
    }

    final cleanExtension = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final path = 'ofertas/${DateTime.now().year}/'
        '${const Uuid().v4()}.${cleanExtension.isEmpty ? 'jpg' : cleanExtension}';

    try {
      await SupabaseService.client.storage.from('ofertas_storage').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              cacheControl: '3600',
              upsert: false,
            ),
          );
      return SupabaseService.client.storage
          .from('ofertas_storage')
          .getPublicUrl(path);
    } catch (_) {
      throw const CommunityServiceException(
        'Não foi possível enviar a foto. Tente novamente.',
      );
    }
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService();
});
