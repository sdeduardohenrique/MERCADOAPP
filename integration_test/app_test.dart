import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:soma_ai/features/scanner/presentation/widgets/camera_preview_widget.dart';
import 'package:soma_ai/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SomaAí - Integration Tests', () {
    testWidgets('App launches and shows scanner screen', (WidgetTester tester) async {
      app.main();

      // A splash anima indefinidamente (CircularProgressIndicator), então não
      // usamos pumpAndSettle: avançamos o tempo manualmente.
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));

      // Verify scanner screen is shown
      expect(find.byType(CameraPreviewWidget), findsOneWidget);
      expect(find.byType(ScanOverlayWidget), findsOneWidget);
    });

    testWidgets('Cart bottom sheet opens and closes', (WidgetTester tester) async {
      app.main();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));

      // Tap cart handle to open
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pumpAndSettle();

      // Verify cart is visible
      expect(find.text('Carrinho'), findsOneWidget);

      // Tap handle again to close
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
    });
  });
}
