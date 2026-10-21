import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/ml_kit_service.dart';
import '../../../core/services/price_validation_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/community_price.dart';
import '../../../core/models/purchase.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/somaai_logo.dart';
import '../../cart/presentation/providers/cart_provider.dart';
import '../../community_alerts/presentation/providers/alert_preferences_provider.dart';
import '../../community_alerts/presentation/widgets/price_alert_banner.dart';
import '../../home/presentation/providers/purchase_history_provider.dart';
import '../domain/label_scanner_service.dart';
import '../domain/usecases/process_frame_use_case.dart';
import 'widgets/camera_preview_widget.dart';
import 'widgets/bottom_sheet_cart.dart';
import 'widgets/scan_confirmation_sheet.dart';
import 'providers/scanner_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  MlKitService? _mlKitService;
  PriceValidationService? _priceValidationService;
  LocationService? _locationService;
  ProcessFrameUseCase? _processFrameUseCase;
  LabelScannerService? _labelScannerService;
  ValidatePriceUseCase? _validatePriceUseCase;

  /// 900 ms between finished frames: enough for ML Kit to keep up without
  /// heating the phone or draining the battery at 30 fps.
  static const Duration _frameInterval = Duration(milliseconds: 900);

  bool _isProcessing = false;
  bool _isStreaming = false;
  bool _scanPaused = false;
  bool _showCart = false;
  CommunityPriceAlert? _currentAlert;
  Timer? _frameTimer;
  String? _cameraError;

  /// Economia acumulada dos alertas vistos nesta compra.
  double _sessionSavings = 0;
  final Set<String> _alertedEans = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _mlKitService = MlKitService();
      _locationService = ref.read(locationServiceProvider);
      _priceValidationService = PriceValidationService(_locationService!);
      _processFrameUseCase = ProcessFrameUseCase(_mlKitService!);
      _labelScannerService = LabelScannerService(_processFrameUseCase!);
      _validatePriceUseCase = ValidatePriceUseCase(_priceValidationService!);
    } catch (e, stack) {
      debugPrint('[SomaAí] Falha ao inicializar serviços: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() => _cameraError =
            'Não foi possível iniciar os serviços de leitura.\n$e');
      }
      return;
    }

    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _frameTimer?.cancel();
    await _cameraController?.dispose();
    _cameraController = null;

    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) {
          setState(() => _cameraError =
              'Permissão de câmera negada.\nHabilite o acesso nas configurações do app.');
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() =>
              _cameraError = 'Nenhuma câmera disponível neste dispositivo.');
        }
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        // Medium is deliberate: OCR only needs readable text, and a smaller
        // frame keeps the YUV copy + ML Kit well within the frame budget.
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
        fps: 15,
      );

      await _cameraController!
          .initialize()
          .timeout(const Duration(seconds: 15));
      await _cameraController!.setFlashMode(FlashMode.off);

      // ~1 frame per second, processed one at a time.
      _frameTimer = Timer.periodic(_frameInterval, (_) {
        _processNextFrame();
      });

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = 'Falha ao iniciar a câmera:\n$e');
      }
    }
  }

  Future<void> _processNextFrame() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (_scanPaused || _isProcessing || _isStreaming) return;

    // Só inicia um novo stream quando o anterior já foi encerrado.
    _isStreaming = true;
    var receivedFrame = false;
    try {
      await controller.startImageStream((image) {
        receivedFrame = true;
        final active = _cameraController;
        if (active != null && _isStreaming) {
          _stopStreaming(active);
        }
        _processFrame(image);
      });

      // Defensive: some devices stop delivering frames after a while. Do not
      // leave the scanner stuck with _isStreaming = true forever.
      Future.delayed(const Duration(seconds: 2), () {
        if (!receivedFrame && _isStreaming && mounted) {
          _isStreaming = false;
          try {
            controller.stopImageStream();
          } catch (_) {
            // Stream may already be closed.
          }
        }
      });
    } catch (e) {
      _isStreaming = false;
      debugPrint('[SomaAí] Falha ao capturar frame: $e');
    }
  }

  Future<void> _stopStreaming(CameraController controller) async {
    try {
      await controller.stopImageStream();
    } catch (e) {
      debugPrint('[SomaAí] Falha ao parar stream: $e');
    } finally {
      _isStreaming = false;
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || _scanPaused) return;

    final notifier = ref.read(scannerProvider.notifier);
    _isProcessing = true;
    notifier.setProcessing(true);

    CartItem? confirmedItem;
    try {
      final outcome = await _labelScannerService!.scan(image);
      if (!mounted) return;
      confirmedItem = _applyScanOutcome(outcome);
    } finally {
      _isProcessing = false;
      if (mounted) notifier.setProcessing(false);
    }

    if (confirmedItem != null && mounted) {
      await _confirmScannedItem(confirmedItem);
    }
  }

  /// Updates the frame hint and returns an item only when the two-frame
  /// confirmation succeeded.
  CartItem? _applyScanOutcome(LabelScanOutcome outcome) {
    final notifier = ref.read(scannerProvider.notifier);

    switch (outcome.status) {
      case LabelScanStatus.confirmed:
        final item = outcome.item;
        if (item == null) return null;

        _pauseScanning();
        HapticFeedback.heavyImpact();
        notifier.triggerSuccessFlash(ean: item.ean);
        notifier.setFeedback(
          message: 'Leitura confirmada',
          candidatePrice: item.unitPrice,
        );
        return item;

      case LabelScanStatus.candidate:
        notifier.setFeedback(
          message: outcome.message,
          candidatePrice: outcome.candidatePrice,
        );
        return null;

      case LabelScanStatus.noCandidate:
      case LabelScanStatus.throttled:
      case LabelScanStatus.cooldown:
        notifier.setFeedback(
          message: outcome.message,
          clearCandidate: true,
        );
        return null;

      case LabelScanStatus.busy:
        return null;

      case LabelScanStatus.error:
        debugPrint('[SomaAí] Erro ao ler etiqueta: ${outcome.error}');
        notifier.setFeedback(
          message: outcome.message,
          clearCandidate: true,
        );
        return null;
    }
  }

  void _pauseScanning() {
    if (_scanPaused) return;
    _scanPaused = true;
    _frameTimer?.cancel();
    _frameTimer = null;
    _isStreaming = false;
    try {
      _cameraController?.stopImageStream();
    } catch (_) {
      // Stream may already be stopped.
    }
    ref.read(scannerProvider.notifier).setPaused(true);
  }

  void _resumeScanning() {
    if (!mounted) return;
    _scanPaused = false;
    _labelScannerService?.reset();
    ref.read(scannerProvider.notifier)
      ..setPaused(false)
      ..setFeedback(
        message: 'Aproxime da etiqueta de preço',
        clearCandidate: true,
      );

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (_frameTimer == null || !_frameTimer!.isActive) {
      _frameTimer = Timer.periodic(_frameInterval, (_) {
        _processNextFrame();
      });
    }
  }

  /// Pauses the camera and asks the user to confirm the value before it is
  /// added to the cart. This is the final anti-false-positive barrier.
  Future<void> _confirmScannedItem(CartItem item) async {
    final add = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ScanConfirmationSheet(
        item: item,
        onConfirm: () => Navigator.pop(ctx, true),
        onRetry: () => Navigator.pop(ctx, false),
      ),
    );

    if (!mounted) return;

    if (add == true) {
      ref.read(cartProvider.notifier).addItem(item);
      unawaited(_checkCommunityAlert(item));
    } else {
      // The user rejected the reading: allow the same label to be retried
      // immediately instead of waiting for the duplicate cooldown.
      _labelScannerService?.forget(item);
    }

    _resumeScanning();
  }

  Future<void> _checkCommunityAlert(CartItem item) async {
    final alertsEnabled = ref.read(alertPreferencesProvider).alertsEnabled;
    if (!alertsEnabled || item.ean == null) return;

    final alert = await _validatePriceUseCase?.execute(
      item: item,
      currentPrice: item.unitPrice,
    );

    if (alert != null && mounted) {
      if (item.ean != null && _alertedEans.add(item.ean!)) {
        _sessionSavings += alert.savings;
      }
      setState(() => _currentAlert = alert);
      // Auto-dismiss after 8 seconds.
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _currentAlert == alert) {
          setState(() => _currentAlert = null);
        }
      });
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _isStreaming = false;
    _labelScannerService?.reset();
    try {
      _cameraController?.stopImageStream();
    } catch (_) {
      // Controlador pode não ter sido inicializado.
    }
    _cameraController?.dispose();
    _mlKitService?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.paused:
        _frameTimer?.cancel();
        _isStreaming = false;
        try {
          _cameraController!.stopImageStream();
        } catch (_) {
          // Stream may already be stopped.
        }
      case AppLifecycleState.resumed:
        if (!_scanPaused && (_frameTimer == null || !_frameTimer!.isActive)) {
          _frameTimer = Timer.periodic(_frameInterval, (_) {
            _processNextFrame();
          });
        }
      default:
        break;
    }
  }

  void _retryCamera() {
    setState(() => _cameraError = null);
    if (_processFrameUseCase == null) {
      _initializeServices();
    } else {
      _initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return _buildCameraError(context);
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return _buildCameraLoading(context);
    }

    final cart = ref.watch(cartProvider);
    final total = cart.fold(0.0, (sum, item) => sum + item.totalPrice);
    final itemCount = cart.fold(0, (sum, item) => sum + item.quantity);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Câmera em tempo real.
          Positioned.fill(
            child: CameraPreviewWidget(controller: _cameraController!),
          ),

          // Guias de enquadramento.
          const ScanOverlayWidget(),

          // Barra superior em vidro escuro.
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                if (_currentAlert != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                    child: PriceAlertBanner(
                      alert: _currentAlert!,
                      onDismiss: () => setState(() => _currentAlert = null),
                      onNavigate: () => _navigateToStore(_currentAlert!),
                    ),
                  ),
              ],
            ),
          ),

          // Painel de saldo flutuante (glassmorphism claro).
          Positioned(
            left: 14,
            right: 14,
            bottom: bottomInset + 12,
            child: _buildBalancePanel(context, cart, total, itemCount),
          ),

          // Carrinho detalhado (sobrepõe o painel quando aberto).
          BottomSheetCart(
            isOpen: _showCart,
            onToggle: () => setState(() => _showCart = !_showCart),
            items: cart,
            total: total,
            onItemRemoved: (id) =>
                ref.read(cartProvider.notifier).removeItem(id),
            onItemQuantityChanged: (id, qty) =>
                ref.read(cartProvider.notifier).updateQuantity(id, qty),
            onClearCart: () => ref.read(cartProvider.notifier).clear(),
            onCheckout: _finishPurchase,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Câmera
  Widget _buildCameraLoading(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 6,
              left: 6,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.ink),
                tooltip: 'Voltar',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SomaAiLogo(size: 86),
                    const SizedBox(height: 22),
                    const Text(
                      'Preparando a câmera...',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Aponte para a etiqueta e veja o total somar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraError(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova compra'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: AppTheme.amberTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.videocam_off_rounded,
                    color: Color(0xFFB26B00),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Não conseguimos abrir a câmera',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _retryCamera,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Abrir configurações'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final alertsEnabled = ref.watch(alertPreferencesProvider).alertsEnabled;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          _GlassCircleButton(
            icon: Icons.close_rounded,
            tooltip: 'Fechar scanner',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SomaAiLogo(size: 22, showShadow: false),
                SizedBox(width: 7),
                SomaAiWordmark(fontSize: 16, color: Colors.white),
              ],
            ),
          ),
          const Spacer(),
          _GlassCircleButton(
            icon: alertsEnabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            tooltip: alertsEnabled ? 'Desativar alertas' : 'Ativar alertas',
            iconColor: alertsEnabled ? AppTheme.lime : Colors.white70,
            onTap: () => ref
                .read(alertPreferencesProvider.notifier)
                .toggleAlerts(!alertsEnabled),
          ),
          const SizedBox(width: 8),
          _GlassCircleButton(
            icon: Icons.flash_off_rounded,
            tooltip: 'Lanterna',
            onTap: _toggleFlashlight,
            iconBuilder: (context) {
              return ValueListenableBuilder<CameraValue>(
                valueListenable: _cameraController!,
                builder: (context, value, _) {
                  final on = value.flashMode == FlashMode.torch;
                  return Icon(
                    on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: on ? AppTheme.lime : Colors.white,
                    size: 22,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------ Painel de saldo (vidro)
  Widget _buildBalancePanel(
    BuildContext context,
    List<CartItem> cart,
    double total,
    int itemCount,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
            boxShadow: AppTheme.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SALDO TOTAL',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: AppTheme.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Formatters.currency(total),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              color: AppTheme.emeraldDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_basket_rounded,
                          size: 13,
                          color: AppTheme.emeraldDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.emeraldDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.mic_rounded,
                      label: 'Voz',
                      onTap: _openVoiceInput,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.keyboard_rounded,
                      label: 'Manual',
                      onTap: _openManualInput,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.shopping_cart_rounded,
                      label: 'Carrinho',
                      badge: itemCount,
                      onTap: () => setState(() => _showCart = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (cart.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Aponte a câmera para uma etiqueta para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _finishPurchase,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 21),
                    label: const Text('Finalizar compra'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Compras
  Future<void> _finishPurchase() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Adicione pelo menos um item antes de finalizar.'),
          ),
        );
      return;
    }

    if (_showCart) setState(() => _showCart = false);

    final storeName = await _askStoreName(cart);
    if (storeName == null || !mounted) return;

    final trimmed = storeName.trim().isEmpty ? 'Mercado' : storeName.trim();
    final purchase = Purchase(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      storeName: trimmed,
      date: DateTime.now(),
      savings: _sessionSavings,
      items: cart
          .map(
            (item) => PurchaseItem(
              name: item.name,
              unit: item.unit,
              unitPrice: item.unitPrice,
              quantity: item.quantity,
            ),
          )
          .toList(),
    );

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(purchaseHistoryProvider.notifier).addPurchase(purchase);
    ref.read(cartProvider.notifier).clear();

    if (!mounted) return;
    Navigator.of(context).maybePop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Compra em $trimmed salva! Total '
            '${Formatters.currency(purchase.total)}.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<String?> _askStoreName(List<CartItem> cart) async {
    final controller = TextEditingController(text: 'Supermercado');
    final total = cart.fold(0.0, (sum, item) => sum + item.totalPrice);
    final itemCount = cart.fold(0, (sum, item) => sum + item.quantity);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Finalizar compra'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_rounded,
                        color: AppTheme.emeraldDark,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total da compra',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppTheme.emeraldDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              Formatters.currency(total),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.emeraldDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.emeraldDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Onde você comprou?',
                    hintText: 'Ex.: Extra, Assaí, Carrefour...',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'Extra',
                    'Assaí',
                    'Carrefour',
                    'Pão de Açúcar',
                  ].map((store) {
                    return ActionChip(
                      label: Text(store),
                      onPressed: () => controller.text = store,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, controller.text),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Salvar compra'),
            ),
          ],
        );
      },
    );

    // Aguarda a animação de saída antes de libertar o controller.
    Future.delayed(const Duration(milliseconds: 400), controller.dispose);
    return result;
  }

  Future<void> _toggleFlashlight() async {
    if (_cameraController == null) return;
    final mode = _cameraController!.value.flashMode == FlashMode.torch
        ? FlashMode.off
        : FlashMode.torch;
    await _cameraController!.setFlashMode(mode);
  }

  void _openVoiceInput() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrada por voz - Em desenvolvimento')),
    );
  }

  Future<void> _openManualInput() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var quantity = 1;

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final keyboard = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: keyboard),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusXl),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppTheme.line,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Adicionar item',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Digite o produto e o preço da etiqueta.',
                          style:
                              TextStyle(fontSize: 12.5, color: AppTheme.muted),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Produto',
                            hintText: 'Ex.: Leite integral 1L',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
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
                                controller: priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Preço unitário',
                                  prefixText: r'R$ ',
                                  hintText: '0,00',
                                ),
                                validator: (value) {
                                  final price = _parsePrice(value ?? '');
                                  if (price == null || price <= 0) {
                                    return 'Preço inválido';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.line),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Diminuir quantidade',
                                    onPressed: quantity > 1
                                        ? () => setSheetState(() => quantity--)
                                        : null,
                                    icon: const Icon(Icons.remove_rounded,
                                        size: 19),
                                  ),
                                  Text(
                                    '$quantity',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Aumentar quantidade',
                                    onPressed: quantity < 99
                                        ? () => setSheetState(() => quantity++)
                                        : null,
                                    icon:
                                        const Icon(Icons.add_rounded, size: 19),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                return;
                              }
                              final price = _parsePrice(priceController.text);
                              if (price == null || price <= 0) return;

                              final item = CartItem(
                                id: DateTime.now()
                                    .microsecondsSinceEpoch
                                    .toString(),
                                name: nameController.text.trim(),
                                unitPrice: price,
                                quantity: quantity,
                                unit: 'un',
                                totalPrice: price * quantity,
                                addedAt: DateTime.now(),
                                source: ScanSource.manual,
                              );
                              ref.read(cartProvider.notifier).addItem(item);
                              Navigator.pop(ctx, true);
                            },
                            icon: const Icon(Icons.add_shopping_cart_rounded,
                                size: 20),
                            label: const Text('Adicionar ao carrinho'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (added == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Item adicionado ao carrinho.')),
        );
    }

    // Só liberta os controllers depois de a folha fechar (e da animação).
    Future.delayed(const Duration(milliseconds: 400), () {
      nameController.dispose();
      priceController.dispose();
    });
  }

  /// Aceita "12,90", "12.90", "1.234,56" ou "1234.56".
  double? _parsePrice(String raw) {
    var value = raw.replaceAll(RegExp(r'[^0-9,.]'), '');
    if (value.isEmpty) return null;
    if (value.contains(',')) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(value);
  }

  void _navigateToStore(CommunityPriceAlert alert) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Navegar para ${alert.storeName} - Em desenvolvimento')),
    );
  }
}

/// Botão circular de vidro escuro usado sobre a câmera.
class _GlassCircleButton extends StatelessWidget {
  final IconData? icon;
  final WidgetBuilder? iconBuilder;
  final String tooltip;
  final VoidCallback onTap;
  final Color iconColor;

  const _GlassCircleButton({
    this.icon,
    this.iconBuilder,
    required this.tooltip,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: iconBuilder != null
                    ? iconBuilder!(context)
                    : Icon(icon, color: iconColor, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ação rápida do painel de saldo: ícone grande + rótulo curto.
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 48,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.line),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 23, color: AppTheme.emeraldDark),
                  if (badge != null && badge! > 0)
                    Positioned(
                      top: 6,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
