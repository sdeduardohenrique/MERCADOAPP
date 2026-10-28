import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/supabase_service.dart';

/// Perfil exibido no Dashboard e na aba Perfil.
///
/// - Visitante: usa apenas o apelido salvo localmente.
/// - Conta real: lê os metadados da sessão do Supabase (sem chamadas extras).
class UserProfile {
  final String name;
  final String email;
  final String city;
  final DateTime memberSince;
  final bool isGuest;

  const UserProfile({
    required this.name,
    required this.email,
    required this.city,
    required this.memberSince,
    this.isGuest = false,
  });

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String get memberSinceLabel {
    const months = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    return '${months[memberSince.month - 1]}/${memberSince.year}';
  }
}

final userProfileProvider = Provider<UserProfile>((ref) {
  final guest = ref.watch(guestSessionProvider);
  if (guest != null) {
    return UserProfile(
      name: guest.name,
      email: '',
      city: '',
      memberSince: DateTime.now(),
      isGuest: true,
    );
  }

  final user = SupabaseService.currentUser;
  final metadata = user?.userMetadata ?? const <String, dynamic>{};
  final rawName =
      (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();
  final email = user?.email ?? '';
  final name = rawName.isNotEmpty
      ? rawName
      : (email.isNotEmpty ? email.split('@').first : 'Usuário');

  final createdAt = DateTime.tryParse(user?.createdAt ?? '');
  final city = (metadata['city'] ?? metadata['cidade'] ?? '').toString().trim();

  return UserProfile(
    name: name,
    email: email,
    city: city,
    memberSince: createdAt ?? DateTime.now(),
  );
});
