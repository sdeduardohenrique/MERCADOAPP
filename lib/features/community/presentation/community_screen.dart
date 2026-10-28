import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/models/community_offer.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/login_screen.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import '../../home/presentation/providers/purchase_history_provider.dart';
import '../domain/community_service.dart';
import 'providers/community_filter_provider.dart';
import 'providers/market_provider.dart';
import 'widgets/community_location_sheet.dart';
import 'widgets/community_offer_details_sheet.dart';
import 'widgets/guest_community_lock.dart';
import 'widgets/offer_contribution_sheet.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  int _filter = 0;

  Future<void> _openLocation() async {
    final current = ref.read(communityFilterProvider);
    final selected = await showCommunityLocationSheet(
      context,
      current: current,
    );
    if (!mounted || selected == null) return;
    ref.read(communityFilterProvider.notifier).apply(selected);
  }

  Future<void> _openContribution() async {
    final published = await showOfferContributionSheet(context);
    if (!mounted || published != true) return;

    ref.invalidate(communityOffersProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Oferta publicada! Obrigado por ajudar a vizinhança.'),
        ),
      );
  }

  Future<void> _refresh() async {
    ref.invalidate(communityOffersProvider);
    try {
      await ref.read(communityOffersProvider.future);
    } catch (_) {
      // O estado de erro é renderizado pelo próprio provider.
    }
  }

  /// Encerra o modo visitante, apaga a memória local e deixa o AuthGate
  /// levar para a tela de login/cadastro.
  Future<void> _createAccountFromGuest() async {
    ref.read(cartProvider.notifier).clear();
    ref.read(selectedMarketProvider.notifier).clear();
    await ref.read(purchaseHistoryProvider.notifier).clearHistory();
    await ref.read(guestSessionProvider.notifier).clear();
    if (!mounted) return;
    // O AuthGate pode não estar no topo da pilha (AppShell é uma rota nova),
    // por isso navegamos explicitamente para o login/cadastro.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _selectFilter(int index) {
    final current = ref.read(communityFilterProvider);

    if (index == 2) {
      if (current.hasCity && current.hasCoordinates) {
        ref.read(communityFilterProvider.notifier).useNearby(
              latitude: current.latitude!,
              longitude: current.longitude!,
              radiusKm: current.radiusKm,
            );
      } else if (!current.hasCoordinates) {
        _openLocation();
      }
    }

    setState(() => _filter = index);
  }

  List<CommunityOffer> _sorted(List<CommunityOffer> source) {
    final list = [...source];
    switch (_filter) {
      case 1:
        list.sort((a, b) {
          final byDiscount = b.savingsPercentage.compareTo(a.savingsPercentage);
          if (byDiscount != 0) return byDiscount;
          return b.capturedAt.compareTo(a.capturedAt);
        });
        return list;
      case 2:
        list.sort((a, b) {
          final aDistance = a.distanceKm;
          final bDistance = b.distanceKm;
          if (aDistance == null && bDistance == null) {
            return b.capturedAt.compareTo(a.capturedAt);
          }
          if (aDistance == null) return 1;
          if (bDistance == null) return -1;
          return aDistance.compareTo(bDistance);
        });
        return list;
      default:
        list.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
        return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bloqueio antes de qualquer leitura: visitante nunca consulta a nuvem.
    if (ref.watch(isGuestProvider)) {
      return GuestCommunityLock(
        onCreateAccount: _createAccountFromGuest,
      );
    }

    final offersAsync = ref.watch(communityOffersProvider);
    final filter = ref.watch(communityFilterProvider);
    final offers = _sorted(offersAsync.valueOrNull ?? const []);
    final firstLoad = offersAsync.isLoading && !offersAsync.hasValue;
    final showSkeleton = firstLoad;
    final error = offersAsync.hasError ? offersAsync.error : null;
    final showError = error != null && !offersAsync.hasValue;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.emerald,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Radar de ofertas',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Preços achados pela comunidade perto de você.',
                        style: TextStyle(fontSize: 13, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppTheme.amberTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    color: Color(0xFFB26B00),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LocationPill(
              filter: filter,
              resolving: false,
              onTap: _openLocation,
            ),
            const SizedBox(height: 16),
            _CommunityImpactCard(
              offers: offers,
              loading: showSkeleton,
              online: !showError,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'Recentes',
                    icon: Icons.schedule_rounded,
                    selected: _filter == 0,
                    onTap: () => _selectFilter(0),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Descontos',
                    icon: Icons.local_fire_department_rounded,
                    selected: _filter == 1,
                    onTap: () => _selectFilter(1),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Perto de mim',
                    icon: Icons.near_me_rounded,
                    selected: _filter == 2,
                    onTap: () => _selectFilter(2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (showSkeleton)
              const _OffersLoading()
            else if (showError)
              _CommunityError(
                message: _errorMessage(error),
                onRetry: _refresh,
              )
            else if (offers.isEmpty)
              _EmptyOffers(onContribute: _openContribution)
            else
              ...offers.map(
                (offer) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OfferCard(
                    offer: offer,
                    onTap: () => showCommunityOfferDetails(context, offer),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _ContributeCard(onTap: _openContribution),
          ],
        ),
      ),
    );
  }

  String _errorMessage(Object? error) {
    if (error is CommunityServiceException) return error.message;
    return 'Não foi possível carregar as ofertas da comunidade agora.';
  }
}

class _LocationPill extends StatelessWidget {
  final CommunityFilter filter;
  final bool resolving;
  final VoidCallback onTap;

  const _LocationPill({
    required this.filter,
    required this.resolving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Região: ${filter.label}. Alterar localização ou raio de busca.',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: resolving ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: AppTheme.emeraldTint,
                    shape: BoxShape.circle,
                  ),
                  child: resolving
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.near_me_rounded,
                          size: 16,
                          color: AppTheme.emeraldDark,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resolving ? 'Obtendo sua localização...' : filter.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      Text(
                        filter.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Alterar',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.emeraldDark,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
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

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppTheme.emerald : Colors.white,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: selected ? AppTheme.emerald : AppTheme.line,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppTheme.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
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

class _CommunityImpactCard extends StatelessWidget {
  final List<CommunityOffer> offers;
  final bool loading;
  final bool online;

  const _CommunityImpactCard({
    required this.offers,
    required this.loading,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    final savings = offers.fold<double>(
      0,
      (sum, offer) => sum + offer.savings,
    );
    final showValue = online && !loading;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.lime.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: AppTheme.lime,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Economia mapeada',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  showValue ? Formatters.currency(savings) : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  !online
                      ? 'Radar temporariamente offline'
                      : loading
                          ? 'Buscando ofertas ativas...'
                          : offers.isEmpty
                              ? 'Nenhuma oferta ativa nesta região'
                              : offers.length == 1
                                  ? 'em 1 oferta ativa'
                                  : 'em ${offers.length} ofertas ativas',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: online ? AppTheme.emeraldBright : AppTheme.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              online ? 'AO VIVO' : 'OFFLINE',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 9.5,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatefulWidget {
  final CommunityOffer offer;
  final VoidCallback onTap;

  const _OfferCard({required this.offer, required this.onTap});

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  late int _confirmations = widget.offer.confirmations;
  bool _confirmed = false;

  void _confirm() {
    if (_confirmed) return;
    setState(() {
      _confirmed = true;
      _confirmations++;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Obrigado! Você confirmou o preço de ${widget.offer.productName}.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;

    return Semantics(
      button: true,
      label: '${offer.productName}, ${Formatters.currency(offer.price)} '
          'no ${offer.marketName}. Toque para ver detalhes e rota.',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.line),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (offer.brand != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              offer.brand!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.storefront_rounded,
                                size: 14,
                                color: AppTheme.muted,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  offer.marketLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (offer.hasImage) ...[
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: CachedNetworkImage(
                            imageUrl: offer.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ColoredBox(
                              color: AppTheme.background,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => const ColoredBox(
                              color: AppTheme.background,
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.currency(offer.price),
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.emerald,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '/ ${offer.unitLabel}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (offer.oldPrice != null) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          Formatters.currency(offer.oldPrice!),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (offer.savingsPercentage > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.lime,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '−${Formatters.percent(offer.savingsPercentage)}',
                          style: const TextStyle(
                            color: AppTheme.emeraldDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      )
                    else if (offer.distanceLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.line),
                        ),
                        child: Text(
                          offer.distanceLabel,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: AppTheme.emeraldTint,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        offer.contributorInitials,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.emeraldDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${offer.contributorLabel} • ${offer.ageLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                    if (offer.distanceLabel.isNotEmpty) ...[
                      const Icon(
                        Icons.near_me_rounded,
                        size: 12,
                        color: AppTheme.emerald,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        offer.distanceLabel,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '$_confirmations',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Semantics(
                      button: true,
                      label: 'Confirmar preço',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _confirm,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            _confirmed
                                ? Icons.thumb_up_alt_rounded
                                : Icons.thumb_up_alt_outlined,
                            size: 18,
                            color:
                                _confirmed ? AppTheme.emerald : AppTheme.muted,
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppTheme.muted,
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

class _OffersLoading extends StatelessWidget {
  const _OffersLoading();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE9ECE8),
      highlightColor: Colors.white,
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
            height: 154,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.line),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _CommunityError({required this.message, required this.onRetry});

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
          const Icon(Icons.cloud_off_rounded, size: 36, color: AppTheme.amber),
          const SizedBox(height: 8),
          const Text(
            'Não foi possível carregar o radar',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  final VoidCallback onContribute;

  const _EmptyOffers({required this.onContribute});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          const Icon(Icons.radar_rounded, size: 34, color: AppTheme.amber),
          const SizedBox(height: 8),
          const Text(
            'Nenhuma oferta nesta região',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Amplie a distância, escolha outra cidade ou seja o primeiro a '
            'compartilhar um preço.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onContribute,
            icon: const Icon(Icons.add_a_photo_rounded, size: 18),
            label: const Text('Publicar primeira oferta'),
          ),
        ],
      ),
    );
  }
}

class _ContributeCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ContributeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Fotografar oferta e publicar na comunidade',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.amberTint,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.amber.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    color: Color(0xFFB26B00),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Encontrou um preço melhor?',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Fotografe a etiqueta e ajude a vizinhança a economizar.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB26B00),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.photo_camera_rounded, size: 20),
                label: const Text('Fotografar oferta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
