import 'package:camera/camera.dart';
import '../../../../core/services/ml_kit_service.dart';
import '../../../../core/services/price_validation_service.dart';
import '../../../../core/models/cart_item.dart';
import '../../../../core/models/community_price.dart';
import '../../../../core/models/partial_scan_data.dart';

/// Use case for processing camera frames
class ProcessFrameUseCase {
  final MlKitService _mlKitService;
  bool _isProcessing = false;

  ProcessFrameUseCase(this._mlKitService);

  /// Processes a single camera frame
  Future<FrameProcessingResult> execute(CameraImage image) async {
    if (_isProcessing) {
      return FrameProcessingResult(skipped: true);
    }

    _isProcessing = true;
    try {
      final scanResult = await _mlKitService.processFrame(image);
      final cartItem = _mlKitService.extractCartItem(scanResult);

      if (cartItem != null) {
        return FrameProcessingResult(
          cartItem: cartItem,
          scanResult: scanResult,
        );
      }

      final partialData = _mlKitService.extractPartialData(scanResult);
      return FrameProcessingResult(
        scanResult: scanResult,
        partialData: partialData,
      );
    } catch (e) {
      return FrameProcessingResult(error: e.toString());
    } finally {
      _isProcessing = false;
    }
  }
}

/// Result of frame processing
class FrameProcessingResult {
  final bool skipped;
  final CartItem? cartItem;
  final PartialScanData? partialData;
  final ScanResult? scanResult;
  final String? error;

  FrameProcessingResult({
    this.skipped = false,
    this.cartItem,
    this.partialData,
    this.scanResult,
    this.error,
  });

  bool get hasItem => cartItem != null;
  bool get hasPartialData => partialData != null && !partialData!.isEmpty;
  bool get hasError => error != null;
}

/// Use case for validating price against community
class ValidatePriceUseCase {
  final PriceValidationService _priceValidationService;

  ValidatePriceUseCase(this._priceValidationService);

  /// Checks if there's a better price in the community
  Future<CommunityPriceAlert?> execute({
    required CartItem item,
    required double currentPrice,
  }) async {
    return _priceValidationService.checkBetterPrice(
      item: item,
      currentPrice: currentPrice,
    );
  }
}

/// Use case for submitting community price
class SubmitCommunityPriceUseCase {
  final PriceValidationService _priceValidationService;

  SubmitCommunityPriceUseCase(this._priceValidationService);

  Future<bool> execute({
    required CartItem item,
    required String storeId,
    required double price,
    double? quantity,
    String? unit,
    bool isPromo = false,
    DateTime? promoEndsAt,
    String? receiptPhotoPath,
  }) async {
    return _priceValidationService.submitCommunityPrice(
      item: item,
      storeId: storeId,
      price: price,
      quantity: quantity,
      unit: unit,
      isPromo: isPromo,
      promoEndsAt: promoEndsAt,
      receiptPhotoPath: receiptPhotoPath,
    );
  }
}
