import 'package:equatable/equatable.dart';

/// Uma compra finalizada, salva no histórico local.
class Purchase extends Equatable {
  final String id;
  final String storeName;

  /// ID remoto do mercado (`mercados.id`), quando disponível.
  final String? marketId;
  final DateTime date;
  final List<PurchaseItem> items;

  /// Economia identificada pelos alertas da comunidade durante a compra.
  final double savings;

  const Purchase({
    required this.id,
    required this.storeName,
    this.marketId,
    required this.date,
    required this.items,
    this.savings = 0,
  });

  double get total => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  int get itemCount => items.fold(0, (sum, item) => sum + item.itemCount);

  int get uniqueItems => items.length;

  Purchase copyWith({
    String? id,
    String? storeName,
    String? marketId,
    DateTime? date,
    List<PurchaseItem>? items,
    double? savings,
  }) {
    return Purchase(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      marketId: marketId ?? this.marketId,
      date: date ?? this.date,
      items: items ?? this.items,
      savings: savings ?? this.savings,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'storeName': storeName,
        'marketId': marketId,
        'date': date.toIso8601String(),
        'savings': savings,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory Purchase.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List? ?? const []);
    return Purchase(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      storeName: json['storeName'] as String? ?? 'Mercado',
      marketId: json['marketId'] as String?,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      savings: (json['savings'] as num?)?.toDouble() ?? 0,
      items: rawItems
          .map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, storeName, marketId, date, items, savings];
}

/// Item de uma compra finalizada (snapshot do carrinho).
class PurchaseItem extends Equatable {
  final String name;
  final String unit;
  final double unitPrice;
  final int quantity;

  /// Weight in kilograms for items sold by weight. When present, [unitPrice]
  /// is the price per kg and [quantity] remains 1 for compatibility.
  final double? weightKg;

  const PurchaseItem({
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.unit = 'un',
    this.weightKg,
  });

  bool get isByWeight => weightKg != null;

  int get itemCount => isByWeight ? 1 : quantity;

  double get effectiveQuantity => isByWeight ? weightKg! : quantity.toDouble();

  double get totalPrice => unitPrice * effectiveQuantity;

  PurchaseItem copyWith({
    String? name,
    String? unit,
    double? unitPrice,
    int? quantity,
    double? weightKg,
  }) {
    return PurchaseItem(
      name: name ?? this.name,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      weightKg: weightKg ?? this.weightKg,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit,
        'unitPrice': unitPrice,
        'quantity': quantity,
        if (weightKg != null) 'weightKg': weightKg,
      };

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        name: json['name'] as String? ?? 'Item',
        unit: json['unit'] as String? ?? 'un',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [name, unit, unitPrice, quantity, weightKg];
}
