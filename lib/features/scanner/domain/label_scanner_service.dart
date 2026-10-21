import 'package:camera/camera.dart';

import '../../../core/models/cart_item.dart';
import '../../../core/models/partial_scan_data.dart';
import '../../../core/utils/text_normalizer.dart';
import 'usecases/process_frame_use_case.dart';

/// Result of one scan attempt.
enum LabelScanStatus {
  /// A frame is already in flight.
  busy,

  /// The minimum interval between processed frames has not elapsed.
  throttled,

  /// OCR ran but produced no trustworthy price or barcode.
  noCandidate,

  /// At least one useful field was read (EAN or price), but the item is not
  /// complete and needs a manual complement before being added to the cart.
  partialRead,

  /// A price was read but still needs a second consecutive confirmation.
  candidate,

  /// The same price/name was read twice in a row.
  confirmed,

  /// This exact item was confirmed moments ago (duplicate protection).
  cooldown,

  /// ML Kit or the image conversion failed.
  error,
}

class LabelScanOutcome {
  final LabelScanStatus status;
  final CartItem? item;
  final PartialScanData? partialData;
  final double? candidatePrice;
  final String message;
  final String? error;

  const LabelScanOutcome({
    required this.status,
    this.item,
    this.partialData,
    this.candidatePrice,
    this.message = 'Aproxime da etiqueta de preço',
    this.error,
  });

  bool get isConfirmed => status == LabelScanStatus.confirmed && item != null;

  bool get hasCandidate => status == LabelScanStatus.candidate;

  bool get hasPartialData =>
      status == LabelScanStatus.partialRead &&
      partialData != null &&
      !partialData!.isEmpty;

  static const busy = LabelScanOutcome(
    status: LabelScanStatus.busy,
    message: 'Lendo a etiqueta…',
  );

  static const throttled = LabelScanOutcome(
    status: LabelScanStatus.throttled,
    message: 'Aproxime da etiqueta de preço',
  );

  static const noCandidate = LabelScanOutcome(
    status: LabelScanStatus.noCandidate,
    message: 'Aproxime da etiqueta de preço',
  );

  static const cooldown = LabelScanOutcome(
    status: LabelScanStatus.cooldown,
    message: 'Item já adicionado. Aponte para outro produto.',
  );
}

/// Coordinates frame throttling, price confirmation (debounce) and duplicate
/// protection around [ProcessFrameUseCase].
///
/// The ML Kit call itself is asynchronous and runs in the platform layer; this
/// service guarantees only one frame is in flight and that the UI never sees a
/// price until it has been read identically in two consecutive frames.
class LabelScannerService {
  LabelScannerService(this._processFrameUseCase);

  /// Minimum time between two frame starts (1 frame per second).
  ///
  /// The screen also enforces this interval before handing a frame to the
  /// service; keeping it here protects any other caller.
  static const Duration minFrameInterval = Duration(milliseconds: 1000);

  /// If two equal readings are further apart than this, restart the count.
  static const Duration confirmationWindow = PriceConfirmationGate.window;

  /// Ignore the same product for a few seconds after it was added, so the
  /// scanner does not add it twice while the user lowers the phone.
  static const Duration duplicateCooldown = Duration(seconds: 4);

  /// Consecutive identical readings required before a price is accepted.
  static const int requiredMatches = PriceConfirmationGate.requiredMatches;

  final ProcessFrameUseCase _processFrameUseCase;
  final PriceConfirmationGate _gate = PriceConfirmationGate();
  final FrameThrottle _throttle = FrameThrottle(minFrameInterval);

  bool _isBusy = false;

  final Map<String, DateTime> _recentlyConfirmed = <String, DateTime>{};

  bool get isBusy => _isBusy;

  /// Processes a frame, respecting the throttle and confirmation rules.
  Future<LabelScanOutcome> scan(CameraImage image) async {
    if (_isBusy) return LabelScanOutcome.busy;

    final now = DateTime.now();
    if (!_throttle.tryAcquire(now)) {
      return LabelScanOutcome.throttled;
    }

    _isBusy = true;
    try {
      final result = await _processFrameUseCase.execute(image);

      if (result.skipped) {
        _resetConfirmation();
        return LabelScanOutcome.busy;
      }
      if (result.hasError) {
        _resetConfirmation();
        return LabelScanOutcome(
          status: LabelScanStatus.error,
          message: 'Não foi possível ler a etiqueta.',
          error: result.error,
        );
      }

      final item = result.cartItem;
      if (item == null) {
        final partial = result.partialData;
        if (partial != null && !partial.isEmpty) {
          _resetConfirmation();
          return LabelScanOutcome(
            status: LabelScanStatus.partialRead,
            partialData: partial,
            candidatePrice: partial.unitPrice,
            message: partial.hasEan && !partial.hasPrice
                ? 'Código lido. Complete o preço.'
                : 'Preço lido. Complete o nome.',
          );
        }

        _resetConfirmation();
        return LabelScanOutcome.noCandidate;
      }

      final key = PriceConfirmationGate.keyFor(item);
      _purgeCooldowns(now);

      if (_recentlyConfirmed.containsKey(key)) {
        _gate.reset();
        return LabelScanOutcome.cooldown;
      }

      final confirmed = _gate.register(item, now: now);
      if (confirmed) {
        _recentlyConfirmed[key] = now;
        return LabelScanOutcome(
          status: LabelScanStatus.confirmed,
          item: item,
          candidatePrice: item.unitPrice,
          message: 'Leitura confirmada',
        );
      }

      return LabelScanOutcome(
        status: LabelScanStatus.candidate,
        item: item,
        candidatePrice: item.unitPrice,
        message: 'Mantenha a etiqueta no quadro para confirmar',
      );
    } catch (e) {
      _resetConfirmation();
      return LabelScanOutcome(
        status: LabelScanStatus.error,
        message: 'Não foi possível ler a etiqueta.',
        error: e.toString(),
      );
    } finally {
      _isBusy = false;
    }
  }

  /// Clears the two-frame confirmation buffer (e.g. after pausing the camera).
  ///
  /// Recent-item cooldowns are intentionally kept so lowering the phone after
  /// adding an item does not immediately add the same product again.
  void reset() {
    _gate.reset();
  }

  /// Removes the duplicate cooldown when the user rejects a confirmation.
  void forget(CartItem item) {
    _recentlyConfirmed.remove(PriceConfirmationGate.keyFor(item));
  }

  void _resetConfirmation() {
    _gate.reset();
  }

  void _purgeCooldowns(DateTime now) {
    _recentlyConfirmed.removeWhere(
      (_, seenAt) => now.difference(seenAt) > duplicateCooldown,
    );
  }
}

/// Simple, testable time gate for camera frames.
class FrameThrottle {
  final Duration minInterval;
  DateTime? _lastAttemptAt;

  FrameThrottle(this.minInterval);

  /// Returns true and records [now] when a new frame may be processed.
  bool tryAcquire(DateTime now) {
    final last = _lastAttemptAt;
    if (last != null && now.difference(last) < minInterval) {
      return false;
    }
    _lastAttemptAt = now;
    return true;
  }
}

/// Requires the same product/price to be read in two consecutive frames.
///
/// The gate is intentionally independent from camera/ML Kit so it can be unit
/// tested. A different value, an empty frame or a gap longer than [window]
/// restarts the count.
class PriceConfirmationGate {
  static const int requiredMatches = 2;
  static const Duration window = Duration(seconds: 5);
  static const double _nameSimilarityThreshold = 0.6;

  double? _lastPrice;
  String? _lastName;
  String? _lastEan;
  int _matchCount = 0;
  DateTime? _lastSeenAt;

  bool register(CartItem item, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();

    final withinWindow =
        _lastSeenAt != null && timestamp.difference(_lastSeenAt!) <= window;

    final samePrice =
        _lastPrice != null && (item.unitPrice - _lastPrice!).abs() < 0.005;

    final sameEan =
        _lastEan != null && item.ean != null && _lastEan == item.ean;
    final eanConflict =
        _lastEan != null && item.ean != null && _lastEan != item.ean;

    final similarName = _lastName != null &&
        TextNormalizer.similarity(_lastName!, item.name) >=
            _nameSimilarityThreshold;

    // Same price + (same EAN or a very similar product name). OCR may drop a
    // word between frames, hence the similarity check instead of exact text.
    final sameReading =
        samePrice && withinWindow && !eanConflict && (sameEan || similarName);

    if (sameReading) {
      _matchCount++;
    } else {
      _matchCount = 1;
    }

    // The current reading is always the baseline for the next frame.
    _lastPrice = item.unitPrice;
    _lastName = item.name;
    _lastEan = item.ean;
    _lastSeenAt = timestamp;

    if (_matchCount >= requiredMatches) {
      reset();
      return true;
    }
    return false;
  }

  void reset() {
    _lastPrice = null;
    _lastName = null;
    _lastEan = null;
    _matchCount = 0;
    _lastSeenAt = null;
  }

  /// Stable key used for duplicate cooldown after an item was added.
  static String keyFor(CartItem item) {
    final normalizedName = TextNormalizer.normalize(item.name)
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    return '${item.ean ?? ''}|$normalizedName|'
        '${item.unitPrice.toStringAsFixed(2)}';
  }
}
