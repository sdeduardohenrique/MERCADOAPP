import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Perfil local do utilizador.
///
/// Ainda não há autenticação: estes dados são o placeholder até o login
/// Supabase entrar. A UI já consome o provider, então a troca é transparente.
class UserProfile {
  final String name;
  final String email;
  final String city;
  final DateTime memberSince;

  const UserProfile({
    required this.name,
    required this.email,
    required this.city,
    required this.memberSince,
  });

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'S';
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
  return UserProfile(
    name: 'Eduardo Alves',
    email: 'eduardo@somaai.app',
    city: 'São Paulo, SP',
    memberSince: DateTime(2024, 3),
  );
});
