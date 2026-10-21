import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../models/cart_item.dart';
import '../utils/price_parser.dart';
import '../utils/ean_validator.dart';

class MlKitService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upca,
      BarcodeFormat.upce,
    ],
  );

  /// Processes a camera frame: runs OCR and barcode detection in parallel.
  ///
  /// The YUV planes are merged in a background isolate so the UI isolate only
  /// pays for the (native, asynchronous) ML Kit call.
  Future<ScanResult> processFrame(CameraImage image) async {
    final inputImage = await _cameraImageToInputImage(image);

    final results = await Future.wait([
      _textRecognizer.processImage(inputImage),
      _barcodeScanner.processImage(inputImage),
    ]);

    final textResult = results[0] as RecognizedText;
    final barcodes = results[1] as List<Barcode>;

    return ScanResult(
      recognizedText: textResult,
      barcodes: barcodes,
      timestamp: DateTime.now(),
    );
  }

  /// Extracts structured cart item from OCR + barcode results
  CartItem? extractCartItem(ScanResult result, {String? photoPath}) {
    final ean = _extractBestEan(result.barcodes);
    final parsed = PriceParser.parseFromOcr(result.recognizedText.text);

    if (parsed == null) return null;

    return CartItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: parsed.name,
      brand: parsed.brand,
      ean: ean,
      unitPrice: parsed.unitPrice,
      quantity: parsed.quantity ?? 1,
      unit: parsed.unit ?? 'un',
      totalPrice: parsed.unitPrice * (parsed.quantity ?? 1),
      addedAt: DateTime.now(),
      source: ScanSource.camera,
      photoPath: photoPath,
      rawOcrData: {
        'full_text': result.recognizedText.text,
        'blocks': result.recognizedText.blocks.map((b) => b.text).toList(),
        'barcodes': result.barcodes.map((b) => b.rawValue).toList(),
      },
    );
  }

  Future<InputImage> _cameraImageToInputImage(CameraImage image) async {
    final planes = [for (final plane in image.planes) plane.bytes];
    final bytesList = planes.length == 1
        ? planes.first
        : await Isolate.run(() => _mergePlanes(planes));

    final InputImageMetadata metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytesList, metadata: metadata);
  }

  String? _extractBestEan(List<Barcode> barcodes) {
    for (final bc in barcodes) {
      final raw = bc.rawValue;
      if (raw != null && EanValidator.isValidEan(raw)) {
        return EanValidator.normalize(raw);
      }
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
    _barcodeScanner.close();
  }
}

class ScanResult {
  final RecognizedText recognizedText;
  final List<Barcode> barcodes;
  final DateTime timestamp;

  ScanResult({
    required this.recognizedText,
    required this.barcodes,
    required this.timestamp,
  });
}

/// Merges YUV planes into a single buffer. Kept top-level so the closure sent
/// to [Isolate.run] cannot accidentally capture the service instance.
Uint8List _mergePlanes(List<Uint8List> planes) {
  var totalLength = 0;
  for (final bytes in planes) {
    totalLength += bytes.length;
  }

  final merged = Uint8List(totalLength);
  var offset = 0;
  for (final bytes in planes) {
    merged.setRange(offset, offset + bytes.length, bytes);
    offset += bytes.length;
  }
  return merged;
}
