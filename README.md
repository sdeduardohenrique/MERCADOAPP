# SomaAí 🛒

Smart grocery shopping assistant with camera-based price scanning, real-time cart calculator, and community price comparison network.

## Features

- **📷 Camera Scanner**: Point camera at price labels to extract product name, price, and EAN barcode
- **🗣️ Voice Input**: Add items by voice (planned)
- **⌨️ Manual Entry**: Type items manually
- **💰 Real-time Cart**: Live total calculation as you scan
- **🤝 Community Prices**: See if nearby stores have better prices
- **⚡ Smart Alerts**: Configurable notifications for savings opportunities
- **📍 Geolocation**: Automatic nearby store detection
- **⏰ Price Freshness**: 72-hour TTL prevents stale promo data

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter 3.22+ (Dart 3.4+) |
| State Management | Riverpod 2.4+ |
| Backend | Supabase (PostgreSQL + Realtime + Edge Functions + Storage) |
| Camera | `camera` plugin |
| OCR | Google ML Kit Text Recognition v2 |
| Barcode | `mobile_scanner` (ZXing) + ML Kit Barcode |
| Location | `geolocator` + `permission_handler` |
| Offline | Drift (SQLite) |
| Animations | `flutter_animate` |

## Architecture

```
lib/
├── core/
│   ├── constants/          # App constants
│   ├── services/           # Camera, ML Kit, Supabase, Location, Price Validation
│   ├── models/             # CartItem, CommunityPrice, Store, Product
│   ├── utils/              # PriceParser, EanValidator, TextNormalizer
│   └── theme/              # Material 3 themes (light/dark)
├── features/
│   ├── scanner/            # Camera + OCR + Cart integration
│   ├── cart/               # Cart state management
│   └── community_alerts/   # Price alerts & preferences
└── main.dart               # App entry point
```

## Getting Started

### Prerequisites

- Flutter SDK 3.22+
- Dart SDK 3.4+
- Supabase account
- Physical Android/iOS device (camera required)

### Setup

1. **Clone and install dependencies**
```bash
flutter pub get
```

2. **Configure Supabase**
   - Create project at [supabase.com](https://supabase.com)
   - Run SQL migrations from `supabase/migrations/`
   - Copy `.env.example` to `.env` and add credentials

3. **Run the app**
```bash
# Development
flutter run --flavor dev

# Production
flutter run --flavor prod --release
```

### Supabase Database Setup

Run these migrations in Supabase SQL Editor:

```sql
-- See supabase/migrations/ for complete schema
-- Key tables: products, stores, community_prices, profiles
-- RPC functions: find_better_prices_nearby, find_stores_nearby
-- Enable RLS on all tables
```

## Configuration

### Environment Variables

Create `.env` file:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### App Constants (lib/core/constants/app_constants.dart)

- `cameraFrameIntervalMs`: Frame processing interval (default 500ms)
- `minSavingsThreshold`: Minimum savings to alert (default R$ 0.50)
- `minSavingsPercentage`: Minimum % savings to alert (default 5%)
- `priceTtlHours`: Community price TTL (default 72 hours)

## Development

### Code Generation

```bash
# Generate Riverpod providers
dart run build_runner build --delete-conflicting-outputs

# Watch mode
dart run build_runner watch --delete-conflicting-outputs
```

### Testing

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Linting & Formatting

```bash
dart analyze
dart format .
```

## AI-Assisted Development

This project is configured for AI coding assistants:

- **MCP Server**: `.vscode/mcp.json` - Dart analyzer, test runner, symbol resolution
- **Flutter Skills**: `.agents/skills/` - Official Flutter/Dart agent skills
- **Rules**: `CLAUDE.md` / `.github/copilot-instructions.md` - Project-specific guidelines

### Supported Assistants

- VS Code + GitHub Copilot
- Cursor
- Claude Code
- Codex
- Antigravity

## Project Structure Details

### Core Services

| Service | Purpose |
|---------|---------|
| `CameraService` | Camera initialization, frame streaming, flashlight |
| `MlKitService` | OCR (Text Recognition v2) + Barcode scanning |
| `PriceValidationService` | Community price checks with caching |
| `LocationService` | GPS with caching and permissions |
| `SupabaseService` | Database operations, auth, storage |

### Key Algorithms

**Price Parser** (`lib/core/utils/price_parser.dart`):
- Handles Brazilian formats: "R$ 8,90", "2x 4,45", "3 por 10,00"
- Extracts name, brand, unit price, quantity, unit

**EAN Validator** (`lib/core/utils/ean_validator.dart`):
- Validates EAN-8, EAN-13, UPC-A, UPC-E checksums
- Normalizes to GTIN-13

**Text Normalizer** (`lib/core/utils/text_normalizer.dart`):
- Removes Portuguese accents
- Fuzzy matching for product names
- Known Brazilian brand database

## Roadmap

- [ ] Phase 1: MVP Core (Camera + OCR + Cart + Sync)
- [ ] Phase 2: Community Features (Price validation, stores, alerts)
- [ ] Phase 3: UX Polish (Voice, manual entry, offline-first)
- [ ] Phase 4: Gamification (Trust score, badges, leaderboards)

## Contributing

1. Fork the repository
2. Create feature branch
3. Follow code style (`dart analyze`, `dart format`)
4. Write tests for new features
5. Submit PR

## License

MIT License - see LICENSE file

---

Built with ❤️ using Flutter + Supabase