import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:camera/camera.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/scanner_provider.dart';

/// Camera preview widget with proper aspect ratio
class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return CameraPreview(controller);
  }
}

/// Scan overlay with animated corners and scan line
class ScanOverlayWidget extends ConsumerWidget {
  const ScanOverlayWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scannerProvider);
    final flash = state.showSuccessFlash;
    final isProcessing = state.isProcessing && !state.isPaused;
    final candidate = state.candidatePrice;
    final message = candidate == null
        ? state.hintMessage
        : '${Formatters.currency(candidate)} • ${state.hintMessage}';

    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        height: 120,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main overlay frame
            CustomPaint(
              painter: _ScanOverlayPainter(
                flash: flash,
                isProcessing: isProcessing,
                hasCandidate: candidate != null,
              ),
              size: Size.infinite,
            ),
            // Discrete guide/status text under the frame.
            Positioned(
              bottom: -46,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: candidate != null
                          ? const Color(0xFFFFB84D).withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: candidate != null
                          ? const Color(0xFFFFD699)
                          : Colors.white.withValues(alpha: 0.92),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Flash indicator
            if (flash)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.greenAccent, width: 4),
                  ),
                ).animate().fadeOut(duration: 300.ms, delay: 100.ms),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  final bool flash;
  final bool isProcessing;
  final bool hasCandidate;

  _ScanOverlayPainter({
    required this.flash,
    required this.isProcessing,
    required this.hasCandidate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Outer glow when flash
    if (flash) {
      canvas.drawRRect(
        rrect.inflate(4),
        Paint()
          ..color = Colors.greenAccent.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );
    }

    final frameColor = flash
        ? Colors.greenAccent
        : hasCandidate
            ? const Color(0xFFFFB84D)
            : Colors.white;

    // Main frame
    final framePaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rrect, framePaint);

    // Corner brackets
    const cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = frameColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final corners = [
      const (Offset(0, 0), Offset(cornerLength, 0), Offset(0, cornerLength)),
      (
        Offset(size.width, 0),
        Offset(size.width - cornerLength, 0),
        Offset(size.width, cornerLength),
      ),
      (
        Offset(0, size.height),
        Offset(cornerLength, size.height),
        Offset(0, size.height - cornerLength),
      ),
      (
        Offset(size.width, size.height),
        Offset(size.width - cornerLength, size.height),
        Offset(size.width, size.height - cornerLength),
      ),
    ];

    for (final (corner, h, v) in corners) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy)
          ..lineTo(h.dx, h.dy)
          ..moveTo(corner.dx, corner.dy)
          ..lineTo(v.dx, v.dy),
        cornerPaint,
      );
    }

    // Scanning line animation
    if (isProcessing) {
      final linePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.greenAccent.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 2))
        ..strokeWidth = 2;

      // Animate line position based on time
      final progress = (DateTime.now().millisecondsSinceEpoch % 2000) / 2000;
      final y = size.height * 0.1 + (size.height * 0.8) * progress;
      canvas.drawLine(
        Offset(size.width * 0.1, y),
        Offset(size.width * 0.9, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _ScanOverlayPainter &&
        (oldDelegate.flash != flash ||
            oldDelegate.isProcessing != isProcessing ||
            oldDelegate.hasCandidate != hasCandidate);
  }
}
