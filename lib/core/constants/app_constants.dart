// App-wide constants
class AppConstants {
  // Supabase - Configured via MCP
  static const String supabaseUrl = 'https://vvoqamnucengagpwwozt.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2b3FhbW51Y2VuZ2FncHd3b3p0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0MTYzNDEsImV4cCI6MjEwNzk5MjM0MX0.qvGacaBT_ha5xKo6Hebbq2Abu1d1KuT8Axx3VZY3rxk';

  // App Configuration
  static const String appName = 'SomaAí';
  static const String appVersion = '1.0.0';

  // Camera Settings
  static const int cameraFrameIntervalMs = 500; // Process frame every 500ms (2fps)
  static const double scanOverlayWidthRatio = 0.85;
  static const double scanOverlayHeight = 120.0;

  // Price Validation
  static const Duration priceCacheTtl = Duration(minutes: 5);
  static const double minSavingsThreshold = 0.50; // R$ 0,50
  static const double minSavingsPercentage = 5.0; // 5%
  static const int searchRadiusKm = 15;

  // Community Price TTL
  static const int priceTtlHours = 72;

  // Storage Keys
  static const String keyAlertsEnabled = 'alerts_enabled';
  static const String keyMinSavingsThreshold = 'min_savings_threshold';
  static const String keyMinSavingsPercentage = 'min_savings_pct';
  static const String keyFirstLaunch = 'first_launch';

  // OCR Patterns
  static const String brazilianPricePattern = r'(?:R\$\s?)?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)';
  static const String quantityPattern = r'(\d+(?:[.,]\d+)?)\s*(?:x|X|un|unid|kg|g|ml|l|L)\b';
  static const String promoPattern = r'(\d+)\s*(?:x|X|por)\s*(?:R\$\s?)?(\d+(?:[.,]\d{2})?)';
}