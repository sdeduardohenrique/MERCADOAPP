import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap/app_bootstrap.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  _configureErrorHandlers();

  // A UI sobe imediatamente. A inicialização do Supabase acontece em segundo
  // plano (AuthGate), então uma falha de rede/plugin nunca deixa o app
  // preso na tela preta do launch theme.
  runApp(const ProviderScope(child: SomaAiApp()));
}

void _configureErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[SomaAí] FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[SomaAí] PlatformError: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  // Em release o widget de erro padrão é uma caixa cinza. Trocamos por uma
  // tela legível para nunca confundir o usuário com "tela preta".
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('[SomaAí] ErrorWidget: ${details.exceptionAsString()}');
    return const AppErrorScreen();
  };
}

class SomaAiApp extends StatelessWidget {
  const SomaAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // A identidade é "White Theme" — mantemos o tema claro por padrão para
      // preservar contraste e legibilidade do design system.
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en'),
      ],
      home: const AuthGate(initialize: [AppBootstrap.initialize]),
    );
  }
}

/// Fallback visual para erros de renderização (substitui a caixa cinza/preto).
class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFF121212),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.white70, size: 48),
                SizedBox(height: 12),
                Text(
                  'Algo deu errado ao desenhar esta tela.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
