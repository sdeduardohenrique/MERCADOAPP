import 'package:equatable/equatable.dart';

/// Represents an item in the shopping cart
class CartItem extends Equatable {
  final String id;
  final String name;
  final String? brand;
  final String? ean;
  final double unitPrice;
  final int quantity;
  final String unit; // 'un', 'kg', 'g', 'L', 'ml'
  final double totalPrice;
  final DateTime addedAt;
  final ScanSource source;
  final String? photoPath; // Supabase Storage path
  final Map<String, dynamic>? rawOcrData; // Debug/audit data

  const CartItem({
    required this.id,
    required this.name,
    this.brand,
    this.ean,
    required this.unitPrice,
    required this.quantity,
    required this.unit,
    required this.totalPrice,
    required this.addedAt,
    required this.source,
    this.photoPath,
    this.rawOcrData,
  });

  CartItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? ean,
    double? unitPrice,
    int? quantity,
    String? unit,
    double? totalPrice,
    DateTime? addedAt,
    ScanSource? source,
    String? photoPath,
    Map<String, dynamic>? rawOcrData,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      ean: ean ?? this.ean,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      totalPrice: totalPrice ?? this.totalPrice,
      addedAt: addedAt ?? this.addedAt,
      source: source ?? this.source,
      photoPath: photoPath ?? this.photoPath,
      rawOcrData: rawOcrData ?? this.rawOcrData,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        brand,
        ean,
        unitPrice,
        quantity,
        unit,
        totalPrice,
        addedAt,
        source,
        photoPath,
        rawOcrData,
      ];
}

/// Source of the scan
enum ScanSource { camera, voice, manual }
