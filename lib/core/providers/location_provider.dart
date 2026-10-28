import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/location_service.dart';

/// Estado global de geolocalização do app.
///
/// Guarda a última leitura de alta precisão para que buscas, mercado e
/// comunidade consumam o MESMO ponto — nenhuma tela deve pedir o GPS do zero.
class AppLocationState {
  final bool isLoading;
  final LocationCoordinates? coordinates;
  final LocationAccessStatus? status;
  final DateTime? updatedAt;

  const AppLocationState({
    this.isLoading = false,
    this.coordinates,
    this.status,
    this.updatedAt,
  });

  bool get hasCoordinates => coordinates != null;

  bool get hasFailure =>
      !isLoading &&
      !hasCoordinates &&
      status != null &&
      status != LocationAccessStatus.success;

  double? get accuracyMeters => coordinates?.accuracyMeters;

  Duration? get age {
    final at = updatedAt;
    if (at == null) return null;
    return DateTime.now().difference(at);
  }
}

typedef LocationResolver = Future<LocationAccessResult> Function();

/// Fonte única de localização do app.
///
/// - `refresh()` sempre faz uma leitura nova em alta precisão;
/// - `ensureCoordinates()` reaproveita a leitura recente (evita abrir o GPS a
///   cada tela) e renova quando expirou;
/// - em falha as coordenadas antigas são descartadas para nunca vincular a
///   compra a um mercado errado.
class LocationNotifier extends StateNotifier<AppLocationState> {
  LocationNotifier({
    LocationService? service,
    LocationResolver? resolver,
  })  : _service = service ?? LocationService(),
        _resolver = resolver,
        super(const AppLocationState());

  final LocationService _service;
  final LocationResolver? _resolver;

  /// Quanto tempo uma leitura pode ser reaproveitada entre telas.
  static const Duration freshness = Duration(minutes: 2);

  Future<LocationAccessResult>? _inFlight;

  Future<LocationAccessResult> refresh() {
    final running = _inFlight;
    if (running != null) return running;

    final future = _run();
    _inFlight = future;
    return future.whenComplete(() {
      _inFlight = null;
    });
  }

  /// Usa a posição atual se ela for recente; caso contrário pede uma nova.
  Future<LocationAccessResult> ensureCoordinates({bool force = false}) async {
    final current = state;
    final age = current.age;
    final fresh =
        current.hasCoordinates && age != null && age < freshness && !force;

    if (fresh) {
      return LocationAccessResult.success(current.coordinates!);
    }

    return refresh();
  }

  void clear() {
    state = const AppLocationState();
  }

  Future<LocationAccessResult> _run() async {
    state = AppLocationState(
      isLoading: true,
      coordinates: state.coordinates,
      status: state.status,
      updatedAt: state.updatedAt,
    );

    final result =
        await (_resolver?.call() ?? _service.resolveCurrentPosition());

    if (!mounted) return result;

    if (result.hasCoordinates) {
      final coordinates = result.coordinates!;
      debugPrint(
        '[LocationProvider] posição global atualizada: '
        'lat=${coordinates.latitude.toStringAsFixed(6)} '
        'lng=${coordinates.longitude.toStringAsFixed(6)} '
        'precisão=${coordinates.accuracyMeters?.toStringAsFixed(1) ?? '?'}m',
      );
      state = AppLocationState(
        coordinates: coordinates,
        status: LocationAccessStatus.success,
        updatedAt: DateTime.now(),
      );
    } else {
      debugPrint(
        '[LocationProvider] não foi possível localizar: ${result.status}',
      );
      state = AppLocationState(status: result.status);
    }

    return result;
  }
}

/// Provider global de localização (fonte única para todo o app).
final locationProvider =
    StateNotifierProvider<LocationNotifier, AppLocationState>((ref) {
  return LocationNotifier(
    service: ref.watch(locationServiceProvider),
  );
});
