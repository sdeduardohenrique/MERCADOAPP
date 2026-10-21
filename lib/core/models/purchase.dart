import 'package:equatable/equatable.dart';

/// Uma compra finalizada, salva no histórico local.
class Purchase extends Equatable {
  final String id;
  final String storeName;
  final DateTime date;
  final List<PurchaseItem> items;

  /// Economia identificada pelos alertas da comunidade durante a compra.
  final double savings;

  const Purchase({
    required this.id,
    required this.storeName,
    required this.date,
    required this.items,
    this.savings = 0,
  });

  double get total => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  int get uniqueItems => items.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'storeName': storeName,
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
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      savings: (json['savings'] as num?)?.toDouble() ?? 0,
      items: rawItems
          .map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, storeName, date, items, savings];
}

/// Item de uma compra finalizada (snapshot do carrinho).
class PurchaseItem extends Equatable {
  final String name;
  final String unit;
  final double unitPrice;
  final int quantity;

  const PurchaseItem({
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.unit = 'un',
  });

  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        name: json['name'] as String? ?? 'Item',
        unit: json['unit'] as String? ?? 'un',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );

  @override
  List<Object?> get props => [name, unit, unitPrice, quantity];
}
