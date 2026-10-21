import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists the shelf-label photo captured by the scanner.
///
/// The camera writes to a temporary cache file; this service compresses it
/// off the UI isolate and moves a JPEG copy into the app documents directory so
/// the proof survives while the purchase is open.
class LabelPhotoService {
  LabelPhotoService._();

  static Future<String?> persistFromFile(String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return null;

      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory(p.join(documents.path, 'etiquetas'));
      await directory.create(recursive: true);

      final bytes = await source.readAsBytes();
      final compressed = await Isolate.run(() => _compress(bytes));
      if (compressed == null) return null;

      final target = File(
        p.join(
          directory.path,
          'etiqueta_${DateTime.now().microsecondsSinceEpoch}.jpg',
        ),
      );
      await target.writeAsBytes(compressed, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cleanup is best-effort; a leftover proof photo never blocks checkout.
    }
  }
}

Uint8List? _compress(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final oriented = img.bakeOrientation(decoded);
  final resized =
      oriented.width > 1280 ? img.copyResize(oriented, width: 1280) : oriented;
  return img.encodeJpg(resized, quality: 82);
}
