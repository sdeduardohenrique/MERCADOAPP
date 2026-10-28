import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Tela de bloqueio da Comunidade para o modo visitante.
///
/// A inteligência colaborativa exige identidade: o visitante usa o app apenas
/// como calculadora local. O CTA encerra a sessão de visitante e leva ao
/// cadastro.
class GuestCommunityLock extends StatelessWidget {
  final VoidCallback onCreateAccount;

  const GuestCommunityLock({super.key, required this.onCreateAccount});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.amberTint,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.amber.withValues(alpha: 0.28),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 42,
                    color: Color(0xFFB26B00),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Comunidade para quem tem conta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Para ter acesso à comunidade com ofertas da sua região, '
                  'você precisa criar uma conta gratuita.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCreateAccount,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text(
                      'Criar minha conta',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ao criar a conta, sua sessão de visitante e as compras '
                  'salvas neste aparelho serão apagadas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: AppTheme.muted,
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
