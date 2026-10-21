import 'package:equatable/equatable.dart';

/// Oferta publicada pela comunidade, já enriquecida com o mercado e o endereço.
///
/// Todos os campos opcionais são tratados na UI: uma oferta antiga pode ter
/// sido criada antes de existir foto, endereço ou preço anterior.
class CommunityOffer extends Equatable {
  final String id;
  final String productName;
  final String? brand;
  final String? marketId;
  final String marketName;
  final String? marketChain;
  final double price;
  final double? oldPrice;
  final String unit;
  final String? imageUrl;
  final double? distanceKm;
  final DateTime capturedAt;
  final int confirmations;
  final String? address;
  final String? neighborhood;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? contributorName;
  final bool isPromo;

  const CommunityOffer({
    required this.id,
    required this.productName,
    required this.marketName,
    required this.price,
    required this.unit,
    required this.capturedAt,
    this.brand,
    this.marketId,
    this.marketChain,
    this.oldPrice,
    this.imageUrl,
    this.distanceKm,
    this.confirmations = 0,
    this.address,
    this.neighborhood,
    this.city,
    this.latitude,
    this.longitude,
    this.contributorName,
    this.isPromo = false,
  });

  factory CommunityOffer.fromRpc(Map<String, dynamic> json) {
    return CommunityOffer(
      id: (json['id'] ?? '').toString(),
      productName: _string(json['product_name']) ?? 'Produto',
      brand: _string(json['brand']),
      marketId: _string(json['store_id']),
      marketName: _string(json['store_name']) ?? 'Mercado',
      marketChain: _string(json['store_chain']),
      price: _double(json['price']) ?? 0,
      oldPrice: _double(json['old_price']),
      unit: _string(json['unit']) ?? 'un',
      imageUrl: _string(json['image_url']),
      distanceKm: _double(json['distance_km']),
      capturedAt: DateTime.tryParse(
            (json['captured_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      confirmations: _int(json['confirmation_count']) ?? 0,
      address: _string(json['endereco']),
      neighborhood: _string(json['bairro']),
      city: _string(json['cidade']),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      contributorName: _string(json['contributor_name']),
      isPromo: json['is_promo'] == true,
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  bool get hasCoordinates => latitude != null && longitude != null;

  double get savings =>
      oldPrice != null && oldPrice! > price ? oldPrice! - price : 0;

  double get savingsPercentage {
    if (oldPrice == null || oldPrice! <= 0 || savings <= 0) return 0;
    return (savings / oldPrice!) * 100;
  }

  String get unitLabel => unit.trim().isEmpty ? 'un' : unit.trim();

  String get distanceLabel {
    final km = distanceKm;
    if (km == null) return '';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  String get contributorInitials {
    final name = contributorName?.trim() ?? '';
    if (name.isEmpty) return 'SA';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String get confirmationsLabel {
    if (confirmations <= 0) return 'Ainda sem confirmações';
    if (confirmations == 1) return '1 confirmação';
    return '$confirmations confirmações';
  }

  String get contributorLabel {
    final name = contributorName?.trim();
    return name == null || name.isEmpty ? 'Vizinho do SomaAí' : name;
  }

  String get ageLabel {
    final diff = DateTime.now().difference(capturedAt);
    if (diff.isNegative || diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    if (diff.inDays == 1) return 'há 1 dia';
    return 'há ${diff.inDays} dias';
  }

  /// Endereço completo sem repetir partes vazias/iguais.
  String get fullAddress {
    final parts = <String>[];
    for (final value in [address, neighborhood, city]) {
      final clean = value?.trim();
      if (clean == null || clean.isEmpty) continue;
      if (!parts.any((part) => part.toLowerCase() == clean.toLowerCase())) {
        parts.add(clean);
      }
    }
    return parts.join(', ');
  }

  String get marketLabel {
    final chain = marketChain?.trim();
    if (chain == null ||
        chain.isEmpty ||
        chain.toLowerCase() == marketName.toLowerCase()) {
      return marketName;
    }
    return '$marketName • $chain';
  }

  String? get mapDestination {
    if (hasCoordinates) {
      return '${latitude!.toStringAsFixed(6)},'
          '${longitude!.toStringAsFixed(6)}';
    }
    final location = fullAddress;
    return location.isEmpty ? null : location;
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
        id,
        productName,
        brand,
        marketId,
        marketName,
        marketChain,
        price,
        oldPrice,
        unit,
        imageUrl,
        distanceKm,
        capturedAt,
        confirmations,
        address,
        neighborhood,
        city,
        latitude,
        longitude,
        contributorName,
        isPromo,
      ];
}
