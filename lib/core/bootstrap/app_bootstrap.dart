import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';

/// Inicialização "à prova de falhas" dos serviços externos.
///
/// Regra de ouro: a UI **nunca** pode depender do sucesso da rede/Supabase para
/// aparecer. Se a inicialização falhar ou demorar, o app segue em modo offline.
class AppBootstrap {
  AppBootstrap._();

  static const Duration timeout = Duration(seconds: 8);

  /// Último erro de inicialização, se houver (exibido apenas em log).
  static Object? error;

  static bool _started = false;

  /// `true` quando o cliente Supabase terminou de inicializar.
  static bool get supabaseReady {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  /// Inicializa o Supabase. Nunca lança exceção.
  static Future<void> initialize() async {
    if (_started) return;
    _started = true;

    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        publishableKey: AppConstants.supabaseAnonKey,
      ).timeout(timeout);

      debugPrint('[SomaAí] Supabase inicializado com sucesso.');
    } on TimeoutException {
      error = 'Tempo esgotado ao inicializar o Supabase.';
      debugPrint('[SomaAí] Supabase: timeout — seguindo em modo offline.');
    } catch (e, stack) {
      error = e;
      debugPrint(
          '[SomaAí] Supabase indisponível — seguindo em modo offline: $e');
      debugPrintStack(stackTrace: stack);
    }
  }
}
