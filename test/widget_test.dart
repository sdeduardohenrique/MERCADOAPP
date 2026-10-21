import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soma_ai/features/home/presentation/home_dashboard_screen.dart';
import 'package:soma_ai/features/shell/presentation/app_shell.dart';
import 'package:soma_ai/features/splash/presentation/splash_screen.dart';
import 'package:soma_ai/main.dart';

Future<void> _noopBootstrap() async {}

void main() {
  group('SplashScreen', () {
    testWidgets('exibe a marca SomaAí e o indicador de carregamento',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      expect(find.text('SomaAí'), findsOneWidget);
      expect(find.text('Sem sustos no caixa.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ocupa a tela inteira com um Scaffold',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);
    });
  });

  group('BootstrapGate', () {
    testWidgets('troca a splash pelo Dashboard mesmo sem Supabase/rede',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BootstrapGate(initialize: _noopBootstrap),
          ),
        ),
      );

      // Primeiro frame: splash visível (nunca tela preta).
      expect(find.byType(SplashScreen), findsOneWidget);

      // Mesmo com a inicialização "vazia" (equivalente a falha), o gate
      // deve liberar a tela principal.
      await tester.pump();
      await tester.pump();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(HomeDashboardScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
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
