import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

// Simple debug print wrapper that works in all environments
void _log(String message) {
  // Using print instead of debugPrint for compatibility with test environment
  // In production, debugPrint would be preferred for performance
  print(message);
}

/// Resultado de operações de autenticação
sealed class AuthResult {
  const AuthResult();

  T when<T>({
    required T Function(User? user) success,
    required T Function(String message, String? code) failure,
  }) {
    switch (this) {
      case AuthSuccess(user: final u):
        return success(u);
      case AuthFailure(message: final m, code: final c):
        return failure(m, c);
    }
  }
}

class AuthSuccess extends AuthResult {
  final User? user;
  const AuthSuccess(this.user);
}

class AuthFailure extends AuthResult {
  final String message;
  final String? code;
  const AuthFailure(this.message, {this.code});
}

/// Tipos de provedor de autenticação suportados
enum AuthProvider {
  email,
  google,
}

/// Serviço centralizado de autenticação
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // Configuração do Google Sign-In com serverClientId do ambiente
  // IMPORTANTE: serverClientId deve ser o Web Client ID do Google Cloud Console
  // (OAuth 2.0 Client ID tipo "Web application", NÃO Android)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    serverClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    // Força a exibição da tela de seleção de conta
    forceCodeForRefreshToken: true,
  );

  /// Verifica se há uma sessão ativa
  User? get currentUser => SupabaseService.currentUser;

  /// Stream de mudanças de estado de autenticação
  Stream<AuthState> get authStateChanges {
    if (!SupabaseService.isReady) {
      return const Stream.empty();
    }
    return SupabaseService.client.auth.onAuthStateChange;
  }

  /// Login com email e senha
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (!SupabaseService.isReady) {
        return const AuthFailure(
            'Modo offline. Conecte-se à internet para autenticar.');
      }

      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        return AuthSuccess(response.user!);
      }
      return const AuthFailure('Não foi possível autenticar. Tente novamente.');
    } on AuthException catch (e) {
      return AuthFailure(_translateAuthError(e.message), code: e.code);
    } catch (e) {
      _log('[AuthService] signInWithEmail unexpected error: $e');
      return const AuthFailure('Erro inesperado. Tente novamente.');
    }
  }

  /// Cadastro com email e senha
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (!SupabaseService.isReady) {
        return const AuthFailure(
            'Modo offline. Conecte-se à internet para cadastrar.');
      }

      final response = await SupabaseService.client.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        // Se não há sessão, email confirmation é necessária
        if (response.session == null) {
          return const AuthFailure(
            'Conta criada! Verifique seu email para confirmar o cadastro.',
          );
        }
        return AuthSuccess(response.user!);
      }
      return const AuthFailure(
          'Não foi possível criar a conta. Tente novamente.');
    } on AuthException catch (e) {
      return AuthFailure(_translateAuthError(e.message), code: e.code);
    } catch (e) {
      _log('[AuthService] signUpWithEmail unexpected error: $e');
      return const AuthFailure('Erro inesperado. Tente novamente.');
    }
  }

  /// Login com Google (OAuth) - Seguindo documentação Supabase
  /// https://supabase.com/docs/guides/auth/social-sign-in/auth-google
  Future<AuthResult> signInWithGoogle() async {
    try {
      if (!SupabaseService.isReady) {
        return const AuthFailure(
            'Modo offline. Conecte-se à internet para autenticar.');
      }

      _log('[AuthService] Starting Google Sign-In flow...');

      // 1. Verifica se serverClientId está configurado
      final serverClientId = const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
      if (serverClientId.isEmpty) {
        _log('[AuthService] ERROR: GOOGLE_WEB_CLIENT_ID não configurado (--dart-define)');
        return const AuthFailure(
            'Configuração do Google incompleta. Contate o suporte.');
      }
      _log('[AuthService] Using serverClientId: $serverClientId');

      // 2. Inicia o fluxo do Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _log('[AuthService] Google Sign-In canceled by user');
        return const AuthFailure('Login com Google cancelado.');
      }

      _log('[AuthService] Google user: ${googleUser.email}');

      // 2. Obtém o ID Token (necessário para Supabase)
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        _log('[AuthService] ERROR: idToken is null');
        return const AuthFailure('Não foi possível obter o token do Google. Tente novamente.');
      }

      _log('[AuthService] Got ID Token (length: ${idToken.length})');

      // 3. Autentica no Supabase com o ID Token
      _log('[AuthService] Calling Supabase signInWithIdToken (Google)...');
      final response = await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      _log('[AuthService] Supabase response:');
      _log('[AuthService]   user: ${response.user?.id ?? 'NULL'}');
      _log('[AuthService]   session: ${response.session != null ? 'PRESENT' : 'NULL'}');

      if (response.user != null) {
        _log('[AuthService] Google login successful for user: ${response.user!.id}');
        return AuthSuccess(response.user!);
      }
      _log('[AuthService] ERROR: Supabase returned null user');
      return const AuthFailure('Falha ao autenticar com Google no Supabase. Tente novamente.');
    } on AuthException catch (e, stackTrace) {
      _log('[AuthService] signInWithGoogle AuthException:');
      _log('  message: ${e.message}');
      _log('  code: ${e.code}');
      _log('  stackTrace: $stackTrace');
      return AuthFailure(_translateAuthError(e.message), code: e.code);
    } catch (e, stackTrace) {
      _log('[AuthService] signInWithGoogle unexpected error:');
      _log('  error: $e');
      _log('  type: ${e.runtimeType}');
      _log('  stackTrace: $stackTrace');
      return AuthFailure('Erro inesperado no login com Google: $e');
    }
  }

  /// Recuperação de senha
  Future<AuthResult> resetPassword({required String email}) async {
    try {
      if (!SupabaseService.isReady) {
        return const AuthFailure('Modo offline. Conecte-se à internet.');
      }

      await SupabaseService.client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'somaai://reset-password',
      );

      return const AuthSuccess(null); // Success sem user (apenas email enviado)
    } on AuthException catch (e) {
      return AuthFailure(_translateAuthError(e.message), code: e.code);
    } catch (e) {
      _log('[AuthService] resetPassword unexpected error: $e');
      return const AuthFailure('Erro ao enviar email de recuperação.');
    }
  }

  /// Atualiza senha (após redirect do reset)
  Future<AuthResult> updatePassword({required String newPassword}) async {
    try {
      if (!SupabaseService.isReady) {
        return const AuthFailure('Modo offline.');
      }

      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      return const AuthSuccess(null);
    } on AuthException catch (e) {
      return AuthFailure(_translateAuthError(e.message), code: e.code);
    } catch (e) {
      _log('[AuthService] updatePassword unexpected error: $e');
      return const AuthFailure('Erro ao atualizar senha.');
    }
  }

  /// Logout
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    if (SupabaseService.isReady) {
      await SupabaseService.signOut();
    }
  }

  /// Exclui conta
  Future<AuthResult> deleteAccount() async {
    try {
      if (!SupabaseService.isReady) {
        return const AuthFailure('Modo offline.');
      }

      // Nota: deleteUser requer política RLS ou service role
      // Em produção, use uma Edge Function com service_role
      await SupabaseService.client.auth.admin.deleteUser(
        SupabaseService.currentUser!.id,
      );
      return const AuthSuccess(null);
    } on AuthException catch (e) {
      return AuthFailure(_translateAuthError(e.message), code: e.code);
    } catch (e) {
      _log('[AuthService] deleteAccount unexpected error: $e');
      return const AuthFailure('Erro ao excluir conta.');
    }
  }

  // ==================== Helpers Privados ====================

  String _translateAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('wrong password') ||
        lower.contains('invalid email')) {
      return 'Email ou senha incorretos.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Confirme seu email antes de entrar.';
    }
    if (lower.contains('user not found')) {
      return 'Conta não encontrada. Verifique o email.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already registered') ||
        lower.contains('email already exists')) {
      return 'Este email já está cadastrado. Tente fazer login.';
    }
    if (lower.contains('weak password') ||
        lower.contains('password should be at least')) {
      return 'Senha muito fraca. Use pelo menos 6 caracteres.';
    }
    if (lower.contains('invalid email')) {
      return 'Email inválido.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Sem conexão. Verifique sua internet.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Muitas tentativas. Aguarde alguns minutos.';
    }
    if (lower.contains('signup disabled') || lower.contains('not allowed')) {
      return 'Cadastro não permitido no momento.';
    }
    if (lower.contains('provider') && lower.contains('disabled')) {
      return 'Este método de login não está habilitado. Configure no Supabase.';
    }
    if (lower.contains('invalid_grant') || lower.contains('invalid_token')) {
      return 'Sessão inválida ou expirada. Faça login novamente.';
    }
    return 'Não foi possível completar a operação. Tente novamente.';
  }
}

/// Provider do AuthService para Riverpod
final authServiceProvider =
    Provider<AuthService>((ref) => AuthService.instance);