import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../shell/presentation/app_shell.dart';
import '../domain/auth_service.dart';

/// Tela de verificação de OTP por SMS
///
/// Exibe 6 campos para digitar o código recebido por SMS,
/// com timer de reenvio e validação automática.
class OTPVerificationScreen extends ConsumerStatefulWidget {
  final String phone;
  final bool isRegistration;

  const OTPVerificationScreen({
    super.key,
    required this.phone,
    this.isRegistration = false,
  });

  @override
  ConsumerState<OTPVerificationScreen> createState() =>
      _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  Timer? _countdownTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOTP() async {
    final code = _pinController.text.trim();
    if (code.length != 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.verifyPhoneOTP(
        phone: widget.phone,
        token: code,
      );

      if (!mounted) return;

      result.when(
        success: (user) {
          // Sucesso: navega para AppShell
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AppShell()),
            (route) => false,
          );
        },
        failure: (message, code) {
          setState(() {
            _isLoading = false;
            _errorMessage = message;
          });
        },
        pending: (phone) {
          // Não deve acontecer aqui
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao verificar código. Tente novamente.';
      });
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.resendPhoneOTP(phone: widget.phone);

      if (!mounted) return;

      result.when(
        success: (_) {
          _startCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Novo código enviado!'),
              backgroundColor: AppTheme.emeraldDark,
            ),
          );
        },
        failure: (message, code) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: const Color(0xFFF04438)),
          );
        },
        pending: (phone) {
          _startCountdown();
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro ao reenviar código.'),
            backgroundColor: Color(0xFFF04438)),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _formatPhone(String phone) {
    // Formata para exibição: +55 11 99999-9999
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 13) {
      // +55 11 999999999
      return '+${digits.substring(0, 2)} ${digits.substring(2, 4)} ${digits.substring(4, 9)}-${digits.substring(9)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF1DB954);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 140,
                    height: 140,
                  ),
                  const SizedBox(height: 16),
                  // Título
                  Text(
                    widget.isRegistration
                        ? 'Verifique seu número'
                        : 'Verificação por SMS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enviamos um código de 6 dígitos para',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPhone(widget.phone),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Card com campos PIN
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Digite o código',
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'O código expira em 10 minutos',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // PIN Code Fields
                        Form(
                          key: _formKey,
                          child: PinCodeTextField(
                            appContext: context,
                            length: 6,
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onCompleted: (value) => _verifyOTP(),
                            onChanged: (value) {
                              if (_errorMessage != null) {
                                setState(() => _errorMessage = null);
                              }
                            },
                            pinTheme: PinTheme(
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(14),
                              fieldHeight: 56,
                              fieldWidth: 48,
                              activeFillColor: AppTheme.background,
                              inactiveFillColor: AppTheme.background,
                              selectedFillColor: AppTheme.emeraldTint,
                              activeColor: AppTheme.emeraldDark,
                              inactiveColor: AppTheme.line,
                              selectedColor: AppTheme.emeraldDark,
                              borderWidth: 1.5,
                              errorBorderColor: const Color(0xFFF04438),
                            ),
                            enableActiveFill: true,
                            cursorColor: AppTheme.emeraldDark,
                            animationType: AnimationType.fade,
                            animationDuration:
                                const Duration(milliseconds: 200),
                          ),
                        ),
                        // Mensagem de erro
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDECEC),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFF04438)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Color(0xFFB42318), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: Color(0xFFB42318),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Botão Verificar
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emeraldDark,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              disabledBackgroundColor:
                                  AppTheme.emeraldDark.withValues(alpha: 0.5),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white)),
                                  )
                                : const Text(
                                    'Verificar e continuar',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Reenviar código
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Não recebeu? ',
                              style: TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500),
                            ),
                            TextButton(
                              onPressed: (_resendCountdown > 0 || _isResending)
                                  ? null
                                  : _resendOTP,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.emeraldDark,
                                disabledForegroundColor: AppTheme.muted,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: _isResending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : Text(
                                      _resendCountdown > 0
                                          ? 'Reenviar em ${_resendCountdown}s'
                                          : 'Reenviar código',
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Voltar
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Alterar número',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension para pattern matching no AuthResult
extension AuthResultX<AuthResult> on AuthResult {
  void when({
    required void Function(User? user) success,
    required void Function(String message, String? code) failure,
    required void Function(String phone) pending,
  }) {
    if (this is AuthSuccess) {
      success((this as AuthSuccess).user);
    } else if (this is AuthFailure) {
      final f = this as AuthFailure;
      failure(f.message, f.code);
    } else if (this is AuthPending) {
      pending((this as AuthPending).phone);
    }
  }
}
