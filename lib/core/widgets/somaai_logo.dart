import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Marca do SomaAí: cesta de compras + selo de "soma".
///
/// O símbolo é construído em código (sem assets) para funcionar offline e
/// escalar em qualquer densidade de ecrã.
class SomaAiLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const SomaAiLogo({super.key, this.size = 88, this.showShadow = true});

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.3;
    final badge = size * 0.36;

    return Semantics(
      label: 'Logotipo SomaAí',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: AppTheme.emerald.withValues(alpha: 0.28),
                    blurRadius: size * 0.32,
                    offset: Offset(0, size * 0.12),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.shopping_basket_rounded,
              color: Colors.white,
              size: size * 0.48,
            ),
            Positioned(
              top: size * 0.12,
              right: size * 0.12,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: AppTheme.lime,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: size * 0.025,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: AppTheme.emeraldDark,
                  size: badge * 0.72,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wordmark "SomaAí" com o "Aí" em verde.
class SomaAiWordmark extends StatelessWidget {
  final double fontSize;
  final Color? color;

  const SomaAiWordmark({
    super.key,
    this.fontSize = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? AppTheme.ink;
    return Semantics(
      label: 'SomaAí',
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: baseColor,
          ),
          children: [
            const TextSpan(text: 'Soma'),
            TextSpan(
              text: 'Aí',
              style: TextStyle(
                color: baseColor == Colors.white
                    ? AppTheme.lime
                    : AppTheme.emerald,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
