import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'receipt_repository.dart';

Uint8List _normalize(Map<String, Object> input) {
  final decoded = img.decodeImage(input['bytes'] as Uint8List);
  if (decoded == null) throw const FormatException('Unsupported image');
  var image = img.bakeOrientation(decoded);
  final size = input['max'] as int;
  if (image.width > size || image.height > size) {
    image = image.width >= image.height
        ? img.copyResize(image, width: size)
        : img.copyResize(image, height: size);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

Future<PickedReceipt> normalizeReceiptImage(
  Uint8List bytes, {
  int maxSize = 3200,
}) async {
  Uint8List normalized;
  try {
    normalized = await compute(_normalize, {'bytes': bytes, 'max': maxSize});
  } on FormatException {
    // Native codecs handle formats such as HEIC that the Dart decoder cannot.
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) throw const FormatException('Unsupported image');
        normalized = await compute(_normalize, {
          'bytes': data.buffer.asUint8List(),
          'max': maxSize,
        });
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
  return PickedReceipt(
    bytes: normalized,
    mimeType: 'image/jpeg',
    extension: 'jpg',
  );
}
