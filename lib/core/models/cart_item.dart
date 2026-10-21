import 'package:equatable/equatable.dart';

/// How the item is priced inside the cart.
///
/// [unit] keeps the physical label (`un`, `L`, `ml`, ...). [weight] always
/// prices by kilogram and stores the chosen weight in [CartItem.weightKg].
enum CartItemKind { unit, weight }

/// Represents an item in the shopping cart
class CartItem extends Equatable {
  final String id;
  final String name;
  final String? brand;
  final String? ean;

  /// Unit price for [CartItemKind.unit], or price per kilogram for
  /// [CartItemKind.weight].
  final double unitPrice;
  final int quantity;
  final String unit; // 'un', 'kg', 'g', 'L', 'ml'
  final CartItemKind kind;

  /// Weight in kilograms. Only used when [kind] is [CartItemKind.weight].
  final double weightKg;
  final double totalPrice;
  final DateTime addedAt;
  final ScanSource source;

  /// Local absolute path of the shelf-label proof photo.
  final String? photoPath;
  final Map<String, dynamic>? rawOcrData; // Debug/audit data

  const CartItem({
    required this.id,
    required this.name,
    this.brand,
    this.ean,
    required this.unitPrice,
    required this.quantity,
    required this.unit,
    this.kind = CartItemKind.unit,
    this.weightKg = 0,
    required this.totalPrice,
    required this.addedAt,
    required this.source,
    this.photoPath,
    this.rawOcrData,
  });

  bool get isByWeight => kind == CartItemKind.weight;

  /// Quantity effectively multiplied by [unitPrice] for the line total.
  double get effectiveQuantity => isByWeight ? weightKg : quantity.toDouble();

  /// Recomputed line total. The stored [totalPrice] must match this value.
  double get calculatedTotal => unitPrice * effectiveQuantity;

  /// Number of physical entries this line represents in summaries.
  int get itemCount => isByWeight ? 1 : quantity;

  /// Unit shown next to the price. Weighted items always use kilograms.
  String get priceUnit => isByWeight ? 'kg' : unit;

  CartItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? ean,
    double? unitPrice,
    int? quantity,
    String? unit,
    CartItemKind? kind,
    double? weightKg,
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
      kind: kind ?? this.kind,
      weightKg: weightKg ?? this.weightKg,
      totalPrice: totalPrice ?? this.totalPrice,
      addedAt: addedAt ?? this.addedAt,
      source: source ?? this.source,
      photoPath: photoPath ?? this.photoPath,
      rawOcrData: rawOcrData ?? this.rawOcrData,
    );
  }

  /// Returns a copy with a line total consistent with the current price and
  /// quantity/weight. Use this whenever price, quantity or kind changes.
  CartItem withCalculatedTotal() {
    return copyWith(totalPrice: calculatedTotal);
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
        kind,
        weightKg,
        totalPrice,
        addedAt,
        source,
        photoPath,
        rawOcrData,
      ];
}

/// Source of the scan
enum ScanSource { camera, voice, manual }
