import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scanner state
class ScannerState {
  final bool showSuccessFlash;
  final String? lastScannedEan;
  final bool isProcessing;
  final bool isPaused;
  final String? errorMessage;
  final String hintMessage;
  final double? candidatePrice;

  const ScannerState({
    this.showSuccessFlash = false,
    this.lastScannedEan,
    this.isProcessing = false,
    this.isPaused = false,
    this.errorMessage,
    this.hintMessage = 'Aproxime da etiqueta de preço',
    this.candidatePrice,
  });

  ScannerState copyWith({
    bool? showSuccessFlash,
    String? lastScannedEan,
    bool? isProcessing,
    bool? isPaused,
    String? errorMessage,
    String? hintMessage,
    double? candidatePrice,
    bool clearCandidate = false,
    bool clearError = false,
  }) {
    return ScannerState(
      showSuccessFlash: showSuccessFlash ?? this.showSuccessFlash,
      lastScannedEan: lastScannedEan ?? this.lastScannedEan,
      isProcessing: isProcessing ?? this.isProcessing,
      isPaused: isPaused ?? this.isPaused,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hintMessage: hintMessage ?? this.hintMessage,
      candidatePrice:
          clearCandidate ? null : (candidatePrice ?? this.candidatePrice),
    );
  }
}

/// Scanner notifier
class ScannerNotifier extends StateNotifier<ScannerState> {
  ScannerNotifier() : super(const ScannerState());

  /// Triggers success flash animation
  void triggerSuccessFlash({String? ean}) {
    state = state.copyWith(
      showSuccessFlash: true,
      lastScannedEan: ean,
      clearCandidate: true,
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        state = state.copyWith(showSuccessFlash: false);
      }
    });
  }

  /// Sets processing state
  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  /// Updates the discrete hint shown under the scan frame.
  void setFeedback({
    required String message,
    double? candidatePrice,
    bool clearCandidate = false,
  }) {
    state = state.copyWith(
      hintMessage: message,
      candidatePrice: candidatePrice,
      clearCandidate: clearCandidate,
    );
  }

  /// Pauses/resumes the visual scanning state.
  void setPaused(bool paused) {
    state = state.copyWith(isPaused: paused);
  }

  /// Sets error message
  void setError(String? error) {
    state = state.copyWith(errorMessage: error);
  }

  /// Clears error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Resets the transient scanner UI state when the camera screen opens.
  void reset() {
    state = const ScannerState();
  }
}

/// Provider
final scannerProvider =
    StateNotifierProvider<ScannerNotifier, ScannerState>((ref) {
  return ScannerNotifier();
});
