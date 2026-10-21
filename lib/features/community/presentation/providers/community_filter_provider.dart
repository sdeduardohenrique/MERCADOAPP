import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/community_offer.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/community_service.dart';

/// Região exibida na aba Comunidade.
///
/// O utilizador pode escolher "perto de mim" (com raio ajustável) ou digitar
/// uma cidade/bairro. As coordenadas são mantidas quando disponíveis para que
/// as ofertas de outra cidade ainda mostrem a distância.
class CommunityFilter {
  final double? latitude;
  final double? longitude;
  final double radiusKm;
  final String? city;

  const CommunityFilter({
    this.latitude,
    this.longitude,
    this.radiusKm = 10,
    this.city,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasCity => city != null && city!.trim().isNotEmpty;

  String get label {
    if (hasCity) return city!.trim();
    if (hasCoordinates) {
      return 'Até ${radiusKm.toStringAsFixed(0)} km';
    }
    return 'Escolha uma região';
  }

  String get subtitle {
    if (hasCity) {
      return hasCoordinates
          ? 'Ofertas da cidade • distância calculada daqui'
          : 'Ofertas da cidade selecionada';
    }
    if (hasCoordinates) {
      return 'Ofertas perto da sua localização';
    }
    return 'Toque para usar o GPS ou escolher uma cidade';
  }

  CommunityFilter nearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
  }) {
    return CommunityFilter(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm ?? this.radiusKm,
      city: null,
    );
  }

  CommunityFilter byCity(String city, {double? radiusKm}) {
    return CommunityFilter(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm ?? this.radiusKm,
      city: city.trim(),
    );
  }

  CommunityFilter withRadius(double value) {
    return CommunityFilter(
      latitude: latitude,
      longitude: longitude,
      radiusKm: value,
      city: city,
    );
  }
}

class CommunityFilterNotifier extends StateNotifier<CommunityFilter> {
  CommunityFilterNotifier({CommunityFilter? initial})
      : super(initial ?? const CommunityFilter());

  void useNearby({
    required double latitude,
    required double longitude,
    double? radiusKm,
  }) {
    state = state.nearby(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
  }

  void useCity(String city, {double? radiusKm}) {
    if (city.trim().isEmpty) return;
    state = state.byCity(city, radiusKm: radiusKm);
  }

  void setRadius(double radiusKm) {
    state = state.withRadius(radiusKm);
  }

  void apply(CommunityFilter filter) {
    state = filter;
  }
}

final communityFilterProvider =
    StateNotifierProvider<CommunityFilterNotifier, CommunityFilter>((ref) {
  // Começa na cidade do perfil em vez de disparar o GPS ao abrir a aba. O
  // seletor de região troca para "perto de mim" quando o utilizador quiser.
  final profile = ref.read(userProfileProvider);
  final city = profile.city.split(',').first.trim();
  return CommunityFilterNotifier(
    initial: CommunityFilter(city: city.length >= 2 ? city : null),
  );
});

final communityOffersProvider =
    FutureProvider.autoDispose<List<CommunityOffer>>((ref) async {
  final filter = ref.watch(communityFilterProvider);
  return ref.watch(communityServiceProvider).listOffers(
        latitude: filter.latitude,
        longitude: filter.longitude,
        radiusKm: filter.radiusKm,
        city: filter.city,
      );
});
