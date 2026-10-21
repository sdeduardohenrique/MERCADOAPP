import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_theme.dart';
import '../../shell/presentation/app_shell.dart';
import '../domain/auth_service.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';
import 'phone_login_sheet.dart';
import 'register_screen.dart';

/// Tela de login/entrada do app com suporte a múltiplos provedores.
///
/// Permite entrar com:
/// - Email e senha
/// - Google OAuth
/// - Apple OAuth
/// - Número de celular (OTP SMS)
/// - Continuar como visitante (modo offline)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isPhoneMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneInput(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) return _formatPhoneInput(value.substring(0, value.length - 1));

    String formatted = '';
    if (digits.length >= 1) formatted = '($digits';
    if (digits.length >= 2) formatted = '(${digits.substring(0, 2)})';
    if (digits.length >= 3) formatted = '(${digits.substring(0, 2)}) ${digits.substring(2)}';
    if (digits.length >= 7) {
      if (digits.length == 11) {
        formatted = '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
      } else {
        formatted = '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
      }
    }
    return formatted;
  }

  String _normalizePhoneForAPI(String formatted) {
    final digits = formatted.replaceAll(RegExp(r'\D'), '');
    if (!digits.startsWith('55')) {
      return '+55$digits';
    }
    return '+$digits';
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      result.when(
        success: (user) {
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
        pending: (phone) {},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro inesperado. Tente novamente.';
      });
    }
  }

  Future<void> _signInWithPhone() async {
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OTPVerificationScreen(phone: phone),
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

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signInWithGoogle();

      if (!mounted) return;

      result.when(
        success: (user) {
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
        pending: (phone) {},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro no login com Google.';
      });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signInWithApple();

      if (!mounted) return;

      result.when(
        success: (user) {
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
        pending: (phone) {},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro no login com Apple.';
      });
    }
  }

  void _openPhoneLogin() {
    showPhoneLoginSheet(context);
  }

  void _continueAsGuest() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
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
                  const Text(
                    'Bem-vindo ao SomaAí',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sem sustos no caixa.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Formulário de login
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Toggle Email / Telefone
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ModeToggleButton(
                                    label: 'Email',
                                    icon: Icons.email_outlined,
                                    isSelected: !_isPhoneMode,
                                    onTap: () => setState(() => _isPhoneMode = false),
                                  ),
                                ),
                                Expanded(
                                  child: _ModeToggleButton(
                                    label: 'Telefone',
                                    icon: Icons.phone_outlined,
                                    isSelected: _isPhoneMode,
                                    onTap: () => setState(() => _isPhoneMode = true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Campo Email ou Telefone
                          if (!_isPhoneMode) ...[
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'voce@exemplo.com',
                                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.muted),
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
                                  borderSide: const BorderSide(color: AppTheme.emeraldDark, width: 2),
                                ),
                                filled: true,
                                fillColor: AppTheme.background,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Informe seu email';
                                }
                                final emailRegex = RegExp(
                                  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+"
                                  r"@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
                                  r"(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
                                );
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Email inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Senha
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _signInWithEmail(),
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.muted),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: AppTheme.muted,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
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
                                  borderSide: const BorderSide(color: AppTheme.emeraldDark, width: 2),
                                ),
                                filled: true,
                                fillColor: AppTheme.background,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Informe sua senha';
                                }
                                if (value.length < 6) {
                                  return 'A senha deve ter pelo menos 6 caracteres';
                                }
                                return null;
                              },
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _signInWithPhone(),
                              onChanged: (value) {
                                _phoneController.value = _phoneController.value.copyWith(
                                  text: _formatPhoneInput(value),
                                  selection: TextSelection.collapsed(offset: _formatPhoneInput(value).length),
                                );
                                if (_errorMessage != null) {
                                  setState(() => _errorMessage = null);
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Celular',
                                hintText: '(11) 99999-9999',
                                prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.muted),
                                prefixText: '+55 ',
                                prefixStyle: const TextStyle(color: AppTheme.ink, fontSize: 16, fontWeight: FontWeight.w600),
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
                                  borderSide: const BorderSide(color: AppTheme.emeraldDark, width: 2),
                                ),
                                filled: true,
                                fillColor: AppTheme.background,
                                errorText: _errorMessage,
                                errorStyle: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w600),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFF04438), width: 1.5),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFF04438), width: 2),
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
                                final ddd = int.tryParse(digits.substring(0, 2));
                                if (ddd == null || ddd < 11 || ddd > 99) {
                                  return 'DDD inválido';
                                }
                                return null;
                              },
                            ),
                          ],
                          // Mensagem de erro
                          if (_errorMessage != null && !_isPhoneMode) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDECEC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF04438)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFB42318), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Color(0xFFB42318), fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          // Botão Entrar
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : (_isPhoneMode ? _signInWithPhone : _signInWithEmail),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.emeraldDark,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                disabledBackgroundColor: AppTheme.emeraldDark.withValues(alpha: 0.5),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                    )
                                  : Text(_isPhoneMode ? 'Enviar código SMS' : 'Entrar com email',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Divisor "OU ENTRE COM"
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.white38, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OU ENTRE COM',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Expanded(child: Divider(color: Colors.white38, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Botões sociais apenas ícones
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google
                      _SocialIconButton(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: _GoogleLogo(size: 24),
                        tooltip: 'Continuar com Google',
                      ),
                      const SizedBox(width: 16),
                      // Apple
                      _SocialIconButton(
                        onPressed: _isLoading ? null : _signInWithApple,
                        icon: const Icon(Icons.apple, size: 24, color: Colors.white),
                        tooltip: 'Continuar com Apple',
                      ),
                      const SizedBox(width: 16),
                      // Telefone
                      _SocialIconButton(
                        onPressed: _isLoading ? null : _openPhoneLogin,
                        icon: Icon(Icons.phone_outlined, size: 24, color: Colors.white.withValues(alpha: 0.9)),
                        tooltip: 'Entrar com Celular',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Link "Esqueci a senha"
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    child: Text(
                      'Esqueci a senha',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Botão "Continuar como visitante"
                  TextButton.icon(
                    onPressed: _continueAsGuest,
                    icon: Icon(Icons.person_outline_rounded, color: Colors.white.withValues(alpha: 0.85), size: 20),
                    label: Text(
                      'Continuar como visitante (modo offline)',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Link "Criar conta"
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: Text(
                      'Criar conta',
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

/// Botão de toggle para alternar entre Email e Telefone
class _ModeToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppTheme.emeraldDark : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.white : AppTheme.muted),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.muted, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão social apenas com ícone
class _SocialIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String tooltip;

  const _SocialIconButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

/// Logo do Google em SVG inline
class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(
        '''
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
          <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
          <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
          <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
        </svg>
        ''',
        width: size,
        height: size,
      ),
    );
  }
}