import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Deterministic icon derivatives of the approved artwork; no generated builds.
void main() {
  final source = img.decodePng(
    File('assets/images/tui_khon_logo_v1.png').readAsBytesSync(),
  )!;
  var left = source.width, top = source.height, right = 0, bottom = 0;
  for (final pixel in source) {
    if (pixel.a > 16) {
      left = math.min(left, pixel.x);
      top = math.min(top, pixel.y);
      right = math.max(right, pixel.x);
      bottom = math.max(bottom, pixel.y);
    }
  }
  final cropped = img.copyCrop(
    source,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
  Directory('assets/launcher').createSync(recursive: true);
  for (final foreground in [false, true]) {
    final size = foreground ? 600 : 820;
    final ratio = size / math.max(cropped.width, cropped.height);
    final logo = img.copyResize(
      cropped,
      width: (cropped.width * ratio).round(),
      height: (cropped.height * ratio).round(),
    );
    final canvas = img.Image(width: 1024, height: 1024, numChannels: 4);
    img.fill(
      canvas,
      color: foreground
          ? img.ColorRgba8(0, 0, 0, 0)
          : img.ColorRgba8(244, 251, 246, 255),
    );
    img.compositeImage(
      canvas,
      logo,
      dstX: (1024 - logo.width) ~/ 2,
      dstY: (1024 - logo.height) ~/ 2,
    );
    File('assets/launcher/${foreground ? 'foreground' : 'icon'}.png')
        .writeAsBytesSync(img.encodePng(canvas));
  }
}
