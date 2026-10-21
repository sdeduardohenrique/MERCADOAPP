import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Cor de fundo exata do SVG da logo (retângulo base do ícone)
const Color _kSplashBackground = Color(0xFF1DB954);

/// Tela de abertura (Splash) com animação de entrada.
///
/// Exibe a logo centralizada com animação de fade-in + scale-up e um
/// CircularProgressIndicator branco na base. O controle de tempo mínimo
/// e navegação é feito pelo [BootstrapGate] no main.dart.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.8, curve: Curves.elasticOut),
      ),
    );

    // Inicia a animação imediatamente
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSplashBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            // Logo com animação de fade-in + scale-up
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: child,
                  ),
                );
              },
              child: SvgPicture.asset(
                'assets/images/logo.svg',
                width: 180,
                height: 180,
                // Placeholder enquanto o SVG carrega
                placeholderBuilder: (context) => const SizedBox(
                  width: 180,
                  height: 180,
                ),
              ),
            ),
            const Spacer(flex: 2),
            // Indicador de carregamento branco
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            // Texto opcional de carregamento
            Text(
              'Carregando...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
