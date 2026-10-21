import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coordenadas simples, sem acoplar a UI ao pacote `geolocator`.
class LocationCoordinates {
  final double latitude;
  final double longitude;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
  });
}

enum LocationAccessStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  timeout,
  error,
}

class LocationAccessResult {
  final LocationAccessStatus status;
  final LocationCoordinates? coordinates;

  const LocationAccessResult._(this.status, this.coordinates);

  const LocationAccessResult.success(LocationCoordinates coordinates)
      : this._(LocationAccessStatus.success, coordinates);

  const LocationAccessResult.failure(LocationAccessStatus status)
      : this._(status, null);

  bool get hasCoordinates => coordinates != null;
}

class LocationService {
  /// Resolve permissão + serviço + posição sem abrir configurações sozinho.
  ///
  /// A UI de identificação de mercado precisa distinguir "permissão negada"
  /// de "GPS desligado" para oferecer a ação correta. O fluxo antigo
  /// ([getCurrentPosition]) continua disponível para os alertas.
  Future<LocationAccessResult> resolveCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 12),
    bool forceRefresh = false,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationAccessResult.failure(
          LocationAccessStatus.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationAccessResult.failure(
          LocationAccessStatus.permissionDenied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationAccessResult.failure(
          LocationAccessStatus.permissionPermanentlyDenied,
        );
      }

      if (!forceRefresh &&
          _lastPosition != null &&
          _lastPositionTime != null &&
          DateTime.now().difference(_lastPositionTime!) < _positionCacheTtl) {
        return LocationAccessResult.success(
          LocationCoordinates(
            latitude: _lastPosition!.latitude,
            longitude: _lastPosition!.longitude,
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
      );
      _lastPosition = position;
      _lastPositionTime = DateTime.now();

      return LocationAccessResult.success(
        LocationCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on TimeoutException {
      return const LocationAccessResult.failure(LocationAccessStatus.timeout);
    } catch (_) {
      // Um último ponto conhecido ainda ajuda a listar mercados próximos.
      if (_lastPosition != null) {
        return LocationAccessResult.success(
          LocationCoordinates(
            latitude: _lastPosition!.latitude,
            longitude: _lastPosition!.longitude,
          ),
        );
      }
      return const LocationAccessResult.failure(LocationAccessStatus.error);
    }
  }

  Future<bool> openAppSettingsPage() => Geolocator.openAppSettings();

  Future<bool> openLocationSettingsPage() => Geolocator.openLocationSettings();

  Position? _lastPosition;
  DateTime? _lastPositionTime;
  static const Duration _positionCacheTtl = Duration(seconds: 30);

  /// Get current position with caching
  Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration? timeout,
  }) async {
    // Return cached position if fresh
    if (_lastPosition != null && _lastPositionTime != null) {
      if (DateTime.now().difference(_lastPositionTime!) < _positionCacheTtl) {
        return _lastPosition;
      }
    }

    // Check permissions
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return null;

    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout ?? const Duration(seconds: 10),
      );
      _lastPositionTime = DateTime.now();
      return _lastPosition;
    } catch (e) {
      // Return last known position even if stale
      return _lastPosition;
    }
  }

  /// Ensure location permission is granted
  Future<bool> _ensureLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;

    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // Open app settings
      await openAppSettings();
      return false;
    }

    return false;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get distance between two points in meters
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void clearCache() {
    _lastPosition = null;
    _lastPositionTime = null;
  }
}

/// Riverpod provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
