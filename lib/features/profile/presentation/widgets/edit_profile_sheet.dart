import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';

/// Abre a modal de edição do perfil.
Future<void> showEditProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const EditProfileSheet(),
  );
}

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final UserProfile _profile;

  Uint8List? _avatarBytes;
  String? _avatarContentType;
  String? _avatarExtension;

  bool _picking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = ref.read(userProfileProvider);
    _nameController = TextEditingController(text: _profile.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _pickAvatar() async {
    if (_picking || _saving) return;

    if (_profile.isGuest) {
      _showError('Crie uma conta gratuita para usar foto de perfil.');
      return;
    }

    setState(() => _picking = true);

    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      final name = file.name.toLowerCase();
      final extension = name.contains('.') ? name.split('.').last : 'jpg';
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      setState(() {
        _avatarBytes = bytes;
        _avatarContentType = contentType;
        _avatarExtension =
            extension == 'png' || extension == 'webp' ? extension : 'jpg';
      });
    } on PlatformException catch (error) {
      _showError(
        error.code == 'photo_access_denied'
            ? 'Permissão de fotos negada. Libere nas configurações do app.'
            : 'Não foi possível abrir a galeria agora.',
      );
    } catch (_) {
      _showError('Não foi possível carregar a foto. Tente novamente.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final error = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(
          name: _nameController.text,
          avatarBytes: _avatarBytes,
          avatarContentType: _avatarContentType,
          avatarExtension: _avatarExtension,
        );

    if (!mounted) return;

    if (error != null) {
      setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Perfil atualizado com sucesso!'),
          backgroundColor: AppTheme.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Widget _buildAvatarPreview(String currentName) {
    final initials = _initialsFor(currentName);
    final fallback = Container(
      color: AppTheme.emeraldTint,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: AppTheme.emeraldDark,
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    Widget child;
    if (_avatarBytes != null) {
      child = Image.memory(_avatarBytes!, fit: BoxFit.cover);
    } else if ((_profile.avatarUrl ?? '').isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: _profile.avatarUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      );
    } else {
      child = fallback;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 96,
          height: 96,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.emerald.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
          child: child,
        ),
        if (_picking)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x66000000),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (!_profile.isGuest)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.emerald,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.photo_camera_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Editar perfil',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: GestureDetector(
                      onTap: _picking || _saving ? null : _pickAvatar,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _nameController,
                        builder: (_, value, __) =>
                            _buildAvatarPreview(value.text),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _picking || _saving ? null : _pickAvatar,
                      icon: Icon(
                        _profile.isGuest
                            ? Icons.lock_outline_rounded
                            : Icons.photo_library_rounded,
                        size: 17,
                      ),
                      label: Text(
                        _profile.isGuest
                            ? 'Foto disponível com conta'
                            : 'Trocar foto',
                      ),
                    ),
                  ),
                  if (_profile.isGuest) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.amberTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 17,
                            color: Color(0xFFB26B00),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Você está no modo visitante. O apelido fica '
                              'salvo apenas neste aparelho; crie uma conta '
                              'para usar foto e sincronizar o perfil.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    maxLength: 60,
                    onFieldSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      labelText: 'Nome de exibição',
                      hintText: 'Como você quer ser chamado',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      counterText: '',
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.length < 2) {
                        return 'Informe pelo menos 2 caracteres.';
                      }
                      if (name.length > 60) {
                        return 'Use no máximo 60 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: _profile.isGuest
                        ? 'Conta de visitante'
                        : _profile.email,
                    readOnly: true,
                    enableInteractiveSelection: false,
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      suffixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                      ),
                      helperText: _profile.isGuest
                          ? 'Crie uma conta para vincular um e-mail.'
                          : 'O e-mail não pode ser alterado por segurança.',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                            disabledBackgroundColor:
                                AppTheme.emerald.withValues(alpha: 0.6),
                          ),
                          child: _saving
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 17,
                                      height: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 9),
                                    Text('Salvando...'),
                                  ],
                                )
                              : const Text(
                                  'Salvar Alterações',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
