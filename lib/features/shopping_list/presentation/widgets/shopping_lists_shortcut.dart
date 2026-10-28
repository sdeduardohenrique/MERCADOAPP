import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shell/presentation/providers/shell_tab_provider.dart';
import '../providers/shopping_lists_provider.dart';

/// Atalho compacto da Home para a aba "Minhas Listas".
class ShoppingListsShortcut extends ConsumerWidget {
  const ShoppingListsShortcut({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(shoppingListsSummaryProvider);
    final hasLists = summary.listCount > 0;
    final subtitle = hasLists
        ? '${summary.listCount} ${summary.listCount == 1 ? 'lista' : 'listas'}'
            ' • ${summary.pendingItems} '
            '${summary.pendingItems == 1 ? 'item pendente' : 'itens pendentes'}'
        : 'Crie sua primeira lista de compras';

    return Semantics(
      button: true,
      label: 'Minhas Listas. $subtitle',
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => ref.read(shellTabProvider.notifier).state = 1,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.line),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.limeTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('🧺', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Minhas Listas',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                          if (hasLists && summary.pendingItems > 0) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${summary.pendingItems}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasLists && summary.hasEstimates) ...[
                  const SizedBox(width: 8),
                  Text(
                    Formatters.currency(summary.estimatedTotal),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.emeraldDark,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
