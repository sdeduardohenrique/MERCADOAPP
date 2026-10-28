import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../cart/presentation/active_purchase_screen.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import '../../cart/presentation/purchase_setup_flow.dart';
import '../domain/shopping_list.dart';
import '../domain/shopping_sector.dart';
import 'providers/shopping_lists_provider.dart';
import 'widgets/shopping_list_editor_sheet.dart';
import 'widgets/shopping_list_item_sheet.dart';

/// Detalhe de uma lista, com itens agrupados por setor do supermercado.
class ShoppingListDetailScreen extends ConsumerWidget {
  const ShoppingListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLists = ref.watch(shoppingListsProvider);
    final list = ref.watch(shoppingListByIdProvider(listId));

    if (list == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          surfaceTintColor: Colors.transparent,
          title: const Text('Lista'),
        ),
        body: asyncLists.isLoading && !asyncLists.hasValue
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.emerald),
              )
            : const _NotFound(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          list.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        actions: [
          PopupMenuButton<_ListAction>(
            tooltip: 'Opções da lista',
            icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.ink),
            onSelected: (action) {
              if (action == _ListAction.edit) {
                unawaited(
                  showShoppingListEditorSheet(context, list: list),
                );
              } else {
                unawaited(_confirmDeleteList(context, ref, list));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ListAction.edit,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 19),
                    SizedBox(width: 9),
                    Text('Editar lista'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _ListAction.delete,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: AppTheme.red,
                    ),
                    SizedBox(width: 9),
                    Text('Excluir lista',
                        style: TextStyle(color: AppTheme.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _StartPurchaseBar(
        list: list,
        onStart: () => _startPurchase(context, ref, list),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _ListHeaderCard(list: list),
          const SizedBox(height: 14),
          _AddItemButton(onTap: () => _addItem(context, ref, list)),
          const SizedBox(height: 18),
          if (list.items.isEmpty)
            _EmptyItems(
              onAdd: () => _addItem(context, ref, list),
              onSuggestion: (name) =>
                  _addItem(context, ref, list, initialName: name),
            )
          else ...[
            ..._buildSectorSections(context, ref, list),
            if (list.bought.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Divider(color: AppTheme.line, height: 20),
              _BoughtHeader(
                count: list.bought.length,
                onClear: () => _confirmClearBought(context, ref, list),
              ),
              ...list.bought.map(
                (item) => _ShoppingItemTile(
                  key: ValueKey('bought-${item.id}'),
                  item: item,
                  onToggle: () => unawaited(
                    ref
                        .read(shoppingListsProvider.notifier)
                        .toggleItem(list.id, item.id),
                  ),
                  onEdit: () => unawaited(
                    showShoppingListItemSheet(
                      context,
                      listId: list.id,
                      item: item,
                    ),
                  ),
                  onDelete: () => unawaited(
                    _confirmDeleteItem(context, ref, list, item),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSectorSections(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) {
    final widgets = <Widget>[];
    for (final sector in ShoppingSector.values) {
      final items =
          list.itemsForSector(sector).where((item) => !item.isBought).toList();
      if (items.isEmpty) continue;

      widgets.add(_SectorHeader(sector: sector, count: items.length));
      for (final item in items) {
        widgets.add(
          _ShoppingItemTile(
            key: ValueKey('pending-${item.id}'),
            item: item,
            onToggle: () => unawaited(
              ref
                  .read(shoppingListsProvider.notifier)
                  .toggleItem(list.id, item.id),
            ),
            onEdit: () => unawaited(
              showShoppingListItemSheet(
                context,
                listId: list.id,
                item: item,
              ),
            ),
            onDelete: () => unawaited(
              _confirmDeleteItem(context, ref, list, item),
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Future<void> _addItem(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list, {
    String? initialName,
  }) async {
    final item = await showShoppingListItemSheet(
      context,
      listId: list.id,
      initialName: initialName,
    );
    if (item == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.name} adicionado à lista.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _startPurchase(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) async {
    // Uma compra nova a partir da lista passa pelo mesmo onboarding da Home:
    // primeiro o mercado, depois o orçamento. Se já existe carrinho, é uma
    // retomada e os dados já foram definidos anteriormente.
    if (ref.read(cartProvider).isEmpty) {
      final ready = await prepareNewPurchase(context, ref);
      if (!context.mounted || !ready) return;
    }

    ref.read(activeShoppingListIdProvider.notifier).select(list.id);

    // Itens que já estavam no carrinho também devem ser riscados.
    final cart = ref.read(cartProvider);
    final notifier = ref.read(shoppingListsProvider.notifier);
    for (final cartItem in cart) {
      await notifier.markBoughtMatching(cartItem.name, listId: list.id);
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ActivePurchaseScreen(),
      ),
    );
  }

  Future<void> _confirmDeleteList(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir lista?'),
        content: Text(
          '"${list.name}" e todos os seus itens serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(shoppingListsProvider.notifier).deleteList(list.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDeleteItem(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
    ShoppingListItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover item?'),
        content: Text('"${item.name}" sairá desta lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(shoppingListsProvider.notifier).removeItem(list.id, item.id);
  }

  Future<void> _confirmClearBought(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar comprados?'),
        content: Text(
          '${list.bought.length} '
          '${list.bought.length == 1 ? 'item comprado será removido' : 'itens comprados serão removidos'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(shoppingListsProvider.notifier).clearBought(list.id);
  }
}

enum _ListAction { edit, delete }

enum _ItemAction { edit, delete }

class _ListHeaderCard extends StatelessWidget {
  const _ListHeaderCard({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context) {
    final percent = (list.progress * 100).round();
    final estimate = list.hasEstimates
        ? Formatters.currency(list.estimatedTotal)
        : 'Sem estimativa';
    final subtitle = list.totalItems == 0
        ? 'Adicione o primeiro item'
        : list.pendingItems == 0
            ? 'Tudo comprado'
            : '${list.pendingItems} '
                '${list.pendingItems == 1 ? 'pendente' : 'pendentes'}';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.line),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.emeraldTint,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(list.icon, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${list.boughtItems} de ${list.totalItems} itens',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: list.pendingItems == 0 && list.totalItems > 0
                            ? AppTheme.emeraldDark
                            : AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    estimate,
                    style: TextStyle(
                      fontSize: list.hasEstimates ? 14 : 11,
                      fontWeight: FontWeight.w800,
                      color: list.hasEstimates
                          ? AppTheme.emeraldDark
                          : AppTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'estimativa',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: list.progress,
              minHeight: 8,
              backgroundColor: AppTheme.line,
              valueColor: const AlwaysStoppedAnimation(AppTheme.emerald),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$percent% concluído',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.emeraldDark,
                ),
              ),
              const Spacer(),
              Text(
                '${list.boughtItems} '
                '${list.boughtItems == 1 ? 'comprado' : 'comprados'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddItemButton extends StatelessWidget {
  const _AddItemButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.emeraldTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: AppTheme.emeraldDark,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Adicionar item',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              const Text(
                'nome, qtd e preço',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.muted,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectorHeader extends StatelessWidget {
  const _SectorHeader({required this.sector, required this.count});

  final ShoppingSector sector;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Row(
        children: [
          Text(sector.emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(
            sector.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppTheme.line),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoughtHeader extends StatelessWidget {
  const _BoughtHeader({required this.count, required this.onClear});

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 17,
            color: AppTheme.emerald,
          ),
          const SizedBox(width: 6),
          const Text(
            'Comprados',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
            label: const Text('Limpar'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.red,
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingItemTile extends StatefulWidget {
  const _ShoppingItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ShoppingListItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ShoppingItemTile> createState() => _ShoppingItemTileState();
}

class _ShoppingItemTileState extends State<_ShoppingItemTile> {
  late bool _visualBought;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _visualBought = widget.item.isBought;
  }

  @override
  void didUpdateWidget(covariant _ShoppingItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy && oldWidget.item.isBought != widget.item.isBought) {
      _visualBought = widget.item.isBought;
    }
  }

  void _handleToggle() {
    if (_busy) return;
    _busy = true;
    setState(() => _visualBought = !widget.item.isBought);
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      widget.onToggle();
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bought = _visualBought;
    final quantity = formatShoppingQuantity(
      widget.item.quantity,
      widget.item.unit,
    );
    final price = widget.item.estimatedPrice == null
        ? null
        : Formatters.currency(widget.item.estimatedTotal);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bought ? AppTheme.background : AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _handleToggle,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.line),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bought ? AppTheme.emerald : Colors.transparent,
                    border: Border.all(
                      color: bought ? AppTheme.emerald : AppTheme.line,
                      width: 1.8,
                    ),
                  ),
                  child: bought
                      ? const Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: bought ? AppTheme.muted : AppTheme.ink,
                          decoration: bought
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: AppTheme.muted,
                          decorationThickness: 1.5,
                        ),
                        child: Text(
                          widget.item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.item.sector.emoji} $quantity'
                        '${price == null ? '' : ' • $price'}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: bought
                              ? AppTheme.muted.withValues(alpha: 0.8)
                              : AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_ItemAction>(
                  tooltip: 'Opções do item',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: AppTheme.muted,
                  ),
                  onSelected: (action) {
                    if (action == _ItemAction.edit) {
                      widget.onEdit();
                    } else {
                      widget.onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ItemAction.edit,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 19),
                          SizedBox(width: 9),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _ItemAction.delete,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: AppTheme.red,
                          ),
                          SizedBox(width: 9),
                          Text(
                            'Remover',
                            style: TextStyle(color: AppTheme.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyItems extends StatelessWidget {
  const _EmptyItems({
    required this.onAdd,
    required this.onSuggestion,
  });

  final VoidCallback onAdd;
  final void Function(String name) onSuggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.limeTint,
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Text('🛒', style: TextStyle(fontSize: 31)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sua lista está vazia',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Adicione itens e o app organiza automaticamente por setor.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar primeiro item'),
            ),
          ),
          const SizedBox(height: 15),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sugestões rápidas',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final suggestion in const [
                'Tomate',
                'Leite',
                'Detergente',
                'Arroz',
                'Pão de Forma',
              ])
                _SuggestionChip(
                  label: suggestion,
                  onTap: () => onSuggestion(suggestion),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.line),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _StartPurchaseBar extends StatelessWidget {
  const _StartPurchaseBar({required this.list, required this.onStart});

  final ShoppingList list;
  final VoidCallback onStart;

  String get _label {
    if (list.items.isEmpty) return 'Adicione itens para iniciar';
    if (list.pending.isEmpty) return 'Tudo comprado';
    return 'Iniciar Compra no Mercado';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = list.pending.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? onStart : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.line,
              disabledForegroundColor: AppTheme.muted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 21),
            label: Text(_label),
          ),
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧺', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              'Lista não encontrada',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Ela pode ter sido excluída em outro dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }
}
