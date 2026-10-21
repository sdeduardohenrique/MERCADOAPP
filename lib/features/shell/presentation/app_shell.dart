import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../community/presentation/community_screen.dart';
import '../../home/presentation/home_dashboard_screen.dart';
import '../../profile/presentation/profile_screen.dart';

/// Casca principal do app com as 3 abas.
///
/// Usa `IndexedStack` para preservar o estado de cada aba (scroll, filtros,
/// formulários) ao alternar entre elas.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = <Widget>[
    HomeDashboardScreen(),
    CommunityScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
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
            currentIndex: _index,
            onTap: (index) => setState(() => _index = index),
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.emeraldDark,
            unselectedItemColor: AppTheme.muted,
            selectedFontSize: 11.5,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, size: 25),
                activeIcon: Icon(Icons.home_rounded, size: 26),
                label: 'Início',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.radar_outlined, size: 25),
                activeIcon: Icon(Icons.radar_rounded, size: 26),
                label: 'Comunidade',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded, size: 25),
                activeIcon: Icon(Icons.person_rounded, size: 26),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
