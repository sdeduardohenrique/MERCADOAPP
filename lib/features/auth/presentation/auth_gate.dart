import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../shell/presentation/app_shell.dart';
import '../../splash/presentation/splash_screen.dart';
import 'login_screen.dart';

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
    _bootstrap();
    _listenToAuthChanges();
  }

  Future<void> _bootstrap() async {
    // Inicia inicialização do Supabase e timer da splash em paralelo
    final initFutures = widget.initialize.map((f) => f()).toList();
    initFutures.add(Future.delayed(const Duration(milliseconds: 2500)));

    // Aguarda todos
    await Future.wait(initFutures);

    if (!mounted) return;

    // Verifica estado inicial de autenticação de forma segura
    User? user;
    try {
      user = SupabaseService.currentUser;
    } catch (_) {
      // Supabase não inicializado ou erro -> trata como não autenticado
      user = null;
    }

    setState(() {
      _status =
          user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    });
  }

  void _listenToAuthChanges() {
    if (!SupabaseService.isReady) return;

    _authStateSubscription = SupabaseService.authStateChanges.listen((state) {
      if (!mounted) return;

      final user = state.session?.user;

      // Se estava autenticado e agora não está -> logout forçado
      if (_status == AuthStatus.authenticated && user == null) {
        setState(() => _status = AuthStatus.unauthenticated);

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
    switch (_status) {
      case AuthStatus.initializing:
        return const SplashScreen();
      case AuthStatus.authenticated:
        return const AppShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

enum AuthStatus {
  initializing,
  authenticated,
  unauthenticated,
}
