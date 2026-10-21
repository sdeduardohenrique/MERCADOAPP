import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/community_offer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';

Future<void> showCommunityOfferDetails(
  BuildContext context,
  CommunityOffer offer,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommunityOfferDetailsSheet(offer: offer),
  );
}

class CommunityOfferDetailsSheet extends StatelessWidget {
  final CommunityOffer offer;

  const CommunityOfferDetailsSheet({super.key, required this.offer});

  Future<void> _openMap(
    BuildContext context, {
    required bool waze,
  }) async {
    final destination = offer.mapDestination;
    if (destination == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Este mercado ainda não tem endereço cadastrado.'),
          ),
        );
      return;
    }

    final encoded = Uri.encodeComponent(destination);
    final uri = waze
        ? Uri.parse('https://waze.com/ul?q=$encoded&navigate=yes')
        : offer.hasCoordinates
            ? Uri.parse(
                'https://www.google.com/maps/dir/?api=1&destination=$encoded&travelmode=driving',
              )
            : Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=$encoded',
              );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        _showMapError(context);
      }
    } catch (_) {
      if (context.mounted) _showMapError(context);
    }
  }

  void _showMapError(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir o aplicativo de mapas neste dispositivo.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.9;
    final hasDestination = offer.mapDestination != null;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.line,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Detalhes da oferta',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (offer.hasImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: CachedNetworkImage(
                          imageUrl: offer.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const ColoredBox(
                            color: AppTheme.background,
                            child: Center(
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const _PhotoFallback(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const _PhotoFallback(),
                    const SizedBox(height: 16),
                  ],
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
                                fontSize: 21,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink,
                                letterSpacing: -0.4,
                              ),
                            ),
                            if (offer.brand != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                offer.brand!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (offer.savingsPercentage > 0)
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
                              fontSize: 12,
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
                          fontSize: 32,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.emerald,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/ ${offer.unitLabel}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                      if (offer.oldPrice != null) ...[
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            Formatters.currency(offer.oldPrice!),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  _InfoCard(
                    icon: Icons.storefront_rounded,
                    title: offer.marketLabel,
                    subtitle: offer.fullAddress.isEmpty
                        ? 'Endereço não informado'
                        : offer.fullAddress,
                    trailing: offer.distanceLabel.isEmpty
                        ? null
                        : offer.distanceLabel,
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.schedule_rounded,
                    title: 'Reportado ${offer.ageLabel}',
                    subtitle:
                        'Por ${offer.contributorLabel} • ${offer.confirmationsLabel}',
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Abrir rota no mapa',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!hasDestination)
                    const Text(
                      'O mercado ainda não tem endereço ou coordenadas. A rota '
                      'ficará disponível quando o cadastro for atualizado.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppTheme.muted,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openMap(context, waze: false),
                            icon: const Icon(
                              Icons.directions_rounded,
                              size: 19,
                            ),
                            label: const Text('Google Maps'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openMap(context, waze: true),
                            icon: const Icon(
                              Icons.navigation_rounded,
                              size: 19,
                            ),
                            label: const Text('Waze'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.emeraldTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: AppTheme.emeraldDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.emeraldDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 116,
      decoration: BoxDecoration(
        color: AppTheme.emeraldTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.emerald.withValues(alpha: 0.12),
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            color: AppTheme.emeraldDark,
            size: 30,
          ),
          SizedBox(height: 6),
          Text(
            'Sem foto da etiqueta',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.emeraldDark,
            ),
          ),
        ],
      ),
    );
  }
}
