import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/models/cart_item.dart';
import '../../../core/models/partial_scan_data.dart';
import '../../../core/services/label_photo_service.dart';
import '../../../core/services/ml_kit_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/somaai_logo.dart';
import '../domain/label_scanner_service.dart';
import '../domain/usecases/process_frame_use_case.dart';
import 'providers/scanner_provider.dart';
import 'widgets/camera_preview_widget.dart';
import 'widgets/partial_scan_sheet.dart';
import 'widgets/scan_confirmation_sheet.dart';

/// Câmera de leitura de etiquetas, aberta sob demanda pelo carrinho.
///
/// Regras de performance:
/// - [ResolutionPreset.medium] é suficiente para OCR e reduz o buffer YUV;
/// - no máximo 1 frame por segundo é enviado ao ML Kit;
/// - um frame novo é descartado enquanto `_isProcessing` for `true`;
/// - ao confirmar um item, voltar ou sair, o stream e o controller são
///   liberados imediatamente.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  MlKitService? _mlKitService;
  LabelScannerService? _labelScannerService;

  static const Duration _minFrameInterval = Duration(milliseconds: 1000);

  bool _isProcessing = false;
  bool _streamActive = false;
  bool _scanPaused = false;
  bool _closing = false;
  DateTime? _lastProcessedAt;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    ref.read(scannerProvider.notifier).reset();

    try {
      _mlKitService = MlKitService();
      final processFrameUseCase = ProcessFrameUseCase(_mlKitService!);
      _labelScannerService = LabelScannerService(processFrameUseCase);
    } catch (error, stack) {
      debugPrint('[SomaAí] Falha ao inicializar serviços: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(
          () => _cameraError =
              'Não foi possível iniciar os serviços de leitura.\n$error',
        );
      }
      return;
    }

    if (mounted) await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_closing) return;

    _releaseCamera();
    if (mounted) setState(() => _cameraError = null);

    CameraController? controller;
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) {
          setState(
            () => _cameraError =
                'Permissão de câmera negada.\nHabilite o acesso nas configurações do app.',
          );
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(
            () => _cameraError = 'Nenhuma câmera disponível neste dispositivo.',
          );
        }
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        backCamera,
        // Medium is deliberate: OCR only needs readable text and a smaller
        // buffer keeps the YUV copy + ML Kit within the frame budget.
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
        fps: 15,
      );

      await controller.initialize().timeout(const Duration(seconds: 15));
      await controller.setFlashMode(FlashMode.off);

      if (!mounted || _closing) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      controller = null; // ownership transferred to the state
      setState(() {});

      // The stream stays open, but [_onCameraFrame] discards everything except
      // one frame per second. This avoids the cost of repeatedly starting and
      // stopping the native image stream.
      await _startImageStream();
    } catch (error) {
      await controller?.dispose();
      if (mounted) {
        setState(() => _cameraError = 'Falha ao iniciar a câmera:\n$error');
      }
    }
  }

  Future<void> _startImageStream() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _streamActive ||
        _scanPaused ||
        _closing) {
      return;
    }

    _streamActive = true;
    try {
      await controller.startImageStream(_onCameraFrame);
    } catch (error) {
      _streamActive = false;
      debugPrint('[SomaAí] Falha ao abrir stream da câmera: $error');
    }
  }

  Future<void> _stopImageStream() async {
    _streamActive = false;
    final controller = _cameraController;
    if (controller == null) return;

    try {
      await controller.stopImageStream();
    } catch (error) {
      debugPrint('[SomaAí] Falha ao parar stream da câmera: $error');
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (!mounted || _closing || _scanPaused || _isProcessing) return;

    final now = DateTime.now();
    final last = _lastProcessedAt;
    if (last != null && now.difference(last) < _minFrameInterval) {
      return;
    }
    _lastProcessedAt = now;

    unawaited(_processFrame(image));
  }

  Future<void> _processFrame(CameraImage image) async {
    // Second barrier: the callback may already have been scheduled when a
    // previous ML Kit call is still in flight.
    if (_isProcessing || _scanPaused || _closing) return;

    final scanner = _labelScannerService;
    if (scanner == null) return;

    final notifier = ref.read(scannerProvider.notifier);
    _isProcessing = true;
    notifier.setProcessing(true);

    CartItem? confirmedItem;
    PartialScanData? partialData;
    try {
      final outcome = await scanner.scan(image);
      if (!mounted) return;
      confirmedItem = _applyScanOutcome(outcome);
      partialData = outcome.partialData;
    } catch (error, stack) {
      debugPrint('[SomaAí] Erro ao processar frame: $error');
      debugPrintStack(stackTrace: stack);
    } finally {
      _isProcessing = false;
      if (mounted) notifier.setProcessing(false);
    }

    if (partialData != null && mounted) {
      await _completePartialScan(partialData);
    } else if (confirmedItem != null && mounted) {
      final photoPath = await _captureLabelPhoto();
      if (!mounted) {
        await LabelPhotoService.delete(photoPath);
        return;
      }
      await _confirmScannedItem(
        photoPath == null
            ? confirmedItem
            : confirmedItem.copyWith(photoPath: photoPath),
      );
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

      case LabelScanStatus.partialRead:
        _pauseScanning();
        HapticFeedback.mediumImpact();
        notifier.setFeedback(
          message: outcome.message,
          candidatePrice: outcome.candidatePrice,
        );
        return null;

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
    _lastProcessedAt = null;
    ref.read(scannerProvider.notifier).setPaused(true);
    unawaited(_stopImageStream());
  }

  Future<void> _resumeScanning() async {
    if (!mounted || _closing) return;
    _scanPaused = false;
    _lastProcessedAt = null;
    _labelScannerService?.reset();
    ref.read(scannerProvider.notifier)
      ..setPaused(false)
      ..setFeedback(
        message: 'Aproxime da etiqueta de preço',
        clearCandidate: true,
      );

    // Make sure the previous stopImageStream() completed before starting a
    // new native stream. Some devices reject start/stop races.
    await _stopImageStream();
    if (!mounted || _closing || _scanPaused) return;
    await _startImageStream();
  }

  /// Takes a still photo of the label after a reading is confirmed.
  ///
  /// The image stream was already paused. Stopping it explicitly before
  /// `takePicture` avoids the Android camera races seen when both operations
  /// overlap. The photo is stored in the app documents directory; if anything
  /// fails the scan continues without a proof photo.
  Future<String?> _captureLabelPhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _closing) {
      return null;
    }

    try {
      await _stopImageStream();
      if (!mounted || _closing) return null;

      final shot =
          await controller.takePicture().timeout(const Duration(seconds: 5));
      final path = await LabelPhotoService.persistFromFile(shot.path);
      if (!mounted) {
        await LabelPhotoService.delete(path);
        return null;
      }
      return path;
    } catch (error) {
      debugPrint('[SomaAí] Foto da etiqueta indisponível: $error');
      return null;
    }
  }

  /// Opens the complement sheet when the camera read only EAN or price.
  ///
  /// The stream was already stopped by [_pauseScanning]. Confirming returns the
  /// completed item to the cart and closes the scanner; retrying resumes the
  /// camera without keeping a second controller alive.
  Future<void> _completePartialScan(PartialScanData data) async {
    final photoPath = await _captureLabelPhoto();
    if (!mounted) {
      await LabelPhotoService.delete(photoPath);
      return;
    }

    final item =
        await showPartialScanSheet(context, data, photoPath: photoPath);
    if (!mounted) return;

    if (item != null) {
      _releaseCamera();
      Navigator.of(context).pop(item);
      return;
    }

    await LabelPhotoService.delete(photoPath);
    _labelScannerService?.reset();
    await _resumeScanning();
  }

  /// Pauses the stream and asks the user to confirm the value before it is
  /// returned to the cart. Confirming closes the scanner immediately; retrying
  /// resumes the stream without leaving the camera open in the background.
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
      _releaseCamera();
      Navigator.of(context).pop(item);
      return;
    }

    // The user rejected the reading: remove the proof photo and allow the same
    // label to be retried immediately instead of waiting for the cooldown.
    await LabelPhotoService.delete(item.photoPath);
    _labelScannerService?.forget(item);
    unawaited(_resumeScanning());
  }

  /// Releases the native camera before navigating away.
  ///
  /// Stops the stream synchronously, then disposes the controller. Both calls
  /// are idempotent so `dispose()` can safely call this again.
  void _releaseCamera({bool notify = true}) {
    final controller = _cameraController;
    if (controller == null) return;

    // Remove the CameraPreview from the tree on the next frame *before* the
    // controller is disposed. Otherwise the popping route can rebuild the
    // preview with an already-disposed controller.
    if (notify && mounted) {
      setState(() => _cameraController = null);
    } else {
      _cameraController = null;
    }
    _streamActive = false;
    _lastProcessedAt = null;

    try {
      unawaited(controller.stopImageStream());
    } catch (_) {
      // Stream may already be stopped.
    }
    unawaited(controller.dispose());
  }

  void _closeScanner() {
    if (_closing) return;
    _closing = true;
    _releaseCamera();
    Navigator.of(context).maybePop();
  }

  Future<void> _toggleFlashlight() async {
    final controller = _cameraController;
    if (controller == null) return;
    final mode = controller.value.flashMode == FlashMode.torch
        ? FlashMode.off
        : FlashMode.torch;
    await controller.setFlashMode(mode);
  }

  @override
  void dispose() {
    _closing = true;
    _releaseCamera(notify: false);
    _labelScannerService?.reset();
    _mlKitService?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        unawaited(_stopImageStream());
      case AppLifecycleState.resumed:
        if (!_scanPaused) unawaited(_startImageStream());
      case AppLifecycleState.detached:
        _releaseCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return _buildCameraError(context);
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return _buildCameraLoading(context);
    }

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return PopScope<Object?>(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _releaseCamera();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: CameraPreviewWidget(controller: controller),
            ),
            const ScanOverlayWidget(),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(controller),
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset + 16),
                    child: _buildPerformanceHint(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                tooltip: 'Voltar ao carrinho',
                onPressed: _closeScanner,
              ),
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SomaAiLogo(size: 86),
                    SizedBox(height: 22),
                    Text(
                      'Preparando a câmera...',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Aponte para a etiqueta e veja o total somar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
                    ),
                    SizedBox(height: 24),
                    SizedBox(
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
        title: const Text('Ler etiqueta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar ao carrinho',
          onPressed: _closeScanner,
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

  void _retryCamera() {
    setState(() => _cameraError = null);
    if (_labelScannerService == null) {
      _bootstrap();
    } else {
      _initializeCamera();
    }
  }

  Widget _buildTopBar(CameraController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          _GlassCircleButton(
            icon: Icons.close_rounded,
            tooltip: 'Voltar ao carrinho',
            onTap: _closeScanner,
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
            icon: Icons.flash_off_rounded,
            tooltip: 'Lanterna',
            onTap: _toggleFlashlight,
            iconBuilder: (context) {
              return ValueListenableBuilder<CameraValue>(
                valueListenable: controller,
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

  Widget _buildPerformanceHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco_rounded, color: AppTheme.lime, size: 17),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Modo econômico: uma leitura por segundo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão circular de vidro escuro usado sobre a câmera.
class _GlassCircleButton extends StatelessWidget {
  final IconData? icon;
  final WidgetBuilder? iconBuilder;
  final String tooltip;
  final VoidCallback onTap;

  const _GlassCircleButton({
    this.icon,
    this.iconBuilder,
    required this.tooltip,
    required this.onTap,
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
                    : Icon(icon, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
