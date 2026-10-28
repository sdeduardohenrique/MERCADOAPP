import 'package:equatable/equatable.dart';

import 'shopping_sector.dart';

/// Ícones (emojis) disponíveis para personalizar cada lista.
const List<String> shoppingListIcons = [
  '🛒',
  '🧺',
  '🥬',
  '🥩',
  '🥛',
  '🧹',
  '🥫',
  '🍞',
  '🎉',
  '📦',
  '🏠',
  '🍺',
];

String normalizeShoppingListIcon(String? value) {
  if (value == null || value.trim().isEmpty) return shoppingListIcons.first;
  return value;
}

/// Uma lista de compras (ex.: Feira da Semana, Churrasco de Domingo).
class ShoppingList extends Equatable {
  final String id;
  final String name;
  final String icon;
  final List<ShoppingListItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingList({
    required this.id,
    required this.name,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  int get totalItems => items.length;

  int get boughtItems => items.where((item) => item.isBought).length;

  int get pendingItems => totalItems - boughtItems;

  double get progress => totalItems == 0 ? 0 : boughtItems / totalItems;

  bool get hasEstimates => items.any((item) => item.estimatedPrice != null);

  /// Soma quantidade × preço estimado de cada item.
  double get estimatedTotal => items.fold<double>(
        0,
        (sum, item) => sum + item.estimatedTotal,
      );

  List<ShoppingListItem> get pending =>
      items.where((item) => !item.isBought).toList();

  List<ShoppingListItem> get bought =>
      items.where((item) => item.isBought).toList();

  List<ShoppingListItem> itemsForSector(ShoppingSector sector) =>
      items.where((item) => item.sector == sector).toList();

  ShoppingList copyWith({
    String? name,
    String? icon,
    List<ShoppingListItem>? items,
    DateTime? updatedAt,
  }) {
    return ShoppingList(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
      };

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now().toUtc();
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => ShoppingListItem.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList()
        : <ShoppingListItem>[];

    return ShoppingList(
      id: json['id'] as String? ?? createdAt.microsecondsSinceEpoch.toString(),
      name: (json['name'] as String? ?? '').trim().isEmpty
          ? 'Minha Lista'
          : (json['name'] as String).trim(),
      icon: normalizeShoppingListIcon(json['icon'] as String?),
      items: items,
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? createdAt,
    );
  }

  factory ShoppingList.fromRemote(
    Map<String, dynamic> json, {
    required List<ShoppingListItem> items,
  }) {
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now().toUtc();
    return ShoppingList(
      id: json['id'] as String? ?? createdAt.microsecondsSinceEpoch.toString(),
      name: (json['name'] as String? ?? '').trim().isEmpty
          ? 'Minha Lista'
          : (json['name'] as String).trim(),
      icon: normalizeShoppingListIcon(json['icon'] as String?),
      items: items,
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ?? createdAt,
    );
  }

  /// Payload de upsert para `listas_compras`.
  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'name': name,
        'icon': icon,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name, icon, items, createdAt, updatedAt];
}

/// Um item dentro de uma lista, com quantidade, unidade, setor e preço
/// estimado opcional.
class ShoppingListItem extends Equatable {
  static const Object _notSet = Object();

  final String id;
  final String listId;
  final String name;
  final double quantity;
  final String unit;
  final double? estimatedPrice;
  final ShoppingSector sector;
  final bool isBought;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingListItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.quantity = 1,
    this.unit = 'un',
    this.estimatedPrice,
    this.sector = ShoppingSector.outros,
    this.isBought = false,
  });

  double get estimatedTotal => (estimatedPrice ?? 0) * quantity;

  ShoppingListItem copyWith({
    String? listId,
    String? name,
    double? quantity,
    String? unit,
    Object? estimatedPrice = _notSet,
    ShoppingSector? sector,
    bool? isBought,
    DateTime? updatedAt,
  }) {
    return ShoppingListItem(
      id: id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      estimatedPrice: identical(estimatedPrice, _notSet)
          ? this.estimatedPrice
          : estimatedPrice as double?,
      sector: sector ?? this.sector,
      isBought: isBought ?? this.isBought,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listId': listId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'estimatedPrice': estimatedPrice,
        'sector': sector.id,
        'isBought': isBought,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now().toUtc();
    return ShoppingListItem(
      id: json['id'] as String? ?? createdAt.microsecondsSinceEpoch.toString(),
      listId: json['listId'] as String? ?? '',
      name: (json['name'] as String? ?? 'Item').trim(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: normalizeShoppingUnit(json['unit'] as String?),
      estimatedPrice: (json['estimatedPrice'] as num?)?.toDouble(),
      sector: ShoppingSector.fromId(json['sector'] as String?),
      isBought: json['isBought'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? createdAt,
    );
  }

  factory ShoppingListItem.fromRemote(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now().toUtc();
    return ShoppingListItem(
      id: json['id'] as String? ?? createdAt.microsecondsSinceEpoch.toString(),
      listId: json['list_id'] as String? ?? '',
      name: (json['name'] as String? ?? 'Item').trim(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: normalizeShoppingUnit(json['unit'] as String?),
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble(),
      sector: ShoppingSector.fromId(json['sector'] as String?),
      isBought: json['is_bought'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ?? createdAt,
    );
  }

  /// Payload de upsert para `itens_lista`.
  Map<String, dynamic> toRemote(String userId) => {
        'id': id,
        'user_id': userId,
        'list_id': listId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'estimated_price': estimatedPrice,
        'sector': sector.id,
        'is_bought': isBought,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        listId,
        name,
        quantity,
        unit,
        estimatedPrice,
        sector,
        isBought,
        createdAt,
        updatedAt,
      ];
}
