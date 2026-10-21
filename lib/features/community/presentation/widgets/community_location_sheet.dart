import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/market_service.dart';
import '../providers/community_filter_provider.dart';

Future<CommunityFilter?> showCommunityLocationSheet(
  BuildContext context, {
  required CommunityFilter current,
}) {
  return showModalBottomSheet<CommunityFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommunityLocationSheet(current: current),
  );
}

class CommunityLocationSheet extends ConsumerStatefulWidget {
  final CommunityFilter current;

  const CommunityLocationSheet({super.key, required this.current});

  @override
  ConsumerState<CommunityLocationSheet> createState() =>
      _CommunityLocationSheetState();
}

class _CommunityLocationSheetState
    extends ConsumerState<CommunityLocationSheet> {
  static const _radii = [5.0, 10.0, 20.0];

  late final TextEditingController _cityController =
      TextEditingController(text: widget.current.city ?? '');
  late double _radius = widget.current.radiusKm;

  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });

    final result = await ref.read(marketServiceProvider).resolveLocation(
          forceRefresh: true,
        );
    if (!mounted) return;

    if (result.hasCoordinates) {
      final coordinates = result.coordinates!;
      Navigator.of(context).pop(
        widget.current.nearby(
          latitude: coordinates.latitude,
          longitude: coordinates.longitude,
          radiusKm: _radius,
        ),
      );
      return;
    }

    setState(() {
      _working = false;
      _error = _messageFor(result.status);
    });
  }

  void _useCity() {
    final city = _cityController.text.trim();
    if (city.length < 2) {
      setState(() {
        _error = 'Informe uma cidade ou bairro com pelo menos 2 letras.';
      });
      return;
    }

    Navigator.of(context).pop(
      widget.current.byCity(city, radiusKm: _radius),
    );
  }

  String _messageFor(LocationAccessStatus status) {
    switch (status) {
      case LocationAccessStatus.serviceDisabled:
        return 'O GPS está desligado. Ative a localização ou escolha uma cidade.';
      case LocationAccessStatus.permissionDenied:
      case LocationAccessStatus.permissionPermanentlyDenied:
        return 'Sem permissão de localização. Escolha uma cidade abaixo.';
      case LocationAccessStatus.timeout:
        return 'O GPS demorou para responder. Tente de novo ou escolha uma cidade.';
      case LocationAccessStatus.error:
      case LocationAccessStatus.success:
        return 'Não foi possível obter sua localização. Escolha uma cidade.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final maxHeight = (media.size.height - keyboard) * 0.9;

    return Padding(
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
                          'Ofertas perto de você',
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
                          'Use o GPS ou escolha uma cidade para ver preços de outra região.',
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
                    onPressed: _working
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Raio da busca',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _radii
                          .map(
                            (value) => ChoiceChip(
                              label: Text('${value.toStringAsFixed(0)} km'),
                              selected: _radius == value,
                              onSelected: _working
                                  ? null
                                  : (_) => setState(() => _radius = value),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _working ? null : _useLocation,
                        icon: _working
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 20),
                        label: Text(
                          _working
                              ? 'Obtendo localização...'
                              : 'Usar minha localização',
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
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
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'ou',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.muted.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Buscar em outra cidade',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cityController,
                      enabled: !_working,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _useCity(),
                      decoration: const InputDecoration(
                        hintText: 'Ex.: Campinas ou Centro, São Paulo',
                        prefixIcon: Icon(Icons.location_city_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _useCity,
                        icon: const Icon(Icons.search_rounded, size: 19),
                        label: const Text('Ver ofertas desta região'),
                      ),
                    ),
                    if (widget.current.hasCoordinates) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Sua localização atual continua sendo usada para calcular a distância até as ofertas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.35,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
