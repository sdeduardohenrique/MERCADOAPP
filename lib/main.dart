import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/bootstrap/app_bootstrap.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/session_provider.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/shopping_list/presentation/providers/shopping_lists_provider.dart';
import 'features/splash/presentation/splash_screen.dart';

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

/// Gate de autenticação que reage a mudanças de estado de auth em tempo real.
///
/// - No boot: aguarda inicialização do Supabase + timer mínimo (SplashScreen)
/// - Em runtime: escuta `onAuthStateChange` e redireciona automaticamente
///   para LoginScreen se a sessão expirar ou for revogada.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({
    super.key,
    this.initialize = const [],
  });

  final List<Future<void> Function()> initialize;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  AuthStatus _status = AuthStatus.initializing;
  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    // Restaura o visitante em paralelo com a splash: se houver apelido salvo,
    // o build reage e entra direto no app.
    ref.read(guestSessionProvider.notifier).restore();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Inicia inicialização do Supabase e timer da splash em paralelo
    final initFutures = widget.initialize.map((f) => f()).toList();
    initFutures.add(Future.delayed(const Duration(milliseconds: 2500)));

    // Aguarda todos
    await Future.wait(initFutures);

    if (!mounted) return;

    // Só agora o Supabase pode estar pronto: assina as mudanças de sessão.
    _listenToAuthChanges();

    // Verifica estado inicial de autenticação de forma segura
    User? user;
    try {
      user = SupabaseService.currentUser;
    } catch (_) {
      // Supabase não inicializado ou erro -> trata como não autenticado
      user = null;
    }

    // Conta real sempre vence: descarta qualquer resquício de visitante.
    if (user != null) {
      await ref.read(guestSessionProvider.notifier).clear();
    }

    setState(() {
      _status =
          user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    });
    // As listas são isoladas por conta: garante uma leitura limpa com o
    // `user_id` correto depois que a sessão inicial foi restaurada.
    _resetShoppingLists();
  }

  void _resetShoppingLists() {
    ref.invalidate(shoppingListsProvider);
    ref.read(activeShoppingListIdProvider.notifier).clear();
  }

  void _listenToAuthChanges() {
    if (!SupabaseService.isReady) return;

    _authStateSubscription = SupabaseService.authStateChanges.listen((state) {
      if (!mounted) return;

      final user = state.session?.user;

      // Se estava autenticado e agora não está -> logout forçado
      if (_status == AuthStatus.authenticated && user == null) {
        setState(() => _status = AuthStatus.unauthenticated);
        _resetShoppingLists();

        // Mostra snackbar informando que a sessão expirou
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sua sessão expirou. Faça login novamente.'),
            duration: Duration(seconds: 5),
            backgroundColor: Color(0xFFF04438),
          ),
        );
      }
      // Se não estava autenticado e agora está -> login detectado
      else if (_status == AuthStatus.unauthenticated && user != null) {
        setState(() => _status = AuthStatus.authenticated);
        _resetShoppingLists();
      }
    }, onError: (error) {
      // Em caso de erro no stream, assume não autenticado por segurança
      if (mounted && _status == AuthStatus.authenticated) {
        setState(() => _status = AuthStatus.unauthenticated);
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guest = ref.watch(guestSessionProvider);

    switch (_status) {
      case AuthStatus.initializing:
        return const SplashScreen();
      case AuthStatus.authenticated:
        return const AppShell();
      case AuthStatus.unauthenticated:
        // O visitante entra no app sem conta; ao sair do modo visitante o
        // AuthGate reage e volta para o login automaticamente.
        return guest != null ? const AppShell() : const LoginScreen();
    }
  }
}

enum AuthStatus {
  initializing,
  authenticated,
  unauthenticated,
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
