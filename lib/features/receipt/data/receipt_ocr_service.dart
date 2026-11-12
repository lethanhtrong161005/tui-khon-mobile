import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class ReceiptOcrLine {
  const ReceiptOcrLine(
    this.text, {
    this.bounds = Rect.zero,
    this.confidence,
    this.angle = 0,
  });
  final String text;
  final Rect bounds;
  final double? confidence;
  final double angle;
}

class ReceiptOcrResult {
  const ReceiptOcrResult(this.lines);
  final List<ReceiptOcrLine> lines;
  String get text => lines.map((l) => l.text).join('\n');
}

abstract class ReceiptOcrService {
  Future<ReceiptOcrResult> recognize(Uint8List bytes);
}

/// The Latin model is bundled with the native SDK, including Vietnamese.
/// The temporary file is private, uniquely named and removed after recognition.
class NativeReceiptOcrService implements ReceiptOcrService {
  @override
  Future<ReceiptOcrResult> recognize(Uint8List bytes) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('Native OCR requires Android or iOS');
    }
    final directory = await Directory(
      '${(await getTemporaryDirectory()).path}/receipt_ocr',
    ).create(recursive: true);
    final temp = await directory.createTemp('scan-');
    final file = File('${temp.path}/image.jpg');
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      await file.writeAsBytes(bytes, flush: true);
      final result = await recognizer.processImage(InputImage.fromFile(file));
      return ReceiptOcrResult([
        for (final block in result.blocks)
          for (final line in block.lines)
            ReceiptOcrLine(
              line.text,
              bounds: line.boundingBox,
              confidence: line.confidence,
              angle: line.cornerPoints.length < 2
                  ? 0
                  : math.atan2(
                      line.cornerPoints[1].y - line.cornerPoints[0].y,
                      line.cornerPoints[1].x - line.cornerPoints[0].x,
                    ),
            ),
      ]);
    } finally {
      await recognizer.close();
      if (await file.exists()) await file.delete();
      await temp.delete();
    }
  }
}

final receiptOcrServiceProvider = Provider<ReceiptOcrService>(
  (ref) => NativeReceiptOcrService(),
);
