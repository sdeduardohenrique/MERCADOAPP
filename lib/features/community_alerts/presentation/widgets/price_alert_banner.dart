import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/community_price.dart';
import '../providers/alert_preferences_provider.dart';

/// Banner showing better price alert from community
class PriceAlertBanner extends StatelessWidget {
  final CommunityPriceAlert alert;
  final VoidCallback onDismiss;
  final VoidCallback onNavigate;

  const PriceAlertBanner({
    super.key,
    required this.alert,
    required this.onDismiss,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon and dismiss
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_offer,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preço melhor encontrado! 🎯',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${alert.storeName} (${alert.storeChain}) • ${alert.distanceKm.toStringAsFixed(1)} km',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: onDismiss,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Price comparison
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.attach_money,
                      label: 'Lá: ${NumberFormat.currency(locale: "pt_BR", symbol: "R\$ ").format(alert.communityPrice)}',
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.trending_down,
                      label: 'Economia: ${NumberFormat.currency(locale: "pt_BR", symbol: "R\$ ").format(alert.savings)} (${alert.savingsPercentage.toStringAsFixed(0)}%)',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Source info
                if (alert.confirmationCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_user,
                          color: Colors.white.withOpacity(0.8),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Confirmado por ${alert.confirmationCount} usuário${alert.confirmationCount != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          color: Colors.white.withOpacity(0.8),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_timeAgo(alert.capturedAt)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Action buttons
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Ir até lá'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: onNavigate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Comprar aqui'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: onDismiss,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().slideY(
            begin: -0.3,
            duration: 300.ms,
            curve: Curves.easeOutCubic,
          ).fadeIn(),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Community alerts toggle widget
class CommunityAlertsToggle extends ConsumerWidget {
  const CommunityAlertsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(alertPreferencesProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            prefs.alertsEnabled ? Icons.notifications_active : Icons.notifications_off,
            color: prefs.alertsEnabled ? Colors.greenAccent : Colors.white54,
            size: 20,
          ),
          const SizedBox(width: 8),
          Switch(
            value: prefs.alertsEnabled,
            onChanged: (v) => ref.read(alertPreferencesProvider.notifier).toggleAlerts(v),
            activeColor: Colors.greenAccent,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.shade800,
          ),
          const SizedBox(width: 8),
          Text(
            'Alertas',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}