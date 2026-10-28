import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../community/presentation/community_screen.dart';
import '../../home/presentation/home_dashboard_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../shopping_list/presentation/shopping_lists_screen.dart';
import 'providers/shell_tab_provider.dart';

/// Casca principal do app com as 4 abas.
///
/// Usa `IndexedStack` para preservar o estado de cada aba (scroll, filtros,
/// formulários) ao alternar entre elas. A aba ativa fica num provider para
/// que atalhos internos (ex.: card da Home) naveguem sem acoplamento.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// As abas só são construídas quando visitadas. Isso evita pedir GPS ou
  /// consultar a comunidade enquanto o utilizador ainda está no Dashboard.
  final List<Widget?> _screens = <Widget?>[
    const HomeDashboardScreen(),
    null,
    null,
    null,
  ];

  static Widget _screenFor(int index) {
    switch (index) {
      case 1:
        return const ShoppingListsScreen();
      case 2:
        return const CommunityScreen();
      case 3:
        return const ProfileScreen();
      case 0:
      default:
        return const HomeDashboardScreen();
    }
  }

  void _selectTab(int index) {
    if (ref.read(shellTabProvider) == index) return;
    ref.read(shellTabProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final rawIndex = ref.watch(shellTabProvider);
    final index = rawIndex >= 0 && rawIndex <= 3 ? rawIndex : 0;

    // Constrói a aba no primeiro acesso. A mutação é apenas um cache local;
    // não chamamos setState porque a seleção já veio de um rebuild.
    if (_screens[index] == null) {
      _screens[index] = _screenFor(index);
    }

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < _screens.length; i++)
            _screens[i] ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppTheme.line),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: index,
            onTap: _selectTab,
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.emeraldDark,
            unselectedItemColor: AppTheme.muted,
            selectedFontSize: 10.5,
            unselectedFontSize: 10,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, size: 24),
                activeIcon: Icon(Icons.home_rounded, size: 25),
                label: 'Início',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_outlined, size: 24),
                activeIcon: Icon(Icons.list_alt_rounded, size: 25),
                label: 'Minhas Listas',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.radar_outlined, size: 24),
                activeIcon: Icon(Icons.radar_rounded, size: 25),
                label: 'Comunidade',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded, size: 24),
                activeIcon: Icon(Icons.person_rounded, size: 25),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
