import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/mercado.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/market_service.dart';
import '../providers/market_provider.dart';

/// Resultado explícito do fluxo de identificação do mercado.
///
/// `skipped` é diferente de fechar a folha: o utilizador decidiu continuar a
/// compra sem mercado. Nesse caso nenhum preço é publicado na comunidade.
enum MarketSelectionAction { selected, skipped, dismissed }

class MarketSelectionResult {
  final MarketSelectionAction action;
  final Mercado? market;

  const MarketSelectionResult._(this.action, this.market);

  const MarketSelectionResult.selected(Mercado market)
      : this._(MarketSelectionAction.selected, market);

  const MarketSelectionResult.skipped()
      : this._(MarketSelectionAction.skipped, null);

  const MarketSelectionResult.dismissed()
      : this._(MarketSelectionAction.dismissed, null);

  bool get isSelected => action == MarketSelectionAction.selected;
  bool get isSkipped => action == MarketSelectionAction.skipped;
}

/// Abre o fluxo "Onde você está comprando?".
///
/// Retorna [MarketSelectionResult.dismissed] quando o utilizador fecha a folha
/// sem decidir. Quando [allowSkip] é `false` (ex.: publicar uma oferta), a
/// opção de continuar sem mercado não é exibida.
Future<MarketSelectionResult> showMarketSelectionSheet(
  BuildContext context, {
  bool allowSkip = true,
}) async {
  final result = await showModalBottomSheet<MarketSelectionResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MarketSelectionSheet(allowSkip: allowSkip),
  );
  return result ?? const MarketSelectionResult.dismissed();
}

class MarketSelectionSheet extends ConsumerStatefulWidget {
  final bool allowSkip;

  const MarketSelectionSheet({super.key, this.allowSkip = true});

  @override
  ConsumerState<MarketSelectionSheet> createState() =>
      _MarketSelectionSheetState();
}

class _MarketSelectionSheetState extends ConsumerState<MarketSelectionSheet> {
  final _searchController = TextEditingController();
  final _manualFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _neighborhoodController = TextEditingController();

  late final MarketService _service = ref.read(marketServiceProvider);

  Timer? _searchDebounce;
  int _searchRequest = 0;

  bool _locating = true;
  bool _loadingNearby = false;
  bool _searching = false;
  bool _saving = false;
  bool _selecting = false;
  bool _manual = false;
  bool _exactRejected = false;

  LocationAccessResult? _locationResult;
  List<Mercado> _nearby = const [];
  List<Mercado> _searchResults = const [];
  Mercado? _exact;
  String? _nearbyError;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _detectLocation();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _neighborhoodController.dispose();
    super.dispose();
  }

  LocationCoordinates? get _coordinates => _locationResult?.coordinates;

  bool get _isSearching => _searchController.text.trim().length >= 2;

  Future<void> _detectLocation() async {
    if (!mounted) return;
    setState(() {
      _locating = true;
      _nearbyError = null;
      _exact = null;
      _exactRejected = false;
      _nearby = const [];
    });

    final result = await _service.resolveLocation(forceRefresh: true);
    if (!mounted) return;

    setState(() {
      _locationResult = result;
      _locating = false;
    });

    if (result.hasCoordinates) {
      await _loadExactMatch();
    }
  }

  Future<void> _loadExactMatch() async {
    final coordinates = _coordinates;
    if (coordinates == null) return;

    setState(() {
      _loadingNearby = true;
      _nearbyError = null;
    });

    try {
      // Passo 1: apenas base interna (PostGIS, 100 m).
      final markets = await _service.findNearby(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        radiusMeters: 100,
        limit: 5,
        includeExternal: false,
      );
      if (!mounted) return;

      final exact = markets.isEmpty ? null : markets.first;
      setState(() {
        _exact = exact;
        _loadingNearby = false;
      });

      if (exact == null) {
        await _loadFallbackMarkets();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingNearby = false;
        _nearbyError = _messageFor(error);
      });
    }
  }

  /// Passo 2: base interna (5 km) + fallback TomTom Places.
  Future<void> _loadFallbackMarkets() async {
    final coordinates = _coordinates;
    if (coordinates == null) return;

    setState(() {
      _loadingNearby = true;
      _nearbyError = null;
    });

    try {
      final markets = await _service.findNearby(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        radiusMeters: 5000,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _nearby = markets;
        _loadingNearby = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingNearby = false;
        _nearbyError = _messageFor(error);
      });
    }
  }

  void _rejectExactMatch() {
    setState(() => _exactRejected = true);
    if (_nearby.isEmpty && !_loadingNearby) {
      _loadFallbackMarkets();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();

    if (query.length < 2) {
      setState(() {
        _searching = false;
        _searchError = null;
        _searchResults = const [];
      });
      return;
    }

    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 380), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    final request = ++_searchRequest;
    if (!mounted) return;

    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      final results = await _service.searchByName(
        query,
        latitude: _coordinates?.latitude,
        longitude: _coordinates?.longitude,
      );
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _searching = false;
        _searchError = _messageFor(error);
        _searchResults = const [];
      });
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searching = false;
      _searchError = null;
      _searchResults = const [];
    });
  }

  Future<void> _selectMarket(Mercado market) async {
    if (_selecting) return;
    setState(() => _selecting = true);

    var selected = market;

    // Passo 3: mercado vindo da TomTom é salvo silenciosamente na base da
    // comunidade. Se a nuvem falhar, seguimos com o dado local.
    if (!market.isRemoto && (market.externalId?.isNotEmpty ?? false)) {
      final persisted = await _service.persistExternalMarket(market);
      selected = persisted.market;
    }

    if (!mounted) return;
    ref.read(selectedMarketProvider.notifier).select(selected);
    Navigator.of(context).pop(MarketSelectionResult.selected(selected));
  }

  void _skipMarket() {
    if (_selecting) return;
    _selecting = true;
    ref.read(selectedMarketProvider.notifier).clear();
    Navigator.of(context).pop(const MarketSelectionResult.skipped());
  }

  void _startManual() {
    FocusScope.of(context).unfocus();
    setState(() {
      _manual = true;
    });
  }

  void _cancelManual() {
    FocusScope.of(context).unfocus();
    setState(() {
      _manual = false;
    });
  }

  Future<void> _saveManualMarket() async {
    if (_saving) return;
    if (!(_manualFormKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    final coordinates = _coordinates;
    final city = _cityController.text.trim();
    final neighborhood = _neighborhoodController.text.trim();

    setState(() {
      _saving = true;
    });

    final result = await _service.createMarket(
      name: _nameController.text.trim(),
      latitude: coordinates?.latitude,
      longitude: coordinates?.longitude,
      city: city.isEmpty ? null : city,
      neighborhood: neighborhood.isEmpty ? null : neighborhood,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    _selectMarket(result.market);
  }

  Future<void> _openSettings({required bool locationSettings}) async {
    if (locationSettings) {
      await _service.openLocationSettings();
    } else {
      await _service.openAppSettings();
    }
  }

  String _messageFor(Object error) {
    if (error is MarketServiceException) return error.message;
    return 'Não foi possível concluir a busca agora. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final maxHeight = (media.size.height - keyboard) * 0.92;

    return PopScope(
      canPop: !_saving,
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
              _DragHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _manual
                                ? 'Cadastrar mercado'
                                : 'Onde você está comprando?',
                            style: const TextStyle(
                              fontSize: 22,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _manual
                                ? 'Seu cadastro ajuda outros usuários a encontrar preços por perto.'
                                : widget.allowSkip
                                    ? 'Identificamos o mercado para ligar os preços à comunidade. Você também pode seguir sem mercado.'
                                    : 'Identificamos o mercado antes de publicar o preço na comunidade.',
                            style: const TextStyle(
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
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: _manual ? _buildManualForm() : _buildSelectionBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_locating)
            const _LocatingCard()
          else ...[
            if (_locationResult != null && !_locationResult!.hasCoordinates)
              _buildLocationNotice(),
            if (_coordinates != null) ...[
              if (_exact != null && !_exactRejected)
                _ExactMarketCard(
                  market: _exact!,
                  onConfirm: () => _selectMarket(_exact!),
                  onReject: _rejectExactMatch,
                )
              else ...[
                _buildNearbySection(),
                if (_exactRejected) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _exactRejected = false);
                      },
                      icon: const Icon(Icons.storefront_rounded, size: 17),
                      label: const Text('Voltar ao mercado identificado'),
                    ),
                  ),
                ],
              ],
            ],
            const SizedBox(height: 16),
            _SearchField(
              controller: _searchController,
              enabled: !_locating,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
            if (_isSearching) ...[
              const SizedBox(height: 14),
              _buildSearchResults(),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _startManual,
                icon: const Icon(Icons.add_business_rounded, size: 20),
                label: const Text('Meu mercado não está na lista'),
              ),
            ),
            if (widget.allowSkip) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _skipMarket,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Continuar sem selecionar mercado'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.muted,
                    minimumSize: const Size(0, 46),
                  ),
                ),
              ),
              const Text(
                'Sem mercado, os itens ficam apenas no seu histórico e não '
                'alimentam o radar da comunidade.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  color: AppTheme.muted,
                ),
              ),
            ] else
              const Text(
                'A localização é necessária para vincular a oferta a um mercado.',
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
    );
  }

  Widget _buildLocationNotice() {
    final status = _locationResult!.status;
    late final String title;
    late final String message;
    late final IconData icon;
    VoidCallback? primaryAction;
    String? primaryLabel;
    VoidCallback? secondaryAction;
    String? secondaryLabel;

    switch (status) {
      case LocationAccessStatus.serviceDisabled:
        title = 'Localização desligada';
        message =
            'Ative o GPS para encontrarmos o mercado automaticamente. Você também pode buscar pelo nome ou cadastrar manualmente.';
        icon = Icons.location_off_rounded;
        primaryLabel = 'Ativar localização';
        primaryAction = () => _openSettings(locationSettings: true);
        secondaryLabel = 'Tentar novamente';
        secondaryAction = _detectLocation;
        break;
      case LocationAccessStatus.permissionPermanentlyDenied:
        title = 'Permissão bloqueada';
        message =
            'A permissão de localização está bloqueada. Libere nas configurações do app ou use a busca por nome.';
        icon = Icons.gpp_maybe_rounded;
        primaryLabel = 'Abrir configurações';
        primaryAction = () => _openSettings(locationSettings: false);
        secondaryLabel = 'Tentar novamente';
        secondaryAction = _detectLocation;
        break;
      case LocationAccessStatus.permissionDenied:
        title = 'Sem permissão de localização';
        message =
            'Não conseguimos acessar o GPS. Você pode permitir novamente, buscar pelo nome ou cadastrar o mercado.';
        icon = Icons.location_disabled_rounded;
        primaryLabel = 'Permitir localização';
        primaryAction = _detectLocation;
        break;
      case LocationAccessStatus.timeout:
        title = 'GPS demorou para responder';
        message =
            'Isso pode acontecer em locais fechados. Tente novamente ou busque o mercado pelo nome.';
        icon = Icons.gps_off_rounded;
        primaryLabel = 'Tentar novamente';
        primaryAction = _detectLocation;
        break;
      case LocationAccessStatus.error:
        title = 'Não encontramos sua localização';
        message =
            'Siga com a busca por nome ou cadastre seu mercado. Nenhuma compra fica bloqueada.';
        icon = Icons.explore_off_rounded;
        primaryLabel = 'Tentar novamente';
        primaryAction = _detectLocation;
        break;
      case LocationAccessStatus.success:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.amberTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFB26B00), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.tonalIcon(
                onPressed: primaryAction,
                icon: const Icon(Icons.settings_rounded, size: 17),
                label: Text(primaryLabel),
              ),
              if (secondaryAction != null)
                TextButton(
                  onPressed: secondaryAction,
                  child: Text(secondaryLabel!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNearbySection() {
    final temResultadosTomTom = _nearby.any(
      (market) => market.externalId?.isNotEmpty ?? false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mercados próximos',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
            ),
            Text(
              'até 5 km',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingNearby)
          const _LoadingNearbyCard()
        else if (_nearbyError != null)
          _NearbyErrorCard(
            message: _nearbyError!,
            onRetry: _loadFallbackMarkets,
          )
        else if (_nearby.isEmpty)
          const _EmptyNearbyCard()
        else ...[
          ..._nearby.map(
            (market) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _MarketTile(
                market: market,
                onTap: () => _selectMarket(market),
              ),
            ),
          ),
          if (temResultadosTomTom)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: Color(0xFF9A5B00),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Resultados marcados como TomTom vêm da TomTom Places e '
                      'são adicionados à comunidade ao selecionar.',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.3,
                        color: AppTheme.muted.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const _SearchingCard();
    }
    if (_searchError != null) {
      return _NearbyErrorCard(
        message: _searchError!,
        onRetry: () => _runSearch(_searchController.text.trim()),
      );
    }
    if (_searchResults.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.line),
        ),
        child: const Text(
          'Nenhum mercado encontrado. Cadastre o seu no botão abaixo.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppTheme.muted,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resultados da busca',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 8),
        ..._searchResults.map(
          (market) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _MarketTile(
              market: market,
              onTap: () => _selectMarket(market),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualForm() {
    final hasCoordinates = _coordinates != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _manualFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: _saving ? null : _cancelManual,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Voltar para a busca'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppTheme.emeraldDark,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Nome do mercado',
                hintText: 'Ex.: Mercado do Joaquim',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Informe o nome do mercado';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cityController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText:
                    hasCoordinates ? 'Cidade (opcional)' : 'Cidade ou bairro',
                hintText: 'Ex.: São Paulo',
              ),
              validator: (value) {
                if (!hasCoordinates &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Sem GPS, informe a cidade ou bairro';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _neighborhoodController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Bairro (opcional)',
                hintText: 'Ex.: Centro',
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    hasCoordinates ? AppTheme.emeraldTint : AppTheme.amberTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    hasCoordinates
                        ? Icons.my_location_rounded
                        : Icons.location_off_rounded,
                    size: 18,
                    color: hasCoordinates
                        ? AppTheme.emeraldDark
                        : const Color(0xFFB26B00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasCoordinates
                          ? 'Vamos usar a localização atual para colocar esse mercado no mapa.'
                          : 'Sem GPS, o cadastro fica salvo com a cidade/bairro. Você pode atualizar a localização depois.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveManualMarket,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.storefront_rounded, size: 20),
                label: Text(
                  _saving ? 'Salvando mercado...' : 'Salvar e começar compra',
                ),
              ),
            ),
            if (widget.allowSkip) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _saving ? null : _skipMarket,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.muted,
                    minimumSize: const Size(0, 46),
                  ),
                  child: const Text('Continuar sem selecionar mercado'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Componentes

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 12),
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.line,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _LocatingCard extends StatelessWidget {
  const _LocatingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.emeraldTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.emerald,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Identificando o local...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Buscando mercados num raio de 100 metros.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExactMarketCard extends StatelessWidget {
  final Mercado market;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  const _ExactMarketCard({
    required this.market,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      if (market.distanciaLabel != null) market.distanciaLabel!,
      if (market.localLabel != null) market.localLabel!,
    ].join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.ctaGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emerald.withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'IDENTIFICAMOS QUE VOCÊ ESTÁ NO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      market.nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        details,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.emeraldDark,
                minimumSize: const Size(0, 48),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text('Sim, é este mercado'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onReject,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.92),
              ),
              child: const Text('Não estou aqui'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketTile extends StatelessWidget {
  final Mercado market;
  final VoidCallback onTap;

  const _MarketTile({required this.market, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final details = [
      if (market.distanciaLabel != null) market.distanciaLabel!,
      if (market.localLabel != null) market.localLabel!,
      if (market.endereco != null && market.endereco!.trim().isNotEmpty)
        market.endereco!.trim(),
    ].join(' • ');

    return Semantics(
      button: true,
      label: 'Selecionar ${market.nome}${details.isEmpty ? '' : ', $details'}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldTint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppTheme.emeraldDark,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              market.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                          ),
                          if (market.verificado) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: AppTheme.emerald,
                            ),
                          ],
                          if (market.externalId?.isNotEmpty ?? false) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.amberTint,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'TomTom',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9A5B00),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          details,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.8,
                            height: 1.3,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.muted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Buscar mercado pelo nome',
        prefixIcon: const Icon(Icons.search_rounded, size: 21),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
      ),
    );
  }
}

class _LoadingNearbyCard extends StatelessWidget {
  const _LoadingNearbyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.line),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppTheme.emerald,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Carregando mercados próximos...',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchingCard extends StatelessWidget {
  const _SearchingCard();

  @override
  Widget build(BuildContext context) {
    return const _LoadingNearbyCard();
  }
}

class _NearbyErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NearbyErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.amberTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.amber.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _EmptyNearbyCard extends StatelessWidget {
  const _EmptyNearbyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.line),
      ),
      child: const Column(
        children: [
          Icon(Icons.store_mall_directory_outlined, color: AppTheme.muted),
          SizedBox(height: 8),
          Text(
            'Nenhum mercado cadastrado num raio de 5 km.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
