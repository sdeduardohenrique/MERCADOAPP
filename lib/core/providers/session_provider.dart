import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sessão de visitante (modo offline).
///
/// O visitante não tem conta no Supabase: nome, compras e carrinho ficam
/// apenas no dispositivo. Nenhuma leitura/escrita é feita no banco enquanto
/// este estado estiver ativo — isso evita erros de RLS e vazamento de dados.
class GuestSession {
  final String name;

  const GuestSession({required this.name});
}

class GuestSessionNotifier extends StateNotifier<GuestSession?> {
  GuestSessionNotifier() : super(null);

  static const storageKey = 'somaai.guest.name.v1';

  bool _restored = false;
  bool get isRestored => _restored;

  /// Lê o apelido salvo. Chamado no boot pelo AuthGate.
  Future<void> restore() async {
    if (_restored) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(storageKey)?.trim();
      if (name != null && name.isNotEmpty) {
        state = GuestSession(name: name);
      }
    } catch (error) {
      debugPrint('[GuestSession] não foi possível restaurar: $error');
    } finally {
      _restored = true;
    }
  }

  Future<void> start(String name) async {
    final apelido = name.trim();
    if (apelido.isEmpty) return;

    state = GuestSession(name: apelido);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, apelido);
    } catch (error) {
      debugPrint('[GuestSession] não foi possível salvar o apelido: $error');
    }
  }

  Future<void> clear() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (error) {
      debugPrint('[GuestSession] não foi possível limpar o apelido: $error');
    }
  }
}

final guestSessionProvider =
    StateNotifierProvider<GuestSessionNotifier, GuestSession?>((ref) {
  return GuestSessionNotifier();
});

/// Atalho booleano usado pelas camadas que precisam bloquear a rede.
final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(guestSessionProvider) != null;
});
