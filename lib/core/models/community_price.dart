import 'package:equatable/equatable.dart';

/// Community price alert from nearby stores
class CommunityPriceAlert extends Equatable {
  final String productName;
  final String storeName;
  final String storeChain;
  final double communityPrice;
  final double unitPrice;
  final double distanceKm;
  final DateTime capturedAt;
  final int confirmationCount;
  final double savings;
  final double savingsPercentage;

  const CommunityPriceAlert({
    required this.productName,
    required this.storeName,
    required this.storeChain,
    required this.communityPrice,
    required this.unitPrice,
    required this.distanceKm,
    required this.capturedAt,
    required this.confirmationCount,
    required this.savings,
    required this.savingsPercentage,
  });

  factory CommunityPriceAlert.fromRpc(Map<String, dynamic> json) {
    return CommunityPriceAlert(
      productName: json['product_name'] as String,
      storeName: json['store_name'] as String,
      storeChain: json['store_chain'] as String? ?? '',
      communityPrice: (json['price'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num).toDouble(),
      capturedAt: DateTime.parse(json['captured_at'] as String),
      confirmationCount: json['confirmation_count'] as int,
      savings: (json['savings'] as num).toDouble(),
      savingsPercentage: (json['savings_pct'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_name': productName,
      'store_name': storeName,
      'store_chain': storeChain,
      'price': communityPrice,
      'unit_price': unitPrice,
      'distance_km': distanceKm,
      'captured_at': capturedAt.toIso8601String(),
      'confirmation_count': confirmationCount,
      'savings': savings,
      'savings_pct': savingsPercentage,
    };
  }

  @override
  List<Object?> get props => [
        productName,
        storeName,
        storeChain,
        communityPrice,
        unitPrice,
        distanceKm,
        capturedAt,
        confirmationCount,
        savings,
        savingsPercentage,
      ];
}

/// Store/Supermarket model
class Store extends Equatable {
  final String id;
  final String name;
  final String? chain;
  final double latitude;
  final double longitude;
  final String? address;
  final bool verified;
  final DateTime createdAt;

  const Store({
    required this.id,
    required this.name,
    this.chain,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.verified,
    required this.createdAt,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    final lat = _asDouble(json['latitude']);
    final lng = _asDouble(json['longitude']);
    return Store(
      id: json['id'] as String,
      name: (json['name'] ?? json['nome'] ?? 'Mercado') as String,
      chain: json['chain'] as String?,
      latitude: lat ?? 0,
      longitude: lng ?? 0,
      address: (json['address'] ?? json['endereco']) as String?,
      verified: (json['verified'] ?? json['verificado'] ?? false) as bool,
      createdAt: DateTime.tryParse(
            (json['created_at'] ?? json['criado_em'] ?? '') as String,
          ) ??
          DateTime.now(),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'chain': chain,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'verified': verified,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        chain,
        latitude,
        longitude,
        address,
        verified,
        createdAt,
      ];
}

/// Product catalog model
class Product extends Equatable {
  final String id;
  final String? ean;
  final String name;
  final String? brand;
  final String? category;
  final String? unit;
  final DateTime createdAt;

  const Product({
    required this.id,
    this.ean,
    required this.name,
    this.brand,
    this.category,
    this.unit,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      ean: json['ean'] as String?,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      category: json['category'] as String?,
      unit: json['unit'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ean': ean,
      'name': name,
      'brand': brand,
      'category': category,
      'unit': unit,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, ean, name, brand, category, unit, createdAt];
}
