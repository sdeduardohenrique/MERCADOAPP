import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soma_ai/features/auth/presentation/auth_gate.dart';
import 'package:soma_ai/features/auth/presentation/login_screen.dart';
import 'package:soma_ai/features/shell/presentation/app_shell.dart';
import 'package:soma_ai/features/splash/presentation/splash_screen.dart';

Future<void> _noopBootstrap() async {}

void main() {
  group('SplashScreen', () {
    testWidgets('exibe a logo SVG e o indicador de carregamento',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      // A nova splash usa SVG logo, não texto "SomaAí"
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Carregando...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ocupa a tela inteira com um Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      expect(find.byType(Scaffold), findsOneWidget);
      // SafeArea não é mais usado na nova splash (usa Center/Column)
      expect(find.byType(Center), findsOneWidget);
    });
  });

  group('AuthGate', () {
    testWidgets(
        'mostra splash por 2500ms e depois vai para LoginScreen (sem auth)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthGate(initialize: [_noopBootstrap]),
          ),
        ),
      );

      // Primeiro frame: splash visível (nunca tela preta).
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(AppShell), findsNothing);

      // Aguarda o timer de 2500ms + um pouco
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pump();

      // Sem autenticação, deve ir para LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(AppShell), findsNothing);
      expect(find.text('Bem-vindo ao SomaAí'), findsOneWidget);
    });

    testWidgets('mostra splash e vai para LoginScreen quando não autenticado',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthGate(initialize: [_noopBootstrap]),
          ),
        ),
      );

      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pump();

      // Sem Supabase inicializado, currentUser retorna null -> LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    testWidgets('valida email inválido', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      // Tenta submeter sem preencher - usa o botão "Entrar com email"
      final enterButton =
          find.widgetWithText(ElevatedButton, 'Entrar com email');
      await tester.ensureVisible(enterButton);
      await tester.tap(enterButton);
      await tester.pump();

      expect(find.text('Informe seu email'), findsOneWidget);
      expect(find.text('Informe sua senha'), findsOneWidget);
    });

    testWidgets('valida formato de email', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      await tester.enterText(
          find.byType(TextFormField).first, 'email-invalido');
      final enterButton =
          find.widgetWithText(ElevatedButton, 'Entrar com email');
      await tester.ensureVisible(enterButton);
      await tester.tap(enterButton);
      await tester.pump();

      expect(find.text('Email inválido'), findsOneWidget);
    });

    testWidgets('valida senha curta', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
      await tester.enterText(find.byType(TextFormField).last, '123');
      final enterButton =
          find.widgetWithText(ElevatedButton, 'Entrar com email');
      await tester.ensureVisible(enterButton);
      await tester.tap(enterButton);
      await tester.pump();

      expect(find.text('A senha deve ter pelo menos 6 caracteres'),
          findsOneWidget);
    });

    testWidgets('navega para tela de cadastro', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      await tester.ensureVisible(find.text('Criar conta'));
      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();

      // Verifica que navegou para RegisterScreen (tem campo "Confirmar senha")
      expect(find.text('Confirmar senha'), findsOneWidget);
    });

    testWidgets('navega para tela de recuperação de senha',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      await tester.ensureVisible(find.text('Esqueci a senha'));
      await tester.tap(find.text('Esqueci a senha'));
      await tester.pumpAndSettle();

      expect(find.text('Recuperar senha'), findsOneWidget);
    });
  });

  group('Dashboard', () {
    testWidgets('mostra o CTA de nova compra e as 3 abas', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: AppShell()),
        ),
      );
      await tester.pump();

      expect(find.text('Iniciar nova compra'), findsOneWidget);
      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Comunidade'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Últimas compras'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Últimas compras'), findsOneWidget);
    });

    testWidgets('troca de aba ao tocar em Comunidade', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: AppShell()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Comunidade'));
      await tester.pumpAndSettle();

      expect(find.text('Radar de ofertas'), findsOneWidget);
    });
  });
}
