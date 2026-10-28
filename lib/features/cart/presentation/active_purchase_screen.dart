import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/cart_item.dart';
import '../../../../core/models/community_price.dart';
import '../../../../core/models/mercado.dart';
import '../../../../core/models/purchase.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/label_photo_service.dart';
import '../../../../core/services/price_validation_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../community/domain/community_contribution_service.dart';
import '../../community/presentation/providers/market_provider.dart';
import '../../community/presentation/widgets/market_selection_sheet.dart';
import '../../community_alerts/presentation/providers/alert_preferences_provider.dart';
import '../../community_alerts/presentation/widgets/price_alert_banner.dart';
import '../../home/presentation/providers/purchase_history_provider.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../domain/checkout_service.dart';
import 'providers/cart_provider.dart';
import 'providers/purchase_budget_provider.dart';
import 'widgets/cart_item_editor_sheet.dart';
import 'widgets/manual_item_sheet.dart';
import 'widgets/purchase_budget_sheet.dart';

/// Carrinho central da "Nova compra".
///
/// A câmera não é inicializada aqui. O [ScannerScreen] só é construído quando
/// o utilizador toca em "Ler Etiquetas (Câmera)", o que mantém o custo de
/// câmera/ML Kit fora do fluxo de navegação normal.
class ActivePurchaseScreen extends ConsumerStatefulWidget {
  const ActivePurchaseScreen({super.key});

  @override
  ConsumerState<ActivePurchaseScreen> createState() =>
      _ActivePurchaseScreenState();
}

class _ActivePurchaseScreenState extends ConsumerState<ActivePurchaseScreen> {
  bool _isFinalizing = false;
  bool _finishRequested = false;
  bool _choosingMarket = false;
  CommunityPriceAlert? _currentAlert;
  double _sessionSavings = 0;
  final Set<String> _alertedEans = <String>{};

  late final PriceValidationService _priceValidationService =
      PriceValidationService(
    coordinatesResolver: () async {
      final result =
          await ref.read(locationProvider.notifier).ensureCoordinates();
      return result.coordinates;
    },
    // Visitante não consulta a comunidade.
    enabled: ref.read(guestSessionProvider) == null,
  );

  Future<void> _openScanner() async {
    final item = await Navigator.of(context).push<CartItem>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

    if (!mounted || item == null) return;

    ref.read(cartProvider.notifier).addItem(item);
    _showSnack('${item.name} adicionado ao carrinho.');
    unawaited(_checkCommunityAlert(item));
  }

  /// Publica os preços da compra somente quando ela é finalizada com um
  /// mercado remoto confirmado.
  ///
  /// A compra concluída sem mercado é um registro pessoal: nada é enviado à
  /// comunidade. Sem sessão/rede o serviço falha em silêncio.
  void _publishCartToCommunity(List<CartItem> items, Mercado? market) {
    if (market == null || !market.isRemoto || items.isEmpty) return;

    final seen = <String>{};
    for (final item in items) {
      final key = '${item.ean ?? item.name}|${item.unitPrice}';
      if (!seen.add(key)) continue;

      unawaited(
        ref.read(communityContributionServiceProvider).contribute(
              item: item,
              market: market,
            ),
      );
    }
  }

  Future<void> _checkCommunityAlert(CartItem item) async {
    if (!ref.read(alertPreferencesProvider).alertsEnabled || item.ean == null) {
      return;
    }

    final alert = await _priceValidationService.checkBetterPrice(
      item: item,
      currentPrice: item.unitPrice,
    );

    if (!mounted || alert == null) return;

    if (_alertedEans.add(item.ean!)) {
      _sessionSavings += alert.savings;
    }
    setState(() => _currentAlert = alert);

    // Auto-dismiss after 8 seconds, like the original scanner.
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && identical(_currentAlert, alert)) {
        setState(() => _currentAlert = null);
      }
    });
  }

  Future<void> _addManualItem() async {
    final item = await showManualItemSheet(context, ref);
    if (item != null && mounted) {
      _showSnack('Item adicionado ao carrinho.');
    }
  }

  Future<void> _editItem(CartItem item) async {
    final updated = await showCartItemEditorSheet(
      context,
      initialItem: item,
      title: 'Editar item',
      submitLabel: 'Salvar alterações',
    );
    if (!mounted || updated == null) return;

    ref.read(cartProvider.notifier).updateItem(updated);
    _showSnack('${updated.name} atualizado.');
  }

  void _removeItem(CartItem item) {
    unawaited(LabelPhotoService.delete(item.photoPath));
    ref.read(cartProvider.notifier).removeItem(item.id);
  }

  Future<void> _editBudget() async {
    final current = ref.read(purchaseBudgetProvider);
    final result = await showPurchaseBudgetSheet(
      context,
      initialBudget: current,
    );
    if (!mounted || result == null) return;

    ref.read(purchaseBudgetProvider.notifier).setBudget(result.budget);
    _showSnack(
      result.budget == null
          ? 'Orçamento removido. A compra continua sem teto.'
          : 'Orçamento definido em ${Formatters.currency(result.budget!)}.',
    );
  }

  void _showProofPhoto(CartItem item) {
    final path = item.photoPath;
    if (path == null || path.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                              size: 54,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Não foi possível abrir a foto desta etiqueta.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                right: 4,
                child: Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          'Foto da etiqueta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar foto',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openVoiceInput() {
    _showSnack('Entrada por voz em desenvolvimento. Use a câmera ou o manual.');
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar carrinho?'),
        content: const Text(
          'Todos os itens desta compra serão removidos. '
          'O histórico de compras anteriores não será alterado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    for (final item in ref.read(cartProvider)) {
      await LabelPhotoService.delete(item.photoPath);
    }
    ref.read(cartProvider.notifier).clear();
    ref.read(selectedMarketProvider.notifier).clear();
    ref.read(purchaseBudgetProvider.notifier).clear();
    setState(() {
      _currentAlert = null;
      _sessionSavings = 0;
      _alertedEans.clear();
    });
    _showSnack('Carrinho limpo.');
  }

  Future<void> _chooseMarket() async {
    if (_choosingMarket) return;
    _choosingMarket = true;
    try {
      final result = await showMarketSelectionSheet(context);
      if (!mounted || result.action == MarketSelectionAction.dismissed) {
        return;
      }

      final market = result.market;
      if (market == null) {
        ref.read(selectedMarketProvider.notifier).clear();
        _showSnack(
          'Compra sem mercado: os preços ficarão apenas no seu histórico.',
        );
        return;
      }

      ref.read(selectedMarketProvider.notifier).select(market);
      _showSnack(
        market.isRemoto
            ? 'Comprando em ${market.nome}.'
            : 'Mercado salvo neste dispositivo: ${market.nome}.',
      );
    } finally {
      _choosingMarket = false;
    }
  }

  Future<void> _finishPurchase() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty || _isFinalizing || _finishRequested) return;

    final total = cart.fold<double>(0, (sum, item) => sum + item.totalPrice);
    final count = cart.fold<int>(0, (sum, item) => sum + item.itemCount);

    // Bloqueia o botão e o "Trocar" enquanto o utilizador decide o mercado e
    // confirma. O spinner só aparece depois da confirmação, para não animar
    // indefinidamente atrás do diálogo.
    setState(() => _finishRequested = true);

    try {
      var market = ref.read(selectedMarketProvider);
      if (market == null) {
        final result = await showMarketSelectionSheet(context);
        if (!mounted) return;

        if (result.action == MarketSelectionAction.dismissed) return;
        if (result.isSelected) {
          market = result.market;
          ref.read(selectedMarketProvider.notifier).select(market!);
        } else {
          ref.read(selectedMarketProvider.notifier).clear();
        }
      }

      final confirmed = await _confirmFinish(
        total: total,
        itemCount: count,
        market: market,
      );
      if (confirmed != true || !mounted) return;

      setState(() {
        _finishRequested = false;
        _isFinalizing = true;
      });

      final purchase = Purchase(
        id: const Uuid().v4(),
        storeName: market?.nome ?? 'Compra sem mercado',
        marketId: market != null && market.isRemoto ? market.id : null,
        date: DateTime.now(),
        savings: _sessionSavings,
        items: cart
            .map(
              (item) => PurchaseItem(
                name: item.name,
                unit: item.isByWeight ? 'kg' : item.unit,
                unitPrice: item.unitPrice,
                quantity: item.isByWeight ? 1 : item.quantity,
                weightKg: item.isByWeight ? item.weightKg : null,
              ),
            )
            .toList(),
      );

      final messenger = ScaffoldMessenger.of(context);

      // 1. Fonte de verdade local: o histórico e o total do mês são derivados
      //    imediatamente pelos providers do Riverpod.
      await ref.read(purchaseHistoryProvider.notifier).addPurchase(purchase);

      // 2. Espelho best-effort no Supabase. Sem rede/sessão a compra continua
      //    salva localmente; [CheckoutService.sync] nunca lança.
      final sync = await ref.read(checkoutServiceProvider).sync(purchase);
      if (sync.isPending) {
        debugPrint(
          '[SomaAí] Compra mantida localmente: ${sync.status.name}',
        );
      }

      // 3. Só uma compra finalizada com mercado remoto publica preços. Sem
      //    mercado, o registro é estritamente pessoal.
      _publishCartToCommunity(cart, market);

      // 4. Limpa o carrinho, orçamento e fotos temporárias; volta ao Dashboard.
      for (final item in cart) {
        unawaited(LabelPhotoService.delete(item.photoPath));
      }
      ref.read(cartProvider.notifier).clear();
      ref.read(selectedMarketProvider.notifier).clear();
      ref.read(purchaseBudgetProvider.notifier).clear();

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Compra finalizada com sucesso!')),
        );
    } catch (error, stack) {
      debugPrint('[SomaAí] Falha ao finalizar compra: $error');
      debugPrintStack(stackTrace: stack);
      if (!mounted) return;
      _showSnack('Não foi possível finalizar a compra. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() {
          _isFinalizing = false;
          _finishRequested = false;
        });
      }
    }
  }

  Future<bool?> _confirmFinish({
    required double total,
    required int itemCount,
    required Mercado? market,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Finalizar compra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deseja encerrar esta compra no valor de '
                '${Formatters.currency(total)}?',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                market == null
                    ? '$itemCount ${itemCount == 1 ? 'item será salvo' : 'itens serão salvos'} '
                        'apenas no seu histórico. Nenhum preço será publicado na comunidade.'
                    : '$itemCount ${itemCount == 1 ? 'item será salvo' : 'itens serão salvos'} '
                        'no seu histórico e no total do mês.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: market == null
                      ? AppTheme.background
                      : AppTheme.emeraldTint,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      market == null ? Border.all(color: AppTheme.line) : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      market == null
                          ? Icons.person_rounded
                          : Icons.storefront_rounded,
                      size: 18,
                      color: market == null
                          ? AppTheme.muted
                          : AppTheme.emeraldDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            market?.nome ?? 'Compra sem mercado',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                          ),
                          if (market == null)
                            const Text(
                              'Somente histórico pessoal',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppTheme.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Finalizar'),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final itemCount = ref.watch(cartItemCountProvider);
    final market = ref.watch(selectedMarketProvider);
    final budget = ref.watch(purchaseBudgetProvider);
    final busy = _isFinalizing || _finishRequested;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova compra'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar ao início',
          onPressed: busy ? null : () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Limpar carrinho',
              onPressed: busy ? null : _clearCart,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _MarketSelectorCard(
            market: market,
            onTap: busy ? null : _chooseMarket,
          ),
          const SizedBox(height: 12),
          _TotalCard(
            total: total,
            itemCount: itemCount,
            budget: budget,
            onEditBudget: busy ? null : _editBudget,
          ),
          if (budget != null) ...[
            const SizedBox(height: 10),
            _BudgetCard(
              total: total,
              budget: budget,
              onEditBudget: busy ? null : _editBudget,
            ),
          ],
          if (_currentAlert != null) ...[
            const SizedBox(height: 12),
            PriceAlertBanner(
              alert: _currentAlert!,
              onDismiss: () => setState(() => _currentAlert = null),
              onNavigate: () => _showSnack(
                'Navegar para ${_currentAlert!.storeName} em desenvolvimento.',
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              const Text(
                'Itens da compra',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const Spacer(),
              if (cart.isNotEmpty)
                Text(
                  '${cart.length} ${cart.length == 1 ? 'produto' : 'produtos'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (cart.isEmpty)
            const _EmptyCartCard()
          else
            ...cart.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CartItemCard(
                  item: item,
                  onIncrement: () => ref
                      .read(cartProvider.notifier)
                      .incrementQuantity(item.id),
                  onDecrement: () => ref
                      .read(cartProvider.notifier)
                      .decrementQuantity(item.id),
                  onEdit: () => _editItem(item),
                  onPhoto: item.photoPath == null
                      ? null
                      : () => _showProofPhoto(item),
                  onRemove: () => _removeItem(item),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _CheckoutBar(
        isFinalizing: _isFinalizing,
        canFinalize: cart.isNotEmpty,
        onCamera: busy ? null : _openScanner,
        onManual: busy ? null : _addManualItem,
        onVoice: busy ? null : _openVoiceInput,
        onFinalize: cart.isEmpty || busy ? null : _finishPurchase,
      ),
    );
  }
}

class _MarketSelectorCard extends StatelessWidget {
  final Mercado? market;
  final VoidCallback? onTap;

  const _MarketSelectorCard({required this.market, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = market;
    final isLocal = selected != null && !selected.isRemoto;
    final remoteDetails = selected == null
        ? ''
        : [
            if (selected.localLabel != null) selected.localLabel!,
            if (selected.distanciaLabel != null) selected.distanciaLabel!,
          ].join(' • ');

    return Semantics(
      button: true,
      label: selected == null
          ? 'Mercado não identificado. Escolher mercado.'
          : 'Comprando em ${selected.nome}. Trocar mercado.',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected == null ? AppTheme.amber : AppTheme.line,
              ),
              color: selected == null ? AppTheme.amberTint : Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected == null
                        ? AppTheme.amber.withValues(alpha: 0.15)
                        : AppTheme.emeraldTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    selected == null
                        ? Icons.location_searching_rounded
                        : Icons.storefront_rounded,
                    size: 20,
                    color: selected == null
                        ? const Color(0xFFB26B00)
                        : AppTheme.emeraldDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected == null
                            ? 'Mercado não identificado'
                            : selected.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected == null
                            ? 'Toque para escolher onde está comprando.'
                            : isLocal
                                ? 'Salvo neste dispositivo'
                                : remoteDetails.isEmpty
                                    ? 'Mercado selecionado'
                                    : remoteDetails,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  selected == null ? 'Escolher' : 'Trocar',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.emeraldDark,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.emeraldDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  final int itemCount;
  final double? budget;
  final VoidCallback? onEditBudget;

  const _TotalCard({
    required this.total,
    required this.itemCount,
    required this.budget,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: AppTheme.ctaGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emerald.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'TOTAL DA COMPRA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: budget == null
                    ? 'Definir orçamento da compra'
                    : 'Editar orçamento da compra',
                onPressed: onEditBudget,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
                icon: Icon(
                  budget == null
                      ? Icons.savings_outlined
                      : Icons.savings_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 18,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.currency(total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            itemCount == 0
                ? 'Adicione o primeiro item para começar.'
                : 'O total é atualizado a cada item adicionado.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual identity of the budget card for each spending zone.
class _BudgetZone {
  final Color background;
  final Color border;
  final Color accent;
  final Color strongText;
  final Color mutedText;
  final Color track;
  final String label;

  const _BudgetZone({
    required this.background,
    required this.border,
    required this.accent,
    required this.strongText,
    required this.mutedText,
    required this.track,
    required this.label,
  });
}

_BudgetZone _budgetZone(double ratio, bool exceeded) {
  if (exceeded) {
    return const _BudgetZone(
      background: Color(0xFFFDECEC),
      border: Color(0xFFF04438),
      accent: Color(0xFFF04438),
      strongText: Color(0xFFB42318),
      mutedText: Color(0xFFB5473B),
      track: Color(0xFFF7CFCB),
      label: 'Orçamento estourado',
    );
  }
  if (ratio > 0.75) {
    return const _BudgetZone(
      background: Color(0xFFFFF6E0),
      border: Color(0xFFF5A524),
      accent: Color(0xFFF5A524),
      strongText: Color(0xFF8A5A00),
      mutedText: Color(0xFFA8761F),
      track: Color(0xFFFBE3AE),
      label: 'Atenção: perto do teto',
    );
  }
  return const _BudgetZone(
    background: Color(0xFFE8F7EF),
    border: Color(0xFF12B76A),
    accent: Color(0xFF12B76A),
    strongText: Color(0xFF07603F),
    mutedText: Color(0xFF3E7A63),
    track: Color(0xFFCFEEDD),
    label: 'Zona segura',
  );
}

/// Budget tracker card whose whole identity (background, border, text and
/// progress bar) changes with the share of the budget already spent.
class _BudgetCard extends StatelessWidget {
  final double total;
  final double budget;
  final VoidCallback? onEditBudget;

  const _BudgetCard({
    required this.total,
    required this.budget,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total / budget;
    final exceeded = total > budget;
    final zone = _budgetZone(ratio, exceeded);
    final remaining = budget - total;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(16, 13, 10, 14),
      decoration: BoxDecoration(
        color: zone.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: zone.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: zone.accent.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: zone.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  exceeded
                      ? Icons.warning_amber_rounded
                      : Icons.savings_rounded,
                  size: 17,
                  color: zone.strongText,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orçamento ${Formatters.currency(budget)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: zone.strongText,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      zone.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: zone.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar orçamento',
                onPressed: onEditBudget,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 17,
                  color: zone.strongText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: ratio.clamp(0.0, 1.0),
            ),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: zone.accent),
                duration: const Duration(milliseconds: 350),
                builder: (context, color, __) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 9,
                      color: color ?? zone.accent,
                      backgroundColor: zone.track,
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  exceeded
                      ? 'Excedeu ${Formatters.currency(-remaining)}'
                      : 'Ainda pode gastar ${Formatters.currency(remaining)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: zone.strongText,
                  ),
                ),
              ),
              Text(
                '${Formatters.currency(total)} de ${Formatters.currency(budget)}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: zone.mutedText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCartCard extends StatelessWidget {
  const _EmptyCartCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: AppTheme.emeraldTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_basket_rounded,
              color: AppTheme.emeraldDark,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Seu carrinho está vazio',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Toque em "Ler Etiquetas (Câmera)" para escanear um preço, '
            'ou adicione manualmente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback? onPhoto;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onPhoto,
    required this.onRemove,
  });

  IconData get _sourceIcon {
    switch (item.source) {
      case ScanSource.camera:
        return Icons.photo_camera_rounded;
      case ScanSource.voice:
        return Icons.mic_rounded;
      case ScanSource.manual:
        return Icons.keyboard_rounded;
    }
  }

  String get _sourceLabel {
    switch (item.source) {
      case ScanSource.camera:
        return 'Câmera';
      case ScanSource.voice:
        return 'Voz';
      case ScanSource.manual:
        return 'Manual';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemThumbnail(
            key: ValueKey('cart_thumbnail_${item.id}'),
            photoPath: item.photoPath,
            fallbackIcon: _sourceIcon,
            onTap: onPhoto,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                    _CardIconButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Editar item',
                      onPressed: onEdit,
                    ),
                    _CardIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Remover item',
                      onPressed: onRemove,
                    ),
                  ],
                ),
                Text(
                  '${Formatters.currency(item.unitPrice)} / ${item.priceUnit} '
                  '• $_sourceLabel',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QuantityStepper(
                      label: item.isByWeight
                          ? Formatters.weight(item.weightKg)
                          : '${item.quantity}',
                      isWeight: item.isByWeight,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                    ),
                    const Spacer(),
                    Text(
                      Formatters.currency(item.totalPrice),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.emeraldDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Square thumbnail shown at the start of each cart item card.
///
/// When the item has a captured shelf-proof photo it is rendered (and tapping
/// it opens the fullscreen viewer); otherwise a discreet source icon is shown
/// for items added manually, by voice or by camera without a picture.
class _ItemThumbnail extends StatelessWidget {
  static const double _size = 48;

  final String? photoPath;
  final IconData fallbackIcon;
  final VoidCallback? onTap;

  const _ItemThumbnail({
    super.key,
    required this.photoPath,
    required this.fallbackIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final hasPhoto = path != null && path.isNotEmpty;

    if (!hasPhoto) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: AppTheme.emeraldTint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(fallbackIcon, size: 21, color: AppTheme.emeraldDark),
      );
    }

    return Semantics(
      button: onTap != null,
      label: 'Prova de prateleira',
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Material(
            color: AppTheme.emeraldTint,
            child: InkWell(
              onTap: onTap,
              child: Tooltip(
                message: 'Ver foto da etiqueta',
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    fallbackIcon,
                    size: 21,
                    color: AppTheme.emeraldDark,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _CardIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 18, color: AppTheme.muted),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final String label;
  final bool isWeight;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QuantityStepper({
    required this.label,
    required this.isWeight,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            tooltip: isWeight ? 'Diminuir peso' : 'Diminuir quantidade',
            onPressed: onDecrement,
          ),
          SizedBox(
            width: isWeight ? 58 : 28,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            tooltip: isWeight ? 'Aumentar peso' : 'Aumentar quantidade',
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 17, color: AppTheme.emeraldDark),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final bool isFinalizing;
  final bool canFinalize;
  final VoidCallback? onCamera;
  final VoidCallback? onManual;
  final VoidCallback? onVoice;
  final VoidCallback? onFinalize;

  const _CheckoutBar({
    required this.isFinalizing,
    required this.canFinalize,
    required this.onCamera,
    required this.onManual,
    required this.onVoice,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppTheme.line)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.photo_camera_rounded, size: 21),
                label: const Text('Ler Etiquetas (Câmera)'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onManual,
                    icon: const Icon(Icons.keyboard_rounded, size: 19),
                    label: const Text('Manual'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onVoice,
                    icon: const Icon(Icons.mic_rounded, size: 19),
                    label: const Text('Voz'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canFinalize ? onFinalize : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emeraldDark,
                  disabledBackgroundColor: AppTheme.line,
                  disabledForegroundColor: AppTheme.muted,
                  minimumSize: const Size(0, 56),
                ),
                child: isFinalizing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 21),
                          SizedBox(width: 8),
                          Text('Finalizar Compra'),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
