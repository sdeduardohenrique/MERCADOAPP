import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coordenadas simples, sem acoplar a UI ao pacote `geolocator`.
class LocationCoordinates {
  final double latitude;
  final double longitude;

  /// Precisão informada pelo sistema, em metros.
  final double? accuracyMeters;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  @override
  String toString() => 'LocationCoordinates('
      'lat: $latitude, lng: $longitude'
      '${accuracyMeters != null ? ', precisão: ${accuracyMeters!.toStringAsFixed(1)} m' : ''})';
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

/// Resolve permissão + serviço + posição.
///
/// Regras importantes contra o "local errado":
/// - sempre pede uma leitura nova (`getCurrentPosition`), nunca reaproveita
///   cache nem `getLastKnownPosition`;
/// - usa `LocationAccuracy.best` por padrão (GPS + alta precisão);
/// - em caso de falha devolve erro em vez de uma coordenada antiga.
class LocationService {
  Future<LocationAccessResult> resolveCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.best,
    Duration timeout = const Duration(seconds: 15),
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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
      );

      // Log de auditoria: permite conferir no `adb logcat` se a coordenada
      // capturada corresponde ao local físico real.
      debugPrint(
        '[Localização] lat=${position.latitude.toStringAsFixed(6)} '
        'lng=${position.longitude.toStringAsFixed(6)} '
        'precisão=${position.accuracy.toStringAsFixed(1)}m '
        'mock=${position.isMocked}',
      );

      return LocationAccessResult.success(
        LocationCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
        ),
      );
    } on TimeoutException {
      debugPrint('[Localização] tempo esgotado ao aguardar o GPS.');
      return const LocationAccessResult.failure(LocationAccessStatus.timeout);
    } catch (error) {
      debugPrint('[Localização] falha ao capturar posição: $error');
      return const LocationAccessResult.failure(LocationAccessStatus.error);
    }
  }

  Future<bool> openAppSettingsPage() => Geolocator.openAppSettings();

  Future<bool> openLocationSettingsPage() => Geolocator.openLocationSettings();

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

/// Riverpod provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
