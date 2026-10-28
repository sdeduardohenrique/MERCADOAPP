import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/shopping_list.dart';
import '../../domain/shopping_sector.dart';
import '../providers/shopping_lists_provider.dart';

Future<ShoppingListItem?> showShoppingListItemSheet(
  BuildContext context, {
  required String listId,
  ShoppingListItem? item,
  String? initialName,
}) {
  return showModalBottomSheet<ShoppingListItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ShoppingListItemSheet(
      listId: listId,
      item: item,
      initialName: initialName,
    ),
  );
}

class ShoppingListItemSheet extends ConsumerStatefulWidget {
  const ShoppingListItemSheet({
    super.key,
    required this.listId,
    this.item,
    this.initialName,
  });

  final String listId;
  final ShoppingListItem? item;
  final String? initialName;

  @override
  ConsumerState<ShoppingListItemSheet> createState() =>
      _ShoppingListItemSheetState();
}

class _ShoppingListItemSheetState extends ConsumerState<ShoppingListItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late String _unit;
  late ShoppingSector _sector;
  late bool _sectorTouched;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    final initialName = item?.name ?? widget.initialName ?? '';
    _nameController = TextEditingController(text: initialName);
    _quantityController = TextEditingController(
      text: item == null ? '1' : _quantityInput(item.quantity),
    );
    _priceController = TextEditingController(
      text: item?.estimatedPrice == null
          ? ''
          : _priceInput(item!.estimatedPrice!),
    );
    _unit = item?.unit ?? 'un';
    _sector = item?.sector ?? ShoppingSector.categorize(initialName);
    _sectorTouched = item != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _quantityInput(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll('.', ',');
  }

  String _priceInput(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  void _onNameChanged(String value) {
    if (_sectorTouched) return;
    final suggested = ShoppingSector.categorize(value);
    if (suggested != _sector) setState(() => _sector = suggested);
  }

  double? _parseNumber(String raw) {
    var normalized = raw.trim().replaceAll(' ', '');
    if (normalized.isEmpty) return null;

    // Aceita "1.234,56" (pt-BR), "8,50" e também "8.50" (teclado numérico).
    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (normalized.contains(',')) {
      normalized = normalized.replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final quantity = _parseNumber(_quantityController.text);
    if (quantity == null || quantity <= 0) return;

    final price = _parseNumber(_priceController.text);
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final notifier = ref.read(shoppingListsProvider.notifier);
    ShoppingListItem? result;

    if (_editing) {
      final original = widget.item!;
      result = await notifier.updateItem(
        widget.listId,
        ShoppingListItem(
          id: original.id,
          listId: widget.listId,
          name: name,
          quantity: quantity,
          unit: _unit,
          estimatedPrice: price,
          sector: _sector,
          isBought: original.isBought,
          createdAt: original.createdAt,
          updatedAt: original.updatedAt,
        ),
      );
    } else {
      result = await notifier.addItem(
        widget.listId,
        name: name,
        quantity: quantity,
        unit: _unit,
        estimatedPrice: price,
        sector: _sector,
      );
    }

    if (!mounted) return;
    if (result == null) {
      setState(() {
        _saving = false;
        _error = 'Não foi possível salvar o item. Tente novamente.';
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _editing ? 'Editar item' : 'Adicionar item',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Informe quantidade, unidade e, se quiser, um preço estimado.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                autofocus: !_editing,
                textCapitalization: TextCapitalization.sentences,
                onChanged: _onNameChanged,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Informe o nome do item.'
                    : null,
                decoration: _inputDecoration(
                  label: 'Nome do item',
                  hint: 'Ex.: Tomate, Detergente, Patinho moído',
                  icon: Icons.shopping_basket_outlined,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                      ],
                      validator: (value) {
                        final parsed = _parseNumber(value ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Quantidade inválida.';
                        }
                        return null;
                      },
                      decoration: _inputDecoration(
                        label: 'Quantidade',
                        hint: '1',
                        icon: Icons.numbers_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: _inputDecoration(
                        label: 'Unidade',
                        icon: Icons.straighten_rounded,
                      ),
                      items: shoppingUnitOptions
                          .map(
                            (option) => DropdownMenuItem(
                              value: option.id,
                              child: Text(
                                option.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _unit = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                validator: (value) {
                  final raw = (value ?? '').trim();
                  if (raw.isEmpty) return null;
                  final parsed = _parseNumber(raw);
                  if (parsed == null || parsed < 0) {
                    return 'Preço inválido.';
                  }
                  return null;
                },
                decoration: _inputDecoration(
                  label: 'Preço estimado (opcional)',
                  hint: '0,00',
                  icon: Icons.attach_money_rounded,
                  prefixText: 'R\$ ',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text(
                    'Setor do mercado',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_sectorTouched)
                    const Text(
                      'sugerido automaticamente',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.emeraldDark,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: ShoppingSector.values.map((sector) {
                  final selected = sector == _sector;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: 'Setor ${sector.label}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: () => setState(() {
                        _sector = sector;
                        _sectorTouched = true;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.emeraldTint
                              : AppTheme.background,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: selected ? AppTheme.emerald : AppTheme.line,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          '${sector.emoji} ${sector.label}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            color: selected
                                ? AppTheme.emeraldDark
                                : AppTheme.muted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.red,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 19),
                      label: Text(
                        _saving
                            ? 'Salvando...'
                            : _editing
                                ? 'Salvar item'
                                : 'Adicionar à lista',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: AppTheme.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppTheme.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppTheme.line),
      ),
    );
  }
}
