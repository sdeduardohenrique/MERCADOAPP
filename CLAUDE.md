# CLAUDE.md - Flutter Project Instructions

## Project Overview

**Mercado App** - Smart grocery shopping assistant with:
- Camera-based price label scanning (OCR + Barcode)
- Real-time cart calculator
- Community price comparison network
- Supabase backend

## Tech Stack

- **Frontend**: Flutter 3.22+ (Dart 3.4+)
- **State Management**: Riverpod
- **Backend**: Supabase (PostgreSQL + Realtime + Edge Functions + Storage)
- **ML/Vision**: google_ml_kit (Text Recognition v2, Barcode Scanning) + mobile_scanner
- **Camera**: camera plugin
- **Location**: geolocator
- **Architecture**: Clean Architecture (Domain/Data/Presentation)

## Key Commands

```bash
# Development
flutter run --flavor dev
flutter run --flavor prod

# Analysis & Format
dart analyze
dart format .
flutter analyze

# Testing
flutter test
flutter test integration_test/
flutter test --coverage

# Build
flutter build apk --flavor prod --release
flutter build ios --flavor prod --release
flutter build appbundle --flavor prod --release

# Dependencies
flutter pub get
flutter pub upgrade
dart pub outdated

# Code Generation (if using)
dart run build_runner build --delete-conflicting-outputs
```

## Project Structure

```
lib/
├── core/
│   ├── constants/
│   ├── services/       # Camera, ML Kit, Supabase, Location, Price Validation
│   ├── models/         # CartItem, CommunityPrice, Store, Product
│   ├── utils/          # PriceParser, EanValidator, TextNormalizer
│   └── theme/
├── features/
│   ├── scanner/
│   │   ├── domain/     # Use cases, repositories
│   │   ├── presentation/
│   │   │   ├── widgets/
│   │   │   └── providers/
│   │   └── data/       # Repository implementations
│   ├── cart/
│   └── community_alerts/
└── main.dart
```

## Critical Implementation Details

### Camera + ML Kit Processing
- Use `camera` plugin with `ImageFormatGroup.yuv420` for ML Kit compatibility
- Process frames at ~2fps (500ms interval) to preserve battery
- Run OCR (Text Recognition v2) and Barcode scanning in parallel
- Use `InputImage.fromCameraImage()` for zero-copy frame processing

### OCR Parser for Brazilian Labels
- Handle formats: "R$ 8,90", "8,90", "2x 4,45", "3 por 10,00"
- Extract: product name, brand, unit price, quantity, unit (kg, g, L, un)
- Normalize text: remove accents, lowercase for fuzzy matching

### Supabase Integration
- Use RPC functions for geo-temporal queries
- Enable RLS on all tables
- Use Realtime subscriptions for live price updates
- Store receipt photos in Supabase Storage

### Price Validation Logic
- TTL: 72 hours (expires_at = captured_at + 72h)
- Only alert if savings > R$ 0.50 AND > 5%
- Cache results for 5 minutes per EAN+price combination
- User toggle to disable alerts entirely

## Coding Standards

### Dart/Flutter
- Always use null safety
- Prefer `const` constructors
- Use `late` only when necessary
- Dispose controllers/streams in `dispose()`
- Use `equatable` for value objects

### Riverpod
- Use `@riverpod` syntax (code generation)
- Separate providers by feature
- Use `ref.watch` for dependencies, `ref.read` for one-time reads
- Keep providers pure (no side effects in build)

### Error Handling
- Use `Result<T, E>` pattern or `Either` for fallible operations
- Log errors with context (use `logger` package)
- Show user-friendly messages, not stack traces

### Testing
- Unit test: services, parsers, validators, use cases
- Widget test: scanner overlay, cart bottom sheet, alert banner
- Integration test: full scan → cart → checkout flow
- Mock: Supabase client, Camera, ML Kit, Location

## AI Assistant Workflow

1. **Before editing**: Run `dart analyze` to see current diagnostics
2. **After editing**: Run `dart analyze` again to verify no regressions
3. **Widget changes**: Trigger hot reload (handled by IDE)
4. **New features**: Write tests first (TDD)
5. **Refactoring**: Use Dart analyzer refactorings (extract widget, method, etc.)

## Common Patterns to Use

```dart
// Service with proper disposal
class CameraService {
  CameraController? _controller;
  StreamSubscription<CameraImage>? _subscription;
  
  Future<void> initialize() async { ... }
  
  void dispose() {
    _subscription?.cancel();
    _controller?.dispose();
  }
}

// Riverpod provider with async initialization
@riverpod
Future<CameraController> cameraController(CameraControllerRef ref) async {
  final controller = CameraController(...);
  await controller.initialize();
  ref.onDispose(() => controller.dispose());
  return controller;
}

// Use case pattern
class ProcessFrameUseCase {
  final MlKitService _mlKit;
  ProcessFrameUseCase(this._mlKit);
  
  Future<ScanResult?> execute(CameraImage image) async {
    if (_isProcessing) return null;
    _isProcessing = true;
    try {
      return await _mlKit.processFrame(image);
    } finally {
      _isProcessing = false;
    }
  }
}
```

## Dependencies (pubspec.yaml key packages)

```yaml
dependencies:
  flutter: sdk: flutter
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
  supabase_flutter: ^2.3.4
  camera: ^0.10.5+9
  google_ml_kit: ^0.15.0
  mobile_scanner: ^5.1.1
  geolocator: ^11.0.0
  permission_handler: ^11.2.0
  intl: ^0.19.0
  equatable: ^2.0.5
  flutter_animate: ^4.5.0
  logger: ^2.2.0
  drift: ^2.14.0  # offline SQLite
  path_provider: ^2.1.1

dev_dependencies:
  flutter_test: sdk: flutter
  flutter_lints: ^3.0.0
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.7
  custom_lint: ^0.6.0
  riverpod_lint: ^2.3.7
  mocktail: ^1.0.0
  integration_test: sdk: flutter
```

## Environment Setup

- Flutter SDK: 3.22+
- Dart SDK: 3.4+
- Android Studio / VS Code with Flutter extension
- Supabase CLI for local development
- Physical devices for camera testing (simulator limited)

## Debugging Tips

- Use `flutter logs` for device logs
- DevTools: `flutter pub global run devtools`
- Inspector for widget tree
- Performance view for frame rendering
- Network view for Supabase calls

---

**When working on this project, always:**
1. Check `dart analyze` before and after changes
2. Write tests for new logic
3. Follow the existing architecture patterns
4. Use the established service/provider patterns
5. Keep UI responsive (60/120fps) during camera preview