import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/shopping_list.dart';
import '../../domain/shopping_sector.dart';
import '../providers/shopping_lists_provider.dart';
import '../shopping_list_detail_screen.dart';

/// Mini-barra expansível da lista ativa na tela de compra.
class ActiveShoppingListBar extends ConsumerStatefulWidget {
  const ActiveShoppingListBar({super.key});

  @override
  ConsumerState<ActiveShoppingListBar> createState() =>
      _ActiveShoppingListBarState();
}

class _ActiveShoppingListBarState extends ConsumerState<ActiveShoppingListBar> {
  bool _expanded = false;

  void _openList(ShoppingList list) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShoppingListDetailScreen(listId: list.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(activeShoppingListProvider);
    if (list == null) return const SizedBox.shrink();

    final total = list.totalItems;
    final bought = list.boughtItems;
    final pending = list.pending;
    final percent = total == 0 ? 0 : (bought / total * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.emeraldTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 10, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          list.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lista: ${list.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.emeraldDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              total == 0
                                  ? 'Lista vazia'
                                  : '$bought/$total itens no carrinho'
                                      '${pending.isEmpty ? ' • tudo comprado 🎉' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.emeraldDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.emeraldDark,
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.emeraldDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : bought / total,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.7),
                      valueColor: const AlwaysStoppedAnimation(
                        AppTheme.emerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    children: [
                      Divider(
                        height: 1,
                        color: AppTheme.emerald.withValues(alpha: 0.18),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pending.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  'Tudo comprado! Você pode finalizar a compra.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.emeraldDark,
                                  ),
                                ),
                              )
                            else ...[
                              const Text(
                                'Ainda faltam',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: AppTheme.emeraldDark,
                                ),
                              ),
                              const SizedBox(height: 5),
                              ...pending.take(6).map(
                                    (item) => _PendingRow(item: item),
                                  ),
                              if (pending.length > 6)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    '+ ${pending.length - 6} '
                                    '${pending.length - 6 == 1 ? 'item' : 'itens'} na lista completa',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ),
                            ],
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () => _openList(list),
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 15,
                                  ),
                                  label: const Text('Abrir lista completa'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.emeraldDark,
                                    textStyle: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => ref
                                      .read(
                                          activeShoppingListIdProvider.notifier)
                                      .clear(),
                                  icon: const Icon(
                                    Icons.link_off_rounded,
                                    size: 15,
                                  ),
                                  label: const Text('Remover'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.muted,
                                    textStyle: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.item});

  final ShoppingListItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.emerald.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(item.sector.emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ),
          Text(
            formatShoppingQuantity(item.quantity, item.unit),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
