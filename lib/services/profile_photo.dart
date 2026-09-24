import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'account_service.dart';

/// Store a thumbnail with local settings, not a link to a movable source file.
Future<String> prepareProfilePhoto(Uint8List bytes) async {
  if (bytes.length > 5 * 1024 * 1024) {
    throw const AccountException('Choose a photo smaller than 5 MB.');
  }
  final codec = await ui.instantiateImageCodec(bytes,
      targetWidth: 256, allowUpscaling: false);
  try {
    final frame = await codec.getNextFrame();
    try {
      final source = frame.image;
      final side = source.width < source.height
          ? source.width.toDouble()
          : source.height.toDouble();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
          source,
          ui.Rect.fromLTWH((source.width - side) / 2,
              (source.height - side) / 2, side, side),
          const ui.Rect.fromLTWH(0, 0, 256, 256),
          ui.Paint()..filterQuality = ui.FilterQuality.medium);
      final picture = recorder.endRecording();
      final thumbnail = await picture.toImage(256, 256);
      try {
        final png = await thumbnail.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) {
          throw const AccountException('Could not read that photo.');
        }
        return base64Encode(png.buffer.asUint8List());
      } finally {
        thumbnail.dispose();
        picture.dispose();
      }
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
