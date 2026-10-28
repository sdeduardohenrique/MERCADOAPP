import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

/// Erro de negócio ao atualizar o perfil (mensagem já tratada para a UI).
class ProfileUpdateException implements Exception {
  final String message;

  const ProfileUpdateException(this.message);

  @override
  String toString() => message;

  /// Converte erros do Supabase/rede em mensagens amigáveis em pt-BR.
  static String messageFor(Object error) {
    if (error is ProfileUpdateException) return error.message;

    if (error is AuthException) {
      return 'Não foi possível atualizar a conta: ${error.message}';
    }
    if (error is StorageException) {
      return 'Não foi possível enviar a foto. Tente novamente.';
    }
    if (error is PostgrestException) {
      return 'Não foi possível salvar os dados do perfil. Tente novamente.';
    }
    if (error is SocketException || error is ClientException) {
      return 'Sem conexão com a internet. Verifique sua rede e tente novamente.';
    }
    return 'Não foi possível salvar o perfil. Tente novamente.';
  }
}

class ProfileUpdateResult {
  final String displayName;
  final String? avatarUrl;

  const ProfileUpdateResult({
    required this.displayName,
    this.avatarUrl,
  });
}

/// Persistência do perfil no Supabase.
///
/// Estratégia:
/// 1. (opcional) envia a nova foto para o bucket público `avatars`;
/// 2. grava `display_name`/`avatar_url` na tabela `profiles` (registro canônico);
/// 3. atualiza os metadados da conta (`full_name`/`avatar_url`) para que o app
///    reflita a mudança imediatamente via `currentUser.userMetadata`.
class ProfileService {
  const ProfileService();

  Future<ProfileUpdateResult> updateProfile({
    required String displayName,
    Uint8List? avatarBytes,
    String? avatarContentType,
    String? avatarExtension,
  }) async {
    final name = displayName.trim();
    if (name.length < 2) {
      throw const ProfileUpdateException(
        'Informe um nome com pelo menos 2 caracteres.',
      );
    }

    if (!SupabaseService.isReady) {
      throw const ProfileUpdateException(
        'Você está offline. Conecte-se para salvar o perfil.',
      );
    }

    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const ProfileUpdateException(
        'Sua sessão expirou. Entre novamente para editar o perfil.',
      );
    }

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    var avatarUrl = (metadata['avatar_url'] ?? '').toString().trim();
    if (avatarUrl.isEmpty) avatarUrl = '';

    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      avatarUrl = await _uploadAvatar(
        client: client,
        userId: user.id,
        bytes: avatarBytes,
        contentType: avatarContentType ?? 'image/jpeg',
        extension: avatarExtension ?? 'jpg',
      );
    }

    final finalAvatarUrl = avatarUrl.isEmpty ? null : avatarUrl;

    try {
      // Registro canônico. O upsert cobre usuários criados antes do trigger.
      await SupabaseService.updateProfile(
        displayName: name,
        avatarUrl: finalAvatarUrl,
      );
    } on PostgrestException catch (error) {
      debugPrint('[ProfileService] upsert em profiles falhou: $error');
      throw const ProfileUpdateException(
        'Não foi possível salvar os dados do perfil. Tente novamente.',
      );
    }

    // Metadados: fonte usada pela UI para atualização instantânea.
    await client.auth.updateUser(
      UserAttributes(
        data: {
          'full_name': name,
          if (finalAvatarUrl != null) 'avatar_url': finalAvatarUrl,
        },
      ),
    );

    return ProfileUpdateResult(
      displayName: name,
      avatarUrl: finalAvatarUrl,
    );
  }

  Future<String> _uploadAvatar({
    required SupabaseClient client,
    required String userId,
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    final bucket = client.storage.from('avatars');
    final safeExtension = switch (extension.toLowerCase()) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
    final fileName =
        'avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    final path = '$userId/$fileName';

    try {
      await bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          cacheControl: '3600',
          upsert: true,
        ),
      );

      // Limpeza best-effort das fotos antigas do próprio usuário.
      try {
        final files = await bucket.list(path: userId);
        final antigos = files
            .where((file) => file.name != fileName)
            .map((file) => '$userId/${file.name}')
            .toList(growable: false);
        if (antigos.isNotEmpty) {
          await bucket.remove(antigos);
        }
      } catch (error) {
        debugPrint('[ProfileService] limpeza de avatares antigos: $error');
      }

      return bucket.getPublicUrl(path);
    } on StorageException {
      rethrow;
    } catch (error) {
      debugPrint('[ProfileService] upload do avatar falhou: $error');
      throw const ProfileUpdateException(
        'Não foi possível enviar a foto. Tente novamente.',
      );
    }
  }
}
