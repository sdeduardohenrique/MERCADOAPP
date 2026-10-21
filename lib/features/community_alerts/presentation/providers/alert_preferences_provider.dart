import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alert preferences state
class AlertPreferences {
  final bool alertsEnabled;
  final double minSavingsThreshold;
  final double minSavingsPercentage;
  final bool showOnlyVerifiedStores;
  final int maxDistanceKm;

  const AlertPreferences({
    this.alertsEnabled = true,
    this.minSavingsThreshold = 0.50,
    this.minSavingsPercentage = 5.0,
    this.showOnlyVerifiedStores = false,
    this.maxDistanceKm = 15,
  });

  AlertPreferences copyWith({
    bool? alertsEnabled,
    double? minSavingsThreshold,
    double? minSavingsPercentage,
    bool? showOnlyVerifiedStores,
    int? maxDistanceKm,
  }) {
    return AlertPreferences(
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      minSavingsThreshold: minSavingsThreshold ?? this.minSavingsThreshold,
      minSavingsPercentage: minSavingsPercentage ?? this.minSavingsPercentage,
      showOnlyVerifiedStores:
          showOnlyVerifiedStores ?? this.showOnlyVerifiedStores,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
    );
  }
}

/// Alert preferences notifier
class AlertPreferencesNotifier extends StateNotifier<AlertPreferences> {
  AlertPreferencesNotifier() : super(const AlertPreferences()) {
    _loadPrefs();
  }

  static const _prefsKeys = {
    'enabled': 'alerts_enabled',
    'threshold': 'min_savings_threshold',
    'percentage': 'min_savings_pct',
    'verified': 'show_verified_only',
    'distance': 'max_distance_km',
  };

  /// Partilha de preferências tolerante a ambientes sem plugin (testes).
  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[SomaAí] Preferências de alerta indisponíveis: $e');
      return null;
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await _prefs();
    if (prefs == null) return;
    state = state.copyWith(
      alertsEnabled: prefs.getBool(_prefsKeys['enabled']!) ?? true,
      minSavingsThreshold: prefs.getDouble(_prefsKeys['threshold']!) ?? 0.50,
      minSavingsPercentage: prefs.getDouble(_prefsKeys['percentage']!) ?? 5.0,
      showOnlyVerifiedStores: prefs.getBool(_prefsKeys['verified']!) ?? false,
      maxDistanceKm: prefs.getInt(_prefsKeys['distance']!) ?? 15,
    );
  }

  Future<void> toggleAlerts(bool enabled) async {
    state = state.copyWith(alertsEnabled: enabled);
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.setBool(_prefsKeys['enabled']!, enabled);
  }

  Future<void> updateThreshold(double threshold) async {
    state = state.copyWith(minSavingsThreshold: threshold);
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.setDouble(_prefsKeys['threshold']!, threshold);
  }

  Future<void> updatePercentage(double percentage) async {
    state = state.copyWith(minSavingsPercentage: percentage);
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.setDouble(_prefsKeys['percentage']!, percentage);
  }

  Future<void> updateVerifiedOnly(bool verified) async {
    state = state.copyWith(showOnlyVerifiedStores: verified);
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.setBool(_prefsKeys['verified']!, verified);
  }

  Future<void> updateMaxDistance(int km) async {
    state = state.copyWith(maxDistanceKm: km);
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.setInt(_prefsKeys['distance']!, km);
  }

  Future<void> resetToDefaults() async {
    state = const AlertPreferences();
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.clear();
  }
}

/// Provider
final alertPreferencesProvider =
    StateNotifierProvider<AlertPreferencesNotifier, AlertPreferences>((ref) {
  return AlertPreferencesNotifier();
});
