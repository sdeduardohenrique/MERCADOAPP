import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soma_ai/features/auth/presentation/login_screen.dart';
import 'package:soma_ai/features/shell/presentation/app_shell.dart';
import 'package:soma_ai/features/splash/presentation/splash_screen.dart';
import 'package:soma_ai/main.dart';

Future<void> _noopBootstrap() async {}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
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
    testWidgets('mostra o CTA de nova compra e as 4 abas', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: AppShell()),
        ),
      );
      await tester.pump();

      expect(find.text('Iniciar nova compra'), findsOneWidget);
      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Minhas Listas'), findsOneWidget);
      expect(find.text('Comunidade'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Últimas compras'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Últimas compras'), findsOneWidget);
    });

    testWidgets('troca de aba ao tocar em Minhas Listas', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: AppShell()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Minhas Listas'));
      await tester.pumpAndSettle();

      expect(find.text('PLANEJAMENTO E ECONOMIA'), findsOneWidget);
      expect(find.text('Sua primeira lista começa aqui'), findsOneWidget);
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
