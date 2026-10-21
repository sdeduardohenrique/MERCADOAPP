import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/mercado.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/community_service.dart';
import '../providers/market_provider.dart';
import 'market_selection_sheet.dart';

/// Abre o formulário de publicação de uma oferta.
///
/// Retorna `true` quando a oferta foi persistida no Supabase.
Future<bool?> showOfferContributionSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const OfferContributionSheet(),
  );
}

class OfferContributionSheet extends ConsumerStatefulWidget {
  const OfferContributionSheet({super.key});

  @override
  ConsumerState<OfferContributionSheet> createState() =>
      _OfferContributionSheetState();
}

class _OfferContributionSheetState
    extends ConsumerState<OfferContributionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _eanController = TextEditingController();
  final _priceController = TextEditingController();
  final _oldPriceController = TextEditingController();

  late Mercado? _market = ref.read(selectedMarketProvider);
  String _unit = 'un';
  bool _submitting = false;
  bool _pickingPhoto = false;
  String? _error;

  Uint8List? _photoBytes;
  String _photoName = '';
  String _photoContentType = 'image/jpeg';
  String _photoExtension = 'jpg';

  @override
  void dispose() {
    _nameController.dispose();
    _eanController.dispose();
    _priceController.dispose();
    _oldPriceController.dispose();
    super.dispose();
  }

  Future<void> _chooseMarket() async {
    if (_submitting) return;
    final result = await showMarketSelectionSheet(
      context,
      allowSkip: false,
    );
    if (!mounted || !result.isSelected || result.market == null) return;

    setState(() {
      _market = result.market;
      _error = null;
    });
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto || _submitting) return;
    FocusScope.of(context).unfocus();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.line,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: AppTheme.emeraldDark,
              ),
              title: const Text('Tirar foto'),
              subtitle: const Text('Fotografe a etiqueta ou o produto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppTheme.emeraldDark,
              ),
              title: const Text('Escolher da galeria'),
              subtitle: const Text('Use uma foto já salva no celular'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    setState(() {
      _pickingPhoto = true;
      _error = null;
    });

    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (file == null) return;

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
        _photoBytes = bytes;
        _photoName = file.name;
        _photoContentType = contentType;
        _photoExtension =
            extension == 'png' || extension == 'webp' ? extension : 'jpg';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == 'camera_access_denied'
            ? 'Permissão de câmera negada. Libere nas configurações do app ou use a galeria.'
            : 'Não foi possível abrir a câmera/galeria agora.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar a foto. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _removePhoto() {
    if (_submitting) return;
    setState(() {
      _photoBytes = null;
      _photoName = '';
    });
  }

  double? _parseMoney(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'[^\d,.]'), '');
    if (value.isEmpty) return null;

    final lastComma = value.lastIndexOf(',');
    final lastDot = value.lastIndexOf('.');
    if (lastComma > lastDot) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else {
      value = value.replaceAll(',', '');
      if (!value.contains('.')) value = '$value.00';
    }

    return double.tryParse(value);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final market = _market;
    if (market == null) {
      setState(() {
        _error = 'Escolha o mercado onde encontrou esta oferta.';
      });
      return;
    }

    final price = _parseMoney(_priceController.text);
    if (price == null || price <= 0) {
      setState(() {
        _error = 'Informe um preço válido, como 12,90.';
      });
      return;
    }

    final oldPrice = _oldPriceController.text.trim().isEmpty
        ? null
        : _parseMoney(_oldPriceController.text);
    if (oldPrice != null && oldPrice <= price) {
      setState(() {
        _error = 'O preço anterior precisa ser maior que o preço atual.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    final service = ref.read(communityServiceProvider);
    try {
      String? imageUrl;
      final bytes = _photoBytes;
      if (bytes != null) {
        imageUrl = await service.uploadOfferPhoto(
          bytes: bytes,
          contentType: _photoContentType,
          extension: _photoExtension,
        );
      }

      await service.createOffer(
        productName: _nameController.text.trim(),
        price: price,
        oldPrice: oldPrice,
        marketId: market.id,
        ean: _eanController.text.trim(),
        unit: _unit,
        imageUrl: imageUrl,
        contributorName: ref.read(userProfileProvider).name,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CommunityServiceException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível publicar a oferta. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final maxHeight = (media.size.height - keyboard) * 0.92;

    return PopScope(
      canPop: !_submitting,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.line,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Publicar oferta',
                            style: TextStyle(
                              fontSize: 22,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: AppTheme.ink,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ajude a vizinhança mostrando o preço que você encontrou.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          enabled: !_submitting,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Produto',
                            hintText: 'Ex.: Leite integral 1L',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 2) {
                              return 'Informe o nome do produto';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                enabled: !_submitting,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Preço atual',
                                  hintText: '12,90',
                                  prefixText: r'R$ ',
                                ),
                                validator: (value) {
                                  final parsed = _parseMoney(value ?? '');
                                  if (parsed == null || parsed <= 0) {
                                    return 'Preço inválido';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _oldPriceController,
                                enabled: !_submitting,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Preço anterior',
                                  hintText: 'Opcional',
                                  prefixText: r'R$ ',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _eanController,
                          enabled: !_submitting,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Código de barras (opcional)',
                            hintText: 'Ajuda a comparar com outros mercados',
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Unidade',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: ['un', 'kg', 'L', 'cx']
                              .map(
                                (unit) => ChoiceChip(
                                  label: Text(unit),
                                  selected: _unit == unit,
                                  onSelected: _submitting
                                      ? null
                                      : (_) => setState(() => _unit = unit),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 18),
                        _MarketChoiceTile(
                          market: _market,
                          enabled: !_submitting,
                          onTap: _chooseMarket,
                        ),
                        const SizedBox(height: 18),
                        _PhotoField(
                          bytes: _photoBytes,
                          fileName: _photoName,
                          picking: _pickingPhoto,
                          enabled: !_submitting,
                          onPick: _pickPhoto,
                          onRemove: _removePhoto,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.amberTint,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.amber.withValues(alpha: 0.24),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFB26B00),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.publish_rounded, size: 20),
                            label: Text(
                              _submitting
                                  ? (_photoBytes != null
                                      ? 'Enviando foto e publicando...'
                                      : 'Publicando oferta...')
                                  : 'Publicar oferta',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'A oferta fica visível por 72 horas e pode ser confirmada por outros vizinhos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.35,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketChoiceTile extends StatelessWidget {
  final Mercado? market;
  final bool enabled;
  final VoidCallback onTap;

  const _MarketChoiceTile({
    required this.market,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = market;

    return Semantics(
      button: true,
      label: selected == null
          ? 'Selecionar mercado da oferta'
          : 'Mercado ${selected.nome}. Trocar mercado.',
      child: Material(
        color: selected == null ? AppTheme.amberTint : AppTheme.emeraldTint,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected == null
                    ? AppTheme.amber.withValues(alpha: 0.3)
                    : AppTheme.emerald.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected == null
                      ? Icons.add_business_rounded
                      : Icons.storefront_rounded,
                  color: selected == null
                      ? const Color(0xFFB26B00)
                      : AppTheme.emeraldDark,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected?.nome ?? 'Escolher mercado',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected == null
                            ? 'Obrigatório para vincular a oferta'
                            : [
                                if (selected.localLabel != null)
                                  selected.localLabel!,
                                if (selected.distanciaLabel != null)
                                  selected.distanciaLabel!,
                              ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  final Uint8List? bytes;
  final String fileName;
  final bool picking;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoField({
    required this.bytes,
    required this.fileName,
    required this.picking,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final image = bytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Foto da oferta',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
            ),
            Text(
              image == null ? 'Opcional' : 'Pronta para enviar',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: image == null ? AppTheme.muted : AppTheme.emeraldDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (image == null)
          Material(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: enabled && !picking ? onPick : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Column(
                  children: [
                    if (picking)
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      const Icon(
                        Icons.add_a_photo_rounded,
                        color: AppTheme.emerald,
                        size: 28,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      picking
                          ? 'Abrindo câmera...'
                          : 'Fotografar ou escolher da galeria',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Uma foto da etiqueta ajuda a validar o preço.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: AppTheme.background,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fileName.isEmpty ? 'Foto selecionada' : fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.muted,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: enabled ? onPick : null,
                        child: const Text('Trocar'),
                      ),
                      IconButton(
                        tooltip: 'Remover foto',
                        onPressed: enabled ? onRemove : null,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
