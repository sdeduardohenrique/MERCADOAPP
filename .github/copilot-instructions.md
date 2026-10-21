# Flutter Development Instructions for AI Assistants

## General Principles

- Follow Flutter and Dart best practices from official documentation
- Use Material 3 and Cupertino widgets appropriately
- Prefer composition over inheritance
- Write declarative UI code
- Use `const` constructors wherever possible
- Leverage hot reload for rapid iteration

## Architecture

- Follow the official Flutter app architecture guide
- Separate UI layer from business logic
- Use Repository pattern for data access
- Implement proper dependency injection
- Use Riverpod or Provider for state management

## Code Style

- Follow Dart style guide and Effective Dart
- Use `flutter_lints` package
- Run `dart format` before committing
- Run `dart analyze` to catch issues early

## Testing

- Write unit tests for business logic
- Write widget tests for UI components
- Write integration tests for critical user flows
- Use `flutter_test` package
- Mock dependencies using `mocktail` or `mockito`

## Performance

- Profile with DevTools before optimizing
- Use `const` widgets to enable rebuild optimizations
- Avoid unnecessary widget rebuilds
- Use `ListView.builder` for long lists
- Implement pagination for large datasets

## Platform Integration

- Use platform channels for native code
- Follow platform-specific guidelines (Material/Human Interface)
- Handle permissions properly
- Test on both iOS and Android

## AI Assistant Specific Rules

- Always run `dart analyze` after making changes
- Trigger hot reload when editing widget code
- Use official Flutter packages from pub.dev
- Prefer `google_ml_kit` for ML tasks
- Use `supabase_flutter` for backend
- Follow null safety strictly