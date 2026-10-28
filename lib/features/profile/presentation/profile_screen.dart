import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/session_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/somaai_logo.dart';
import '../../auth/presentation/login_screen.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import '../../cart/presentation/providers/purchase_budget_provider.dart';
import '../../community/presentation/providers/market_provider.dart';
import '../../community_alerts/presentation/providers/alert_preferences_provider.dart';
import '../../home/presentation/providers/purchase_history_provider.dart';
import '../../home/presentation/providers/dashboard_period_provider.dart';
import 'providers/profile_provider.dart';

/// Aba Perfil: dados do utilizador, estatísticas e preferências.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _pushEnabled = true;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final purchases = ref.watch(purchaseHistoryProvider);
    final savings = ref.watch(lifetimeSavingsProvider);
    final alertPrefs = ref.watch(alertPreferencesProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Perfil',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SomaAiLogo(size: 40, showShadow: false),
            ],
          ),
          const SizedBox(height: 16),
          _ProfileCard(profile: profile),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.shopping_basket_rounded,
                    label: 'Compras',
                    value: '${purchases.length}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.savings_rounded,
                    label: 'Economia',
                    value: Formatters.currency(savings),
                    valueColor: AppTheme.emerald,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: _StatCard(
                    icon: Icons.favorite_rounded,
                    label: 'Ajudas',
                    value: '12',
                    valueColor: AppTheme.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Mercados favoritos'),
          const SizedBox(height: 10),
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _FavoriteMarket(name: 'Extra', icon: Icons.storefront_rounded),
                _FavoriteMarket(name: 'Assaí', icon: Icons.warehouse_rounded),
                _FavoriteMarket(
                    name: 'Carrefour', icon: Icons.local_grocery_store_rounded),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Preferências'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.radar_rounded,
                  title: 'Alertas da comunidade',
                  subtitle:
                      'Avisar quando o preço estiver mais baixo por perto',
                  trailing: Switch.adaptive(
                    value: alertPrefs.alertsEnabled,
                    activeTrackColor: AppTheme.emerald,
                    onChanged: (value) => ref
                        .read(alertPreferencesProvider.notifier)
                        .toggleAlerts(value),
                  ),
                ),
                const Divider(height: 1, indent: 60),
                _SettingTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Notificações',
                  subtitle: 'Lembretes e novidades do SomaAí',
                  trailing: Switch.adaptive(
                    value: _pushEnabled,
                    activeTrackColor: AppTheme.emerald,
                    onChanged: (value) => setState(() => _pushEnabled = value),
                  ),
                ),
                const Divider(height: 1, indent: 60),
                _SettingTile(
                  icon: Icons.near_me_rounded,
                  title: 'Distância dos alertas',
                  subtitle: 'Raio de busca de ofertas',
                  trailing: Text(
                    '${alertPrefs.maxDistanceKm} km',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.emerald,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () => _showDistanceSheet(alertPrefs.maxDistanceKm),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Ajuda e suporte',
                  subtitle: 'Como usar o SomaAí',
                  onTap: () => _showSimpleDialog(
                    title: 'Como usar',
                    message: '1. Toque em "Iniciar nova compra".\n'
                        '2. Adicione itens pela câmera, manual ou voz.\n'
                        '3. Ajuste as quantidades no carrinho.\n'
                        '4. Toque em "Finalizar Compra" para guardar no histórico.',
                  ),
                ),
                const Divider(height: 1, indent: 60),
                _SettingTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Sobre o SomaAí',
                  subtitle: 'Versão 1.0.0',
                  onTap: () => _showSimpleDialog(
                    title: 'SomaAí',
                    message: 'Sem sustos no caixa.\n\n'
                        'Uma calculadora de supermercado que soma os preços '
                        'pela câmera e avisa onde o vizinho encontrou mais barato.',
                  ),
                ),
                const Divider(height: 1, indent: 60),
                _SettingTile(
                  icon: Icons.logout_rounded,
                  iconColor: AppTheme.red,
                  title: profile.isGuest
                      ? 'Sair do modo visitante'
                      : 'Sair da conta',
                  subtitle: profile.isGuest
                      ? 'Apagar os dados locais e voltar ao login'
                      : 'Encerrar sessão e limpar dados locais',
                  titleColor: AppTheme.red,
                  onTap: _confirmLogout,
                ),
                const Divider(height: 1, indent: 60),
                _SettingTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: AppTheme.red,
                  title: 'Limpar histórico',
                  subtitle: 'Apagar todas as compras salvas',
                  titleColor: AppTheme.red,
                  onTap: _confirmClearHistory,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'SomaAí • feito para somar, não para assustar',
              style: TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text(
          'Todas as compras salvas neste dispositivo serão apagadas. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            child: const Text('Limpar tudo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(purchaseHistoryProvider.notifier).clearHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Histórico limpo.')),
        );
    }
  }

  Future<void> _confirmLogout() async {
    final isGuest = ref.read(userProfileProvider).isGuest;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isGuest ? 'Sair do modo visitante?' : 'Sair da conta?'),
        content: Text(
          isGuest
              ? 'Seu apelido, carrinho e compras salvas neste aparelho serão '
                  'apagados. Você voltará para a tela de login.'
              : 'Ao sair da conta, todos os dados locais serão limpos. '
                  'Você voltará para a tela de login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (isGuest) {
      // Nada de Supabase: apenas limpa o estado local do visitante.
      ref.read(cartProvider.notifier).clear();
      ref.read(selectedMarketProvider.notifier).clear();
      await ref.read(purchaseHistoryProvider.notifier).clearHistory();
      await ref.read(guestSessionProvider.notifier).clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    if (mounted) {
      // 1. Sign out from Supabase
      await SupabaseService.signOut();

      // 2. Invalidate ALL Riverpod providers to clear state
      ref.invalidate(purchaseHistoryProvider);
      ref.invalidate(cartProvider);
      ref.invalidate(purchaseBudgetProvider);
      ref.invalidate(dashboardPeriodProvider);
      ref.invalidate(alertPreferencesProvider);
      ref.invalidate(userProfileProvider);

      // Navigate to login screen (AuthGate will handle redirect)
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showSimpleDialog({required String title, required String message}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  void _showDistanceSheet(int current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.line,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Distância dos alertas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Até onde o SomaAí procura ofertas mais baratas.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [1, 3, 5, 10, 15, 25].map((km) {
                  final selected = km == current;
                  return ChoiceChip(
                    label: Text('$km km'),
                    selected: selected,
                    onSelected: (_) {
                      ref
                          .read(alertPreferencesProvider.notifier)
                          .updateMaxDistance(km);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserProfile profile;

  const _ProfileCard({required this.profile});

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
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.place_rounded,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      profile.city,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Desde ${profile.memberSinceLabel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Edição de perfil chega na próxima versão.'),
                  ),
                );
            },
            tooltip: 'Editar perfil',
            icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = AppTheme.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 19, color: valueColor),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: valueColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteMarket extends StatelessWidget {
  final String name;
  final IconData icon;

  const _FavoriteMarket({required this.name, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppTheme.emerald),
          const Spacer(),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const Text(
            'favorito',
            style: TextStyle(fontSize: 9.5, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (iconColor ?? AppTheme.emerald).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? AppTheme.emerald,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.muted,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppTheme.ink,
      ),
    );
  }
}
