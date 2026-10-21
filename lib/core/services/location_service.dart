import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocationService {
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
    double lat1, double lon1, double lat2, double lon2,
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