import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

/// Resultado de operações de autenticação
sealed class AuthResult {
  const AuthResult();

  T when<T>({
    required T Function(User? user) success,
    required T Function(String message, String? code) failure,
    required T Function(String phone) pending,
  }) {
    switch (this) {
      case AuthSuccess(user: final u):
        return success(u);
      case AuthFailure(message: final m, code: final c):
        return failure(m, c);
      case AuthPending(phone: final p):
        return pending(p);
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

class AuthPending extends AuthResult {
  final String phone;
  const AuthPending(this.phone);
}

/// Tipos de provedor de autenticação suportados
enum AuthProvider {
  email,
  google,
  apple,
  phone,
}

/// Serviço centralizado de autenticação
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
    // O serverClientId deve ser configurado para o Android/iOS
    // serverClientId: 'SEU_WEB_CLIENT_ID.apps.googleusercontent.com',
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
      return const AuthFailure('Erro inesperado. Tente novamente.');
    }
  }

  /// Login com Google (OAuth)
  Future<AuthResult> signInWithGoogle() async {
    try {
      if (!SupabaseService.isReady) {
        return const AuthFailure(
            'Modo offline. Conecte-se à internet para autenticar.');
      }

      // 1. Inicia o fluxo do Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthFailure('Login com Google cancelado.');
      }

      // 2. Obtém o ID Token
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return const AuthFailure('Não foi possível obter o token do Google.');
      }

      // 3. Autentica no Supabase com o ID Token
      final response = await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (response.user != null) {
        return AuthSuccess(response.user!);
      }
      return const AuthFailure('Falha ao autenticar com Google no Supabase.');
    } on AuthException catch (e) {
      return AuthFailure(_translateAuthError(e.message), code: e.code);
    } catch (e) {
      return AuthFailure('Erro no login com Google: $e');
    }
  }

  /// Login com Apple (OAuth)
  Future<AuthResult> signInWithApple() async {
    try {
      if (!SupabaseService.isReady) {
        return const AuthFailure(
            'Modo offline. Conecte-se à internet para autenticar.');
      }

      // 1. Gera nonce para segurança
      final rawNonce = _generateNonce();
      final nonce = _sha256(rawNonce);

      // 2. Inicia o fluxo do Apple Sign-In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) {
        return const AuthFailure('Não foi possível obter o token da Apple.');
      }

      // 3. Autentica no Supabase com o Identity Token + nonce
      final response = await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: identityToken,
        nonce: rawNonce,
      );

      if (response.user != null) {
        return AuthSuccess(response.user!);
      }
      return const AuthFailure('Falha ao autenticar com Apple no Supabase.');
    } on AuthException catch (e) {
      return AuthFailure(_translateAuthError(e.message), code: e.code);
    } catch (e) {
      return AuthFailure('Erro no login com Apple: $e');
    }
  }

  /// Envia OTP por SMS
  Future<AuthResult> sendPhoneOTP({required String phone}) async {
    try {
      if (!SupabaseService.isReady) {
        return const AuthFailure(
            'Modo offline. Conecte-se à internet para autenticar.');
      }

      // Normaliza o número para formato E.164
      final normalizedPhone = _normalizePhone(phone);

      await SupabaseService.client.auth.signInWithOtp(
        phone: normalizedPhone,
        // Opcional: channel pode ser 'sms' ou 'whatsapp'
        // channel: OtpChannel.sms,
      );

      return AuthPending(normalizedPhone);
    } on AuthException catch (e) {
      return AuthFailure(_translateAuthError(e.message), code: e.code);
    } catch (e) {
      return AuthFailure('Erro ao enviar SMS: $e');
    }
  }

  /// Verifica OTP recebido por SMS
  Future<AuthResult> verifyPhoneOTP({
    required String phone,
    required String token,
  }) async {
    try {
      if (!SupabaseService.isReady) {
        return const AuthFailure(
            'Modo offline. Conecte-se à internet para autenticar.');
      }

      final response = await SupabaseService.client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );

      if (response.user != null) {
        return AuthSuccess(response.user!);
      }
      return const AuthFailure('Código inválido ou expirado.');
    } on AuthException catch (e) {
      return AuthFailure(_translateAuthError(e.message), code: e.code);
    } catch (e) {
      return AuthFailure('Erro ao verificar código: $e');
    }
  }

  /// Reenvia OTP (com rate limiting interno do Supabase)
  Future<AuthResult> resendPhoneOTP({required String phone}) async {
    return sendPhoneOTP(phone: phone);
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
    if (lower.contains('phone') && lower.contains('invalid')) {
      return 'Número de telefone inválido.';
    }
    if (lower.contains('otp') &&
        (lower.contains('expired') || lower.contains('invalid'))) {
      return 'Código inválido ou expirado.';
    }
    if (lower.contains('provider') && lower.contains('disabled')) {
      return 'Este método de login não está habilitado. Configure no Supabase.';
    }
    return 'Não foi possível completar a operação. Tente novamente.';
  }

  String _normalizePhone(String phone) {
    // Remove tudo que não é dígito
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    // Se não começa com código do país, assume Brasil (+55)
    if (!digits.startsWith('55')) {
      digits = '55$digits';
    }

    // Garante formato E.164
    return '+$digits';
  }

  String _generateNonce() {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return random + (chars * 2).substring(0, 32 - random.length);
  }

  String _sha256(String input) {
    // Implementação simples usando crypto
    // Para produção, use package:crypto
    var bytes = input.codeUnits;
    var hash = 0;
    for (var byte in bytes) {
      hash = ((hash << 5) - hash) + byte;
      hash = hash & hash;
    }
    return hash.abs().toRadixString(16).padLeft(32, '0');
  }
}

/// Provider do AuthService para Riverpod
final authServiceProvider =
    Provider<AuthService>((ref) => AuthService.instance);
