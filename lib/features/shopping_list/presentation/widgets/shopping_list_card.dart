import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/shopping_list.dart';

/// Card Bento de uma lista de compras.
class ShoppingListCard extends StatelessWidget {
  const ShoppingListCard({
    super.key,
    required this.list,
    required this.onTap,
  });

  final ShoppingList list;
  final VoidCallback onTap;

  String get _counter {
    if (list.totalItems == 0) return 'Lista vazia';
    if (list.pendingItems == 0) return 'Tudo comprado';
    return '${list.boughtItems} de ${list.totalItems} itens';
  }

  String get _estimate => list.hasEstimates
      ? Formatters.currency(list.estimatedTotal)
      : 'Sem estimativa';

  @override
  Widget build(BuildContext context) {
    final progress = list.progress;
    final percent = (progress * 100).round();

    return Semantics(
      button: true,
      label: '${list.name}, $_counter, $_estimate',
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.line),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldTint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        list.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _counter,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
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
                        fontWeight: FontWeight.w700,
                        color: AppTheme.emeraldDark,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      list.hasEstimates
                          ? Icons.savings_outlined
                          : Icons.receipt_long_outlined,
                      size: 14,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _estimate,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color:
                            list.hasEstimates ? AppTheme.ink : AppTheme.muted,
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
