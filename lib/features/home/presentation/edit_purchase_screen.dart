import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/purchase.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/price_parser.dart';
import '../domain/purchase_history_sync_service.dart';
import 'providers/purchase_history_provider.dart';

/// Resultado devolvido pela edição para a lista conseguir mostrar o feedback
/// de sincronização sem manter uma referência à compra antiga.
class PurchaseEditResult {
  final Purchase purchase;
  final PurchaseMutationResult sync;

  const PurchaseEditResult({required this.purchase, required this.sync});
}

/// Edição direta de uma compra do histórico (loja, itens e valores).
///
/// O total é sempre recalculado a partir dos itens. A gravação local acontece
/// antes da tentativa no Supabase, por isso o Dashboard nunca fica "esperando
/// a internet" para refletir a correção.
class EditPurchaseScreen extends ConsumerStatefulWidget {
  final Purchase purchase;

  const EditPurchaseScreen({super.key, required this.purchase});

  @override
  ConsumerState<EditPurchaseScreen> createState() => _EditPurchaseScreenState();
}

class _EditPurchaseScreenState extends ConsumerState<EditPurchaseScreen> {
  late final TextEditingController _storeController;
  late List<PurchaseItem> _items;
  bool _saving = false;
  bool _dirty = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _storeController = TextEditingController(text: widget.purchase.storeName);
    _items = [...widget.purchase.items];
  }

  @override
  void dispose() {
    _storeController.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _editItem(int index) async {
    if (_saving) return;

    final edited = await _showPurchaseItemSheet(
      context,
      initial: _items[index],
    );
    if (edited == null || !mounted) return;

    setState(() {
      _items = [..._items]..[index] = edited;
      _dirty = true;
    });
  }

  Future<void> _addItem() async {
    if (_saving) return;

    final added = await _showPurchaseItemSheet(context);
    if (added == null || !mounted) return;

    setState(() {
      _items = [..._items, added];
      _dirty = true;
    });
  }

  void _removeItem(int index) {
    if (_saving) return;

    final removed = _items[index];
    setState(() {
      _items = [..._items]..removeAt(index);
      _dirty = true;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${removed.name} removido. Salve para confirmar.'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              if (!mounted) return;
              setState(() => _items = [..._items]..insert(index, removed));
            },
          ),
        ),
      );
  }

  Future<void> _save() async {
    if (_saving) return;

    final store = _storeController.text.trim();
    if (store.isEmpty) {
      _showError('Informe o nome do mercado.');
      return;
    }
    if (_items.isEmpty) {
      _showError('A compra precisa de pelo menos um item.');
      return;
    }

    final updated = widget.purchase.copyWith(
      storeName: store,
      items: List.unmodifiable(_items),
    );

    setState(() => _saving = true);

    try {
      final sync = await ref
          .read(purchaseHistoryProvider.notifier)
          .updatePurchase(updated);

      if (!mounted) return;
      _allowPop = true;
      Navigator.of(context).pop(
        PurchaseEditResult(purchase: updated, sync: sync),
      );
    } catch (error, stack) {
      debugPrint('[SomaAí] Falha ao editar compra: $error');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Não foi possível salvar a edição. Tente novamente.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDiscard() async {
    if (_saving) return;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text(
          'As mudanças feitas nesta compra ainda não foram salvas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (discard == true && mounted) {
      _allowPop = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_dirty || _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _saving) return;
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar compra'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cancelar edição',
            onPressed: _saving
                ? null
                : _dirty
                    ? _confirmDiscard
                    : () => Navigator.of(context).pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.emeraldTint,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    color: AppTheme.emeraldDark,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ajuste os itens e os valores. O total e o resumo do mês '
                      'são recalculados automaticamente.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppTheme.emeraldDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _storeController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _markDirty(),
              decoration: const InputDecoration(
                labelText: 'Mercado',
                hintText: 'Ex.: Extra, Assaí, Carrefour...',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Itens da compra',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                Text(
                  '${_items.length} ${_items.length == 1 ? 'produto' : 'produtos'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.line),
                ),
                child: const Text(
                  'Nenhum item. Adicione pelo menos um para salvar a compra.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
                ),
              )
            else
              ...List.generate(_items.length, (index) {
                final item = _items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EditableItemCard(
                    item: item,
                    enabled: !_saving,
                    onTap: () => _editItem(index),
                    onRemove: () => _removeItem(index),
                  ),
                );
              }),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _addItem,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Adicionar item'),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.line),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Novo total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.currency(_total),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.emeraldDark,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(_saving ? 'Salvando...' : 'Salvar alterações'),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableItemCard extends StatelessWidget {
  final PurchaseItem item;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _EditableItemCard({
    required this.item,
    required this.enabled,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: item.isByWeight ? 56 : 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.emeraldTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.isByWeight
                      ? Formatters.weight(item.weightKg!)
                      : '${item.quantity}×',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.emeraldDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.currency(item.unitPrice)} / ${item.unit} '
                      '• toque para editar',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.currency(item.totalPrice),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.emeraldDark,
                ),
              ),
              IconButton(
                tooltip: 'Remover item',
                onPressed: enabled ? onRemove : null,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<PurchaseItem?> _showPurchaseItemSheet(
  BuildContext context, {
  PurchaseItem? initial,
}) {
  return showModalBottomSheet<PurchaseItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PurchaseItemSheet(initial: initial),
  );
}

class _PurchaseItemSheet extends StatefulWidget {
  final PurchaseItem? initial;

  const _PurchaseItemSheet({this.initial});

  @override
  State<_PurchaseItemSheet> createState() => _PurchaseItemSheetState();
}

class _PurchaseItemSheetState extends State<_PurchaseItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late int _quantity;

  bool get _editing => widget.initial != null;
  bool get _isWeight => widget.initial?.isByWeight == true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _priceController = TextEditingController(
      text: initial == null
          ? ''
          : initial.unitPrice.toStringAsFixed(2).replaceAll('.', ','),
    );
    _quantity = initial?.quantity ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = PriceParser.parsePrice(_priceController.text);
    if (!PriceParser.isSanePrice(price)) return;

    Navigator.pop(
      context,
      PurchaseItem(
        name: _nameController.text.trim(),
        unit: widget.initial?.unit ?? 'un',
        unitPrice: price!,
        quantity: _isWeight ? 1 : _quantity,
        weightKg: widget.initial?.weightKg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

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
                Text(
                  _editing ? 'Editar item' : 'Adicionar item',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'O total da compra será recalculado ao salvar.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
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
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText:
                              _isWeight ? 'Preço por kg' : 'Preço unitário',
                          prefixText: r'R$ ',
                          hintText: '0,00',
                        ),
                        validator: (value) {
                          final price = PriceParser.parsePrice(value ?? '');
                          if (!PriceParser.isSanePrice(price)) {
                            return 'Preço inválido';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 56,
                      padding: _isWeight
                          ? const EdgeInsets.symmetric(horizontal: 12)
                          : EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.line),
                      ),
                      child: _isWeight
                          ? Center(
                              child: Text(
                                Formatters.weight(widget.initial!.weightKg!),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ink,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Diminuir quantidade',
                                  onPressed: _quantity > 1
                                      ? () => setState(() => _quantity--)
                                      : null,
                                  icon: const Icon(
                                    Icons.remove_rounded,
                                    size: 19,
                                  ),
                                ),
                                Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Aumentar quantidade',
                                  onPressed: _quantity < 99
                                      ? () => setState(() => _quantity++)
                                      : null,
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    size: 19,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(_editing ? 'Salvar item' : 'Adicionar item'),
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
