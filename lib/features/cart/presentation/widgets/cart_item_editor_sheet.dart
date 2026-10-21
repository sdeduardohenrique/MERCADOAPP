import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/cart_item.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/price_parser.dart';

/// Shared add/edit sheet for cart items.
///
/// The sheet only builds and validates the [CartItem]. The caller decides
/// whether to add it to the cart or replace an existing line, keeping the
/// Riverpod mutation in a single place.
Future<CartItem?> showCartItemEditorSheet(
  BuildContext context, {
  CartItem? initialItem,
  String? title,
  String? subtitle,
  String? submitLabel,
}) {
  return showModalBottomSheet<CartItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CartItemEditorSheet(
      initialItem: initialItem,
      title: title,
      subtitle: subtitle,
      submitLabel: submitLabel,
    ),
  );
}

class CartItemEditorSheet extends StatefulWidget {
  final CartItem? initialItem;
  final String? title;
  final String? subtitle;
  final String? submitLabel;

  const CartItemEditorSheet({
    super.key,
    this.initialItem,
    this.title,
    this.subtitle,
    this.submitLabel,
  });

  @override
  State<CartItemEditorSheet> createState() => _CartItemEditorSheetState();
}

class _CartItemEditorSheetState extends State<CartItemEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _weightController;
  late CartItemKind _kind;
  late int _quantity;

  bool get _editing => widget.initialItem != null;
  bool get _isWeight => _kind == CartItemKind.weight;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialItem;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _priceController = TextEditingController(
      text: initial == null
          ? ''
          : initial.unitPrice.toStringAsFixed(2).replaceAll('.', ','),
    );
    _kind = initial?.kind ?? CartItemKind.unit;
    _quantity = initial?.quantity ?? 1;
    final initialWeight =
        initial != null && initial.isByWeight ? initial.weightKg : 1.0;
    _weightController = TextEditingController(
      text: Formatters.weightInput(initialWeight <= 0 ? 1 : initialWeight),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  double? get _price => _parsePriceInput(_priceController.text);
  double? get _weight => _parseWeight(_weightController.text);
  double get _subtotal {
    final price = _price;
    if (price == null) return 0;
    return price * (_isWeight ? (_weight ?? 0) : _quantity);
  }

  /// Accepts user-friendly input such as `5`, `5,9` or `5.9` and normalizes it
  /// to the strict two-decimal contract of [PriceParser.parsePrice].
  double? _parsePriceInput(String raw) {
    final strict = PriceParser.parsePrice(raw);
    if (strict != null) return strict;

    var value = raw.replaceAll(RegExp(r'[^\d.,]'), '');
    if (value.isEmpty) return null;
    if (RegExp(r',\d$').hasMatch(value)) {
      value = '${value}0';
    } else if (RegExp(r'\.\d$').hasMatch(value)) {
      value = '${value}0';
    } else if (!value.contains(',') && !value.contains('.')) {
      value = '$value,00';
    }
    return PriceParser.parsePrice(value);
  }

  double? _parseWeight(String raw) {
    var value = raw.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    if (value.isEmpty) return null;
    final parsed = double.tryParse(value);
    if (parsed == null || parsed < 0.01 || parsed > 100) return null;
    return double.parse(parsed.toStringAsFixed(3));
  }

  void _setWeight(double value) {
    setState(() {
      _weightController.text = Formatters.weightInput(value);
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = _price;
    if (price == null || price <= 0) return;

    final weight = _isWeight ? _weight : null;
    if (_isWeight && weight == null) return;

    final initial = widget.initialItem;
    final item = CartItem(
      id: initial?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      brand: initial?.brand,
      ean: initial?.ean,
      unitPrice: price,
      quantity: _isWeight ? 1 : _quantity,
      unit: _isWeight ? 'kg' : (initial?.unit ?? 'un'),
      kind: _kind,
      weightKg: weight ?? 0,
      totalPrice: 0,
      addedAt: initial?.addedAt ?? DateTime.now(),
      source: initial?.source ?? ScanSource.manual,
      photoPath: initial?.photoPath,
      rawOcrData: initial?.rawOcrData,
    ).withCalculatedTotal();

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    final title = widget.title ??
        (_editing ? 'Editar item' : 'Adicionar item manualmente');
    final subtitle = widget.subtitle ??
        (_editing
            ? 'Ajuste o nome, o preço e a quantidade ou o peso.'
            : 'Digite o produto e o preço da etiqueta.');

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: AppTheme.floatingShadow,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.line,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppTheme.emeraldTint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _editing
                            ? Icons.edit_rounded
                            : Icons.add_shopping_cart_rounded,
                        color: AppTheme.emeraldDark,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('cart_item_name'),
                  controller: _nameController,
                  autofocus: !_editing,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Produto',
                    hintText: 'Ex.: Leite integral 1L',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome do produto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Como este item é cobrado?',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 7),
                SegmentedButton<CartItemKind>(
                  key: const Key('cart_item_kind'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: CartItemKind.unit,
                      icon: Icon(Icons.inventory_2_outlined, size: 17),
                      label: Text('Por unidade'),
                    ),
                    ButtonSegment(
                      value: CartItemKind.weight,
                      icon: Icon(Icons.scale_rounded, size: 17),
                      label: Text('Por peso (kg)'),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (selection) {
                    setState(() => _kind = selection.first);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('cart_item_price'),
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _isWeight ? 'Preço por kg' : 'Preço unitário',
                    prefixText: r'R$ ',
                    hintText: '0,00',
                  ),
                  validator: (value) {
                    final price = _parsePriceInput(value ?? '');
                    if (price == null || price <= 0) {
                      return 'Preço inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                if (_isWeight) ...[
                  TextFormField(
                    key: const Key('cart_item_weight'),
                    controller: _weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Peso',
                      suffixText: 'kg',
                      hintText: '0,500',
                      helperText: 'Use 0,500 para 500 g. Passo rápido: 100 g.',
                    ),
                    validator: (value) {
                      if (!_isWeight) return null;
                      return _parseWeight(value ?? '') == null
                          ? 'Peso inválido (0,01 a 100 kg)'
                          : null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      (0.25, '250 g'),
                      (0.5, '500 g'),
                      (0.75, '750 g'),
                      (1.0, '1 kg'),
                    ]
                        .map(
                          (preset) => ChoiceChip(
                            label: Text(preset.$2),
                            selected:
                                ((_weight ?? 0) - preset.$1).abs() < 0.001,
                            onSelected: (_) => _setWeight(preset.$1),
                            labelStyle: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Quantidade',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      _EditorStepper(
                        quantity: _quantity,
                        onDecrement: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        onIncrement: _quantity < 99
                            ? () => setState(() => _quantity++)
                            : null,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isWeight
                              ? '${_price == null ? 'R\$ --' : Formatters.currency(_price!)}/kg × ${Formatters.weight(_weight ?? 0)}'
                              : '$_quantity ${_quantity == 1 ? 'unidade' : 'unidades'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.emeraldDark,
                          ),
                        ),
                      ),
                      Text(
                        Formatters.currency(_subtotal),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.emeraldDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      widget.submitLabel ??
                          (_editing
                              ? 'Salvar alterações'
                              : 'Adicionar ao carrinho'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _EditorStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Diminuir quantidade',
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_rounded, size: 19),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Aumentar quantidade',
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}
