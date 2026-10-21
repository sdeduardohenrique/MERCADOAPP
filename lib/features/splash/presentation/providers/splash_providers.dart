import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';

/// Provider que expõe o estado de autenticação atual (sessão Supabase).
///
/// Retorna o [User] se houver sessão válida, ou `null` se não autenticado
/// ou em modo offline.
final authStateProvider = StreamProvider<User?>((ref) {
  if (!SupabaseService.isReady) {
    return Stream.value(null);
  }
  return SupabaseService.client.auth.onAuthStateChange.map((state) {
    return state.session?.user;
  });
});

/// Provider síncrono para verificação rápida no bootstrap.
final currentUserProvider = Provider<User?>((ref) {
  return SupabaseService.currentUser;
});

/// Estado da tela de splash para coordenação entre timer e auth check.
class SplashState {
  const SplashState({
    this.timerCompleted = false,
    this.authChecked = false,
    this.user,
  });

  final bool timerCompleted;
  final bool authChecked;
  final User? user;

  SplashState copyWith({
    bool? timerCompleted,
    bool? authChecked,
    User? user,
  }) {
    return SplashState(
      timerCompleted: timerCompleted ?? this.timerCompleted,
      authChecked: authChecked ?? this.authChecked,
      user: user ?? this.user,
    );
  }

  bool get canNavigate => timerCompleted && authChecked;

  bool get isAuthenticated => user != null;
}

/// Notifier que gerencia o fluxo da splash screen.
class SplashNotifier extends StateNotifier<SplashState> {
  SplashNotifier() : super(const SplashState());

  void setTimerCompleted() {
    state = state.copyWith(timerCompleted: true);
  }

  void setAuthChecked({required User? user}) {
    state = state.copyWith(authChecked: true, user: user);
  }

  void reset() {
    state = const SplashState();
  }
}

final splashNotifierProvider =
    StateNotifierProvider<SplashNotifier, SplashState>(
  (ref) => SplashNotifier(),
);
