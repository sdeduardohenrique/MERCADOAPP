import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/profile_service.dart';

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
  final String? avatarUrl;

  const UserProfile({
    required this.name,
    required this.email,
    required this.city,
    required this.memberSince,
    this.isGuest = false,
    this.avatarUrl,
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
  final avatarUrl =
      (metadata['avatar_url'] ?? metadata['picture'] ?? '').toString().trim();

  return UserProfile(
    name: name,
    email: email,
    city: city,
    memberSince: createdAt ?? DateTime.now(),
    avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
  );
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  return const ProfileService();
});

/// Controla a edição do perfil e mantém o estado da operação para a UI.
class ProfileController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Salva nome/avatar.
  ///
  /// Retorna `null` em caso de sucesso ou a mensagem amigável de erro.
  Future<String?> updateProfile({
    required String name,
    Uint8List? avatarBytes,
    String? avatarContentType,
    String? avatarExtension,
  }) async {
    state = const AsyncLoading();

    try {
      final guest = ref.read(guestSessionProvider);
      if (guest != null) {
        // Visitante: só o apelido, sempre local. Foto exige conta.
        if (avatarBytes != null) {
          throw const ProfileUpdateException(
            'Crie uma conta gratuita para usar foto de perfil.',
          );
        }
        await ref.read(guestSessionProvider.notifier).start(name);
      } else {
        await ref.read(profileServiceProvider).updateProfile(
              displayName: name,
              avatarBytes: avatarBytes,
              avatarContentType: avatarContentType,
              avatarExtension: avatarExtension,
            );

        // Metadados mudaram: recompõe o perfil e atualiza Dashboard/Card.
        ref.invalidate(userProfileProvider);
      }

      state = const AsyncData(null);
      return null;
    } catch (error) {
      state = AsyncError(error, StackTrace.current);
      return ProfileUpdateException.messageFor(error);
    }
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, void>(ProfileController.new);
