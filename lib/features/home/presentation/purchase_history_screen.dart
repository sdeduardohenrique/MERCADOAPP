import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/purchase.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../domain/purchase_history_sync_service.dart';
import 'edit_purchase_screen.dart';
import 'providers/purchase_history_provider.dart';
import 'widgets/purchase_share_button.dart';

/// Histórico completo de compras salvas no dispositivo.
class PurchaseHistoryScreen extends ConsumerWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchaseHistoryProvider);
    final spending = ref.watch(monthlySpendingProvider);
    final savings = ref.watch(monthlySavingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de compras'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: purchases.isEmpty
          ? const _EmptyHistory()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                _MonthlySummary(spending: spending, savings: savings),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Todas as compras',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldTint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${purchases.length}',
                        style: const TextStyle(
                          color: AppTheme.emeraldDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...purchases.map(
                  (purchase) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PurchaseHistoryTile(purchase: purchase),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  final double spending;
  final double savings;

  const _MonthlySummary({required this.spending, required this.savings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emerald.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo de ${Formatters.monthName(DateTime.now()).toLowerCase()}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gasto total',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Formatters.currency(spending),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Economia',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Formatters.currency(savings),
                      style: const TextStyle(
                        color: AppTheme.lime,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tile com menu para excluir uma compra do histórico.
class PurchaseHistoryTile extends ConsumerWidget {
  final Purchase purchase;

  const PurchaseHistoryTile({super.key, required this.purchase});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PurchaseDetailScreen(purchaseId: purchase.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.emeraldTint,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.emeraldDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchase.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${Formatters.relativeDate(purchase.date)} • '
                      '${purchase.itemCount} itens',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(purchase.total),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    purchase.savings > 0
                        ? '− ${Formatters.currency(purchase.savings)}'
                        : 'sem alertas',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: purchase.savings > 0
                          ? AppTheme.emerald
                          : AppTheme.muted,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções da compra',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppTheme.muted,
                ),
                onSelected: (value) async {
                  if (value == 'edit') {
                    final result =
                        await Navigator.of(context).push<PurchaseEditResult>(
                      MaterialPageRoute(
                        builder: (_) => EditPurchaseScreen(purchase: purchase),
                      ),
                    );
                    if (!context.mounted || result == null) return;
                    showPurchaseMutationFeedback(
                      ScaffoldMessenger.of(context),
                      result.sync,
                      success: 'Compra atualizada.',
                      localOnly: 'Edição salva neste dispositivo.',
                      failure:
                          'Edição salva aqui, mas não foi possível sincronizar.',
                    );
                    return;
                  }

                  if (value == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Excluir compra?'),
                        content: Text(
                          'A compra em ${purchase.storeName} será removida do '
                          'histórico e do total do mês.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.red,
                            ),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;

                    final messenger = ScaffoldMessenger.of(context);
                    final sync = await ref
                        .read(purchaseHistoryProvider.notifier)
                        .removePurchase(purchase.id);
                    showPurchaseMutationFeedback(
                      messenger,
                      sync,
                      success: 'Compra excluída.',
                      localOnly: 'Compra excluída deste dispositivo.',
                      failure:
                          'Compra excluída aqui, mas não foi possível sincronizar.',
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Editar compra'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Excluir compra'),
                      ],
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
}

/// Feedback padronizado para edição/exclusão local-first.
void showPurchaseMutationFeedback(
  ScaffoldMessengerState messenger,
  PurchaseMutationResult result, {
  required String success,
  required String localOnly,
  required String failure,
}) {
  final message = result.isSynced
      ? success
      : result.hasFailed
          ? failure
          : localOnly;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

// --------------------------------------------------------------- Detalhes
class PurchaseDetailScreen extends ConsumerWidget {
  final String purchaseId;

  const PurchaseDetailScreen({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchase = ref.watch(purchaseByIdProvider(purchaseId));

    if (purchase == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalhes da compra'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Voltar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Esta compra não está mais no histórico.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.muted),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da compra'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PurchaseShareButton(purchase: purchase, expanded: false),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Editar compra',
            onPressed: () => _editPurchase(context, ref, purchase),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Excluir compra',
            onPressed: () => _deletePurchase(context, ref, purchase),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          _DetailHeader(purchase: purchase),
          const SizedBox(height: 24),
          const Text(
            'Itens da compra',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < purchase.items.length; i++) ...[
                  _ItemRow(item: purchase.items[i]),
                  if (i < purchase.items.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.emeraldTint,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total da compra',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.emeraldDark,
                    ),
                  ),
                ),
                Text(
                  Formatters.currency(purchase.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppTheme.emeraldDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          if (purchase.savings > 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.eco_rounded,
                  size: 15,
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Você economizou ${Formatters.currency(purchase.savings)} '
                    'com ofertas e alertas',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.emerald,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          PurchaseShareButton(purchase: purchase),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: AppTheme.muted,
              ),
              SizedBox(width: 5),
              Text(
                'Compra salva no dispositivo',
                style: TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editPurchase(
    BuildContext context,
    WidgetRef ref,
    Purchase purchase,
  ) async {
    final result = await Navigator.of(context).push<PurchaseEditResult>(
      MaterialPageRoute(
        builder: (_) => EditPurchaseScreen(purchase: purchase),
      ),
    );
    if (!context.mounted || result == null) return;

    showPurchaseMutationFeedback(
      ScaffoldMessenger.of(context),
      result.sync,
      success: 'Compra atualizada.',
      localOnly: 'Edição salva neste dispositivo.',
      failure: 'Edição salva aqui, mas não foi possível sincronizar.',
    );
  }

  Future<void> _deletePurchase(
    BuildContext context,
    WidgetRef ref,
    Purchase purchase,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir compra?'),
        content: Text(
          'A compra em ${purchase.storeName} será removida do histórico e do '
          'total do mês.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final sync = await ref
        .read(purchaseHistoryProvider.notifier)
        .removePurchase(purchase.id);

    if (context.mounted) Navigator.of(context).pop();
    showPurchaseMutationFeedback(
      messenger,
      sync,
      success: 'Compra excluída.',
      localOnly: 'Compra excluída deste dispositivo.',
      failure: 'Compra excluída aqui, mas não foi possível sincronizar.',
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final Purchase purchase;

  const _DetailHeader({required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppTheme.lime,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchase.storeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.longDate(purchase.date),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valor total',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.currency(purchase.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.lime,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${purchase.itemCount} itens',
                  style: const TextStyle(
                    color: AppTheme.emeraldDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final PurchaseItem item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: item.isByWeight ? 54 : 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(11),
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
                color: AppTheme.muted,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.currency(item.unitPrice)} / ${item.unit}',
                  style: const TextStyle(
                    fontSize: 11,
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
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.emeraldTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppTheme.emerald,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sem compras guardadas',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'As compras que você finalizar no scanner aparecem aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}
