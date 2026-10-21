import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isStreaming = false;
  final int frameIntervalMs;

  CameraService({this.frameIntervalMs = 900});

  /// Initialize camera with back-facing camera
  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      throw Exception('No cameras available');
    }

    final backCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // Required for ML Kit
      fps: 15,
    );

    await _controller!.initialize();
    await _controller!.setFlashMode(FlashMode.off);
  }

  /// Start image stream for frame processing
  void startImageStream(Function(CameraImage) onFrame) {
    if (_controller == null || _isStreaming) return;

    _isStreaming = true;
    _controller!.startImageStream((image) {
      onFrame(image);
    });
  }

  /// Stop image stream
  void stopImageStream() {
    if (_controller == null || !_isStreaming) return;
    _controller!.stopImageStream();
    _isStreaming = false;
  }

  /// Toggle flashlight
  Future<void> toggleFlashlight() async {
    if (_controller == null) return;
    final currentMode = _controller!.value.flashMode;
    final newMode =
        currentMode == FlashMode.torch ? FlashMode.off : FlashMode.torch;
    await _controller!.setFlashMode(newMode);
  }

  /// Set flash mode
  Future<void> setFlashMode(FlashMode mode) async {
    if (_controller == null) return;
    await _controller!.setFlashMode(mode);
  }

  /// Get current flash mode
  FlashMode get flashMode => _controller?.value.flashMode ?? FlashMode.off;

  /// Get camera controller for preview widget
  CameraController? get controller => _controller;

  /// Check if camera is initialized
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Get camera preview size
  Size? get previewSize => _controller?.value.previewSize;

  /// Dispose resources
  void dispose() {
    stopImageStream();
    _controller?.dispose();
    _controller = null;
  }
}

/// Camera provider for Riverpod
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  ref.onDispose(() => service.dispose());
  return service;
});

final cameraControllerProvider = FutureProvider<CameraController>((ref) async {
  final service = ref.watch(cameraServiceProvider);
  await service.initialize();
  return service.controller!;
});
