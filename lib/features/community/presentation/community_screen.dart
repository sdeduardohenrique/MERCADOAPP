import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../profile/presentation/providers/profile_provider.dart';

/// Oferta comunitária (mock estruturado).
///
/// No futuro estes campos vêm do Supabase/PostGIS:
/// `product_name`, `store_name`, `store_chain`, `price`, `old_price`,
/// `distance_km`, `confirmation_count`, `created_at`, `contributor_name`.
class CommunityOffer {
  final String id;
  final String productName;
  final String storeName;
  final String storeChain;
  final String unit;
  final double price;
  final double oldPrice;
  final double distanceKm;
  final int confirmations;
  final String contributor;
  final Duration age;

  const CommunityOffer({
    required this.id,
    required this.productName,
    required this.storeName,
    required this.storeChain,
    required this.unit,
    required this.price,
    required this.oldPrice,
    required this.distanceKm,
    required this.confirmations,
    required this.contributor,
    required this.age,
  });

  double get savings => oldPrice > price ? oldPrice - price : 0;

  double get savingsPercentage =>
      oldPrice <= 0 ? 0 : (savings / oldPrice) * 100;

  String get ageLabel {
    if (age.inMinutes < 60) return 'há ${age.inMinutes} min';
    if (age.inHours < 24) return 'há ${age.inHours}h';
    return 'há ${age.inDays} dias';
  }
}

const _mockOffers = <CommunityOffer>[
  CommunityOffer(
    id: 'offer-1',
    productName: 'Leite integral 1L',
    storeName: 'Mercado do Bairro',
    storeChain: 'Rede Local',
    unit: 'un',
    price: 3.89,
    oldPrice: 5.49,
    distanceKm: 0.8,
    confirmations: 34,
    contributor: 'Ana Paula',
    age: Duration(hours: 2, minutes: 20),
  ),
  CommunityOffer(
    id: 'offer-2',
    productName: 'Arroz branco 5kg',
    storeName: 'Assaí Atacadista',
    storeChain: 'Assaí',
    unit: 'un',
    price: 24.90,
    oldPrice: 31.90,
    distanceKm: 2.4,
    confirmations: 51,
    contributor: 'Carlos Souza',
    age: Duration(hours: 5),
  ),
  CommunityOffer(
    id: 'offer-3',
    productName: 'Café torrado 500g',
    storeName: 'Supermercado Extra',
    storeChain: 'Extra',
    unit: 'un',
    price: 15.99,
    oldPrice: 21.90,
    distanceKm: 1.2,
    confirmations: 27,
    contributor: 'Marina Lima',
    age: Duration(hours: 8, minutes: 10),
  ),
  CommunityOffer(
    id: 'offer-4',
    productName: 'Frango inteiro (kg)',
    storeName: 'Carrefour',
    storeChain: 'Carrefour',
    unit: 'kg',
    price: 12.49,
    oldPrice: 16.90,
    distanceKm: 3.1,
    confirmations: 19,
    contributor: 'João Pedro',
    age: Duration(hours: 12),
  ),
  CommunityOffer(
    id: 'offer-5',
    productName: 'Banana prata (kg)',
    storeName: 'Hortifruti da Praça',
    storeChain: 'Local',
    unit: 'kg',
    price: 3.99,
    oldPrice: 6.99,
    distanceKm: 0.4,
    confirmations: 42,
    contributor: 'Bete Alves',
    age: Duration(days: 1, hours: 3),
  ),
  CommunityOffer(
    id: 'offer-6',
    productName: 'Detergente 500ml',
    storeName: 'Pão de Açúcar',
    storeChain: 'Pão de Açúcar',
    unit: 'un',
    price: 2.29,
    oldPrice: 3.49,
    distanceKm: 1.9,
    confirmations: 15,
    contributor: 'Rafa Nunes',
    age: Duration(days: 1, hours: 9),
  ),
];

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  int _filter = 0;

  List<CommunityOffer> get _offers {
    final list = [..._mockOffers];
    switch (_filter) {
      case 1:
        list.sort((a, b) => b.savingsPercentage.compareTo(a.savingsPercentage));
        return list;
      case 2:
        list.retainWhere((o) => o.distanceKm <= 2);
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        return list;
      default:
        list.sort((a, b) => a.age.compareTo(b.age));
        return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.near_me_rounded,
                  size: 15,
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 6),
                Text(
                  profile.city,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _CommunityImpactCard(),
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Mais recentes',
                  icon: Icons.schedule_rounded,
                  selected: _filter == 0,
                  onTap: () => setState(() => _filter = 0),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Maiores descontos',
                  icon: Icons.local_fire_department_rounded,
                  selected: _filter == 1,
                  onTap: () => setState(() => _filter = 1),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Perto de mim',
                  icon: Icons.near_me_rounded,
                  selected: _filter == 2,
                  onTap: () => setState(() => _filter = 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_offers.isEmpty)
            const _EmptyOffers()
          else
            ..._offers.map(
              (offer) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OfferCard(offer: offer),
              ),
            ),
          const SizedBox(height: 8),
          const _ContributeCard(),
        ],
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
  const _CommunityImpactCard();

  @override
  Widget build(BuildContext context) {
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Economia da comunidade',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  r'R$ 4.280,00',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'nesta semana, em 1.204 contribuições',
                  style: TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.emeraldBright,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '+18%',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
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

  const _OfferCard({required this.offer});

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
    final initials = offer.contributor
        .trim()
        .split(RegExp(r'\s+'))
        .map((p) => p.substring(0, 1))
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
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
                            '${offer.storeName} • ${offer.storeChain}',
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
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
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                  '/ ${offer.unit}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  Formatters.currency(offer.oldPrice),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              const Spacer(),
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
                child: Row(
                  children: [
                    const Icon(
                      Icons.near_me_rounded,
                      size: 12,
                      color: AppTheme.emerald,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${offer.distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
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
                  initials,
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
                  '${offer.contributor} • ${offer.ageLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.muted,
                  ),
                ),
              ),
              Text(
                '$_confirmations',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: 'Confirmar Preço',
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
                      color: _confirmed ? AppTheme.emerald : AppTheme.muted,
                    ),
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

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.line),
      ),
      child: const Column(
        children: [
          Icon(Icons.radar_rounded, size: 34, color: AppTheme.amber),
          SizedBox(height: 8),
          Text(
            'Nenhuma oferta por perto',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink),
          ),
          SizedBox(height: 4),
          Text(
            'Amplie a distância ou contribua com o primeiro preço.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _ContributeCard extends StatelessWidget {
  const _ContributeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.amberTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
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
                  'Fotografe a etiqueta no scanner e ajude a vizinhança a economizar.',
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
