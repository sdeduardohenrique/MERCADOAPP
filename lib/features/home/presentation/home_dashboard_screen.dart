import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/purchase.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../cart/presentation/active_purchase_screen.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import '../../cart/presentation/providers/purchase_budget_provider.dart';
import '../../cart/presentation/widgets/purchase_budget_sheet.dart';
import '../../community/presentation/providers/market_provider.dart';
import '../../community/presentation/widgets/market_selection_sheet.dart';
import '../../profile/presentation/providers/profile_provider.dart';
import 'providers/dashboard_period_provider.dart';
import 'providers/purchase_history_provider.dart';
import 'purchase_history_screen.dart';

/// Dashboard financeiro e de histórico — primeira tela após o Splash.
///
/// "Iniciar nova compra" abre o fluxo de identificação do mercado e só libera
/// o carrinho depois que o utilizador confirma onde está comprando.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  bool _startingPurchase = false;
  bool _openingPurchase = false;

  Future<void> _openActivePurchase() async {
    if (_openingPurchase) return;
    _openingPurchase = true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActivePurchaseScreen()),
    );
    _openingPurchase = false;
  }

  Future<void> _startPurchase() async {
    if (_startingPurchase) return;

    final cart = ref.read(cartProvider);

    // Retomar uma compra já iniciada não pede o mercado novamente. Um carrinho
    // vazio sempre passa pela identificação, mesmo que exista um mercado
    // escolhido de uma visita anterior.
    if (cart.isNotEmpty) {
      await _openActivePurchase();
      return;
    }

    setState(() => _startingPurchase = true);
    try {
      final result = await showMarketSelectionSheet(context);
      if (!mounted || result.action == MarketSelectionAction.dismissed) {
        return;
      }

      final market = result.market;
      if (market == null) {
        ref.read(selectedMarketProvider.notifier).clear();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Compra sem mercado: os preços ficarão apenas no seu histórico.',
              ),
            ),
          );
      } else {
        ref.read(selectedMarketProvider.notifier).select(market);

        if (!market.isRemoto) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Mercado salvo neste dispositivo. A sincronização acontece quando houver conexão.',
                ),
              ),
            );
        }
      }

      // Orçamento é opcional e só é perguntado ao iniciar uma compra nova.
      final budget = await showPurchaseBudgetSheet(context);
      if (!mounted) return;
      ref.read(purchaseBudgetProvider.notifier).setBudget(budget?.budget);

      await _openActivePurchase();
    } finally {
      if (mounted) setState(() => _startingPurchase = false);
    }
  }

  void _openHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen()),
    );
  }

  Future<void> _pickCustomPeriod() async {
    final filter = ref.read(dashboardPeriodProvider);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: filter.customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      helpText: 'Escolha o período',
      cancelText: 'Cancelar',
      saveText: 'Aplicar',
      confirmText: 'Aplicar',
      fieldStartLabelText: 'Data inicial',
      fieldEndLabelText: 'Data final',
    );

    if (picked == null || !mounted) return;
    ref.read(dashboardPeriodProvider.notifier).selectCustom(picked);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final periodFilter = ref.watch(dashboardPeriodProvider);
    final spending = ref.watch(periodSpendingProvider);
    final savings = ref.watch(periodSavingsProvider);
    final periodPurchases = ref.watch(periodPurchasesProvider);
    final recent = ref.watch(recentPurchasesProvider);
    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final cartItems = ref.watch(cartItemCountProvider);
    final selectedMarket = ref.watch(selectedMarketProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _Header(
            name: profile.firstName,
            initials: profile.initials,
            onNotifications: () => _showNotifications(context),
          ),
          if (cart.isNotEmpty) ...[
            const SizedBox(height: 18),
            _ActiveCartBanner(
              total: cartTotal,
              itemCount: cartItems,
              uniqueItems: cart.length,
              marketName: selectedMarket?.nome,
              onContinue: _openActivePurchase,
            ),
          ],
          const SizedBox(height: 24),
          _PrimaryCta(
            onStart: _startingPurchase ? null : _startPurchase,
          ),
          const SizedBox(height: 20),
          _PeriodSelector(
            filter: periodFilter,
            onSelect: (period) {
              if (period == DashboardPeriod.custom) {
                _pickCustomPeriod();
              } else {
                ref.read(dashboardPeriodProvider.notifier).select(period);
              }
            },
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BentoCard(
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppTheme.emerald,
                    iconBackground: AppTheme.emeraldTint,
                    label: periodFilter.spendingLabel,
                    value: Formatters.currency(spending),
                    caption: periodPurchases.length == 1
                        ? '1 compra no período'
                        : '${periodPurchases.length} compras no período',
                    valueColor: AppTheme.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BentoCard(
                    icon: Icons.savings_rounded,
                    iconColor: AppTheme.emeraldDark,
                    iconBackground: AppTheme.lime,
                    label: 'Você economizou',
                    value: Formatters.currency(savings),
                    caption:
                        savings > 0 ? 'Graças aos alertas' : 'Ative os alertas',
                    valueColor: AppTheme.emerald,
                    highlight: savings > 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Últimas compras',
            actionLabel: 'Ver todas',
            onAction: () => _openHistory(context),
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            _EmptyPurchases(
              onStart: _startingPurchase ? null : _startPurchase,
            )
          else
            ...recent.map(
              (purchase) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PurchaseTile(purchase: purchase),
              ),
            ),
          const SizedBox(height: 16),
          const _CommunityTeaser(),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content:
              Text('Nenhuma notificação nova. Bom momento para economizar!'),
        ),
      );
  }
}

// ---------------------------------------------------------------- Header
class _Header extends StatelessWidget {
  final String name;
  final String initials;
  final VoidCallback onNotifications;

  const _Header({
    required this.name,
    required this.initials,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            color: AppTheme.emeraldTint,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppTheme.emeraldDark,
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, $name! 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Sem sustos no caixa.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        _IconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notificações',
          onTap: onNotifications,
          showDot: true,
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showDot;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: AppTheme.ink, size: 24),
                  if (showDot)
                    Positioned(
                      top: 13,
                      right: 14,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------- Compra em andamento
/// Indicador de carrinho ativo, exibido acima do CTA principal.
///
/// O carrinho vive no Riverpod; voltar ao Dashboard não descarta os itens.
class _ActiveCartBanner extends StatelessWidget {
  final double total;
  final int itemCount;
  final int uniqueItems;
  final String? marketName;
  final VoidCallback onContinue;

  const _ActiveCartBanner({
    required this.total,
    required this.itemCount,
    required this.uniqueItems,
    required this.onContinue,
    this.marketName,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Você tem uma compra em andamento. '
          'Total ${Formatters.currency(total)}. Retomar compra.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: onContinue,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              color: AppTheme.amberTint,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.amber.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_rounded,
                    color: Color(0xFFB26B00),
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Você tem uma compra em andamento',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${marketName ?? 'Mercado'} • '
                        '$itemCount ${itemCount == 1 ? 'item' : 'itens'} '
                        '(${uniqueItems == 1 ? '1 produto' : '$uniqueItems produtos'}) '
                        '• ${Formatters.currency(total)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Retomar',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.emeraldDark,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: AppTheme.emeraldDark,
                      ),
                    ],
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

// ------------------------------------------------------------------- CTA
class _PrimaryCta extends StatelessWidget {
  final VoidCallback? onStart;

  const _PrimaryCta({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Iniciar nova compra',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.ctaGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.emerald.withValues(alpha: 0.28),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppTheme.lime.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -70,
                left: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'NOVA COMPRA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Vamos somar\nas compras?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adicione itens pela câmera, manual ou voz e acompanhe o total em tempo real.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onStart,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.emeraldDark,
                          minimumSize: const Size(0, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon:
                            const Icon(Icons.shopping_basket_rounded, size: 22),
                        label: const Text('Iniciar nova compra'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Período
class _PeriodSelector extends StatelessWidget {
  final DashboardPeriodFilter filter;
  final ValueChanged<DashboardPeriod> onSelect;

  const _PeriodSelector({required this.filter, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const options = <(DashboardPeriod, String)>[
      (DashboardPeriod.thisMonth, 'Este mês'),
      (DashboardPeriod.lastThreeMonths, 'Últimos 3 meses'),
      (DashboardPeriod.thisYear, 'Este ano'),
      (DashboardPeriod.custom, 'Personalizado'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Resumo do período',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
            ),
            if (filter.period == DashboardPeriod.custom)
              Text(
                filter.shortLabel,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final option = options[index];
              final selected = filter.period == option.$1;
              final label = option.$1 == DashboardPeriod.custom &&
                      filter.customRange != null
                  ? filter.shortLabel
                  : option.$2;

              return _PeriodChip(
                label: label,
                icon: option.$1 == DashboardPeriod.custom
                    ? Icons.date_range_rounded
                    : null,
                selected: selected,
                onTap: () => onSelect(option.$1),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filtrar por $label',
      child: Material(
        color: selected ? AppTheme.emerald : Colors.white,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: selected ? AppTheme.emerald : AppTheme.line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 14,
                    color: selected ? Colors.white : AppTheme.muted,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.ink,
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

// ------------------------------------------------------------- Bento card
class _BentoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;
  final String caption;
  final Color valueColor;
  final bool highlight;

  const _BentoCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.caption,
    required this.valueColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.emeraldTint : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: highlight
              ? AppTheme.emerald.withValues(alpha: 0.12)
              : AppTheme.line,
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppTheme.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------- Section header
class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.emeraldDark,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(actionLabel),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Lista de compras
/// Tile compacto de compra, reutilizado no Dashboard e no Histórico.
class PurchaseTile extends StatelessWidget {
  final Purchase purchase;

  const PurchaseTile({super.key, required this.purchase});

  @override
  Widget build(BuildContext context) {
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
            boxShadow: AppTheme.softShadow,
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
                  Icons.storefront_rounded,
                  color: AppTheme.emeraldDark,
                  size: 23,
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
                      '${purchase.itemCount} ${purchase.itemCount == 1 ? 'item' : 'itens'}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(purchase.total),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  if (purchase.savings > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      '− ${Formatters.currency(purchase.savings)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Empty state
class _EmptyPurchases extends StatelessWidget {
  final VoidCallback? onStart;

  const _EmptyPurchases({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            color: AppTheme.emerald,
            size: 34,
          ),
          const SizedBox(height: 10),
          const Text(
            'Nenhuma compra por aqui ainda',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Faça sua primeira compra e o resumo aparece aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Começar agora'),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Teaser
class _CommunityTeaser extends StatelessWidget {
  const _CommunityTeaser();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.amberTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.radar_rounded,
              color: Color(0xFFB26B00),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Radar da comunidade',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppTheme.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Veja onde os vizinhos encontraram os menores preços.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
