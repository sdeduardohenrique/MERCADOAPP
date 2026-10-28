import 'package:flutter/material.dart';

import '../../../../core/models/purchase.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../home/domain/purchase_share_service.dart';
import '../../home/presentation/purchase_history_screen.dart';
import '../../home/presentation/widgets/purchase_share_button.dart';

/// Tela de sucesso exibida imediatamente após finalizar a compra.
///
/// Além de confirmar o salvamento, é o ponto natural para enviar o recibo
/// digital à família pelo WhatsApp.
class PurchaseSuccessScreen extends StatelessWidget {
  final Purchase purchase;

  const PurchaseSuccessScreen({super.key, required this.purchase});

  @override
  Widget build(BuildContext context) {
    final market = const PurchaseShareService().marketLabel(purchase);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Fechar',
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppTheme.muted,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  color: AppTheme.emeraldTint,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emerald.withValues(alpha: 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.ctaGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldTint,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'RECIBO DIGITAL',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppTheme.emeraldDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Compra finalizada!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sem sustos no caixa. Seu resumo está pronto para '
              'compartilhar com a família.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: 24),
            _SuccessSummaryCard(purchase: purchase, market: market),
            const SizedBox(height: 20),
            PurchaseShareButton(purchase: purchase),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PurchaseDetailScreen(
                      purchaseId: purchase.id,
                    ),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('Ver detalhes da compra'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar ao início'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessSummaryCard extends StatelessWidget {
  final Purchase purchase;
  final String market;

  const _SuccessSummaryCard({
    required this.purchase,
    required this.market,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = purchase.itemCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          _SummaryRow(
            icon: Icons.storefront_rounded,
            label: 'Mercado',
            value: market,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: Icons.calendar_today_rounded,
            label: 'Data',
            value: Formatters.numericDate(purchase.date),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: Icons.shopping_bag_rounded,
            label: 'Itens',
            value: '$itemCount ${itemCount == 1 ? 'item' : 'itens'}'
                ' • ${purchase.uniqueItems} '
                '${purchase.uniqueItems == 1 ? 'produto' : 'produtos'}',
          ),
          const Divider(height: 28, color: AppTheme.line),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total pago',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'O valor já está no seu histórico.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.currency(purchase.total),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.emeraldDark,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
          if (purchase.savings > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppTheme.emeraldTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.savings_rounded,
                    size: 18,
                    color: AppTheme.emeraldDark,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Você economizou ${Formatters.currency(purchase.savings)} '
                      'com ofertas e alertas.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.emeraldDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: AppTheme.emeraldDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.muted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ),
      ],
    );
  }
}
