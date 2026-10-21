import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../shell/presentation/app_shell.dart';
import '../domain/auth_service.dart';
import 'otp_verification_screen.dart';

/// BottomSheet para entrada de número de telefone com máscara e validação
class PhoneLoginSheet extends ConsumerStatefulWidget {
  final bool isRegistration;

  const PhoneLoginSheet({super.key, this.isRegistration = false});

  @override
  ConsumerState<PhoneLoginSheet> createState() => _PhoneLoginSheetState();
}

class _PhoneLoginSheetState extends ConsumerState<PhoneLoginSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneInput(String value) {
    // Remove tudo que não é dígito
    final digits = value.replaceAll(RegExp(r'\D'), '');

    // Limita a 11 dígitos (DDD + número)
    if (digits.length > 11)
      return _formatPhoneInput(value.substring(0, value.length - 1));

    // Formata: (11) 99999-9999 ou (11) 9999-9999
    String formatted = '';
    if (digits.length >= 1) formatted = '($digits';
    if (digits.length >= 2) formatted = '(${digits.substring(0, 2)})';
    if (digits.length >= 3)
      formatted = '(${digits.substring(0, 2)}) ${digits.substring(2)}';
    if (digits.length >= 7) {
      if (digits.length == 11) {
        // Celular com 9 dígitos
        formatted =
            '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
      } else {
        // Fixo com 8 dígitos
        formatted =
            '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
      }
    }
    return formatted;
  }

  String _normalizePhoneForAPI(String formatted) {
    // Converte para formato E.164 (+5511999999999)
    final digits = formatted.replaceAll(RegExp(r'\D'), '');
    if (!digits.startsWith('55')) {
      return '+55$digits';
    }
    return '+$digits';
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final normalizedPhone = _normalizePhoneForAPI(_phoneController.text);
      final result = await authService.sendPhoneOTP(phone: normalizedPhone);

      if (!mounted) return;

      result.when(
        success: (user) {
          // Login direto (raro, mas possível se já autenticado)
          Navigator.of(context).pop();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const _AppShellEntry()),
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
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OTPVerificationScreen(
                  phone: phone, isRegistration: widget.isRegistration),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao enviar SMS. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Título
          Text(
            widget.isRegistration
                ? 'Cadastro por Celular'
                : 'Entrar com Celular',
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Envie um código SMS para o número abaixo',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Formulário
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendOTP(),
                  onChanged: (value) {
                    _phoneController.value = _phoneController.value.copyWith(
                      text: _formatPhoneInput(value),
                      selection: TextSelection.collapsed(
                          offset: _formatPhoneInput(value).length),
                    );
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Celular',
                    hintText: '(11) 99999-9999',
                    prefixIcon:
                        const Icon(Icons.phone_outlined, color: AppTheme.muted),
                    prefixText: '+55 ',
                    prefixStyle: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppTheme.emeraldDark, width: 2),
                    ),
                    filled: true,
                    fillColor: AppTheme.background,
                    errorText: _errorMessage,
                    errorStyle: const TextStyle(
                        color: Color(0xFFB42318), fontWeight: FontWeight.w600),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFFF04438), width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Color(0xFFF04438), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe seu número de celular';
                    }
                    final digits = value.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 10 || digits.length > 11) {
                      return 'Número inválido. Use (DDD) 99999-9999';
                    }
                    // Valida DDD (11 a 99)
                    final ddd = int.tryParse(digits.substring(0, 2));
                    if (ddd == null || ddd < 11 || ddd > 99) {
                      return 'DDD inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOTP,
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
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white)),
                          )
                        : const Text(
                            'Enviar código SMS',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Link para voltar
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(
              'Voltar',
              style: TextStyle(
                color: AppTheme.emeraldDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper para abrir o bottom sheet
Future<void> showPhoneLoginSheet(BuildContext context,
    {bool isRegistration = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PhoneLoginSheet(isRegistration: isRegistration),
  );
}

/// Entry point para o AppShell (import lazy para evitar ciclos)
class _AppShellEntry extends ConsumerWidget {
  const _AppShellEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _RealAppShell();
  }
}

typedef _RealAppShell = AppShell;
