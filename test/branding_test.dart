import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_management/widgets/hisaab_logo.dart';

const iconSizes = [16, 24, 32, 48, 64, 128, 256];

Future<Uint8List> renderLogo(int size) async {
  final recorder = ui.PictureRecorder();
  HisaabLogoPainter().paint(ui.Canvas(recorder), Size.square(size.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

/// Regenerate from the same vector used in the app:
/// flutter test --dart-define=HISAAB_GENERATE_ICONS=true test/branding_test.dart
Future<void> generateIcons() async {
  final frames = <Uint8List>[];
  for (final size in iconSizes) {
    frames.add(await renderLogo(size));
  }
  final headerSize = 6 + 16 * frames.length;
  final header = ByteData(headerSize);
  header.setUint16(2, 1, Endian.little);
  header.setUint16(4, frames.length, Endian.little);
  var offset = headerSize;
  for (var i = 0; i < frames.length; i++) {
    final entry = 6 + i * 16;
    header.setUint8(entry, iconSizes[i] == 256 ? 0 : iconSizes[i]);
    header.setUint8(entry + 1, iconSizes[i] == 256 ? 0 : iconSizes[i]);
    header.setUint16(entry + 4, 1, Endian.little);
    header.setUint16(entry + 6, 32, Endian.little);
    header.setUint32(entry + 8, frames[i].length, Endian.little);
    header.setUint32(entry + 12, offset, Endian.little);
    offset += frames[i].length;
  }
  final ico = BytesBuilder()..add(header.buffer.asUint8List());
  for (final frame in frames) {
    ico.add(frame);
  }
  await File('windows/runner/resources/app_icon.ico')
      .writeAsBytes(ico.takeBytes());
  await Directory('assets/branding').create(recursive: true);
  await File('assets/branding/hisaab_icon.png')
      .writeAsBytes(await renderLogo(1024));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Windows logo includes valid icons at all required sizes', () async {
    if (const bool.fromEnvironment('HISAAB_GENERATE_ICONS')) {
      await generateIcons();
    }
    final bytes =
        await File('windows/runner/resources/app_icon.ico').readAsBytes();
    final header = ByteData.sublistView(bytes);
    expect(header.getUint16(0, Endian.little), 0);
    expect(header.getUint16(2, Endian.little), 1);
    expect(header.getUint16(4, Endian.little), iconSizes.length);
    for (var i = 0; i < iconSizes.length; i++) {
      final entry = 6 + 16 * i;
      final length = header.getUint32(entry + 8, Endian.little);
      final offset = header.getUint32(entry + 12, Endian.little);
      final codec = await ui.instantiateImageCodec(
          Uint8List.sublistView(bytes, offset, offset + length));
      final frame = await codec.getNextFrame();
      expect(frame.image.width, iconSizes[i]);
      expect(frame.image.height, iconSizes[i]);
      frame.image.dispose();
      codec.dispose();
    }
    expect(await File('windows/runner/Runner.rc').readAsString(),
        contains('app_icon.ico'));
  });
  testWidgets('in-app vector logo has a stable size and accessible label',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Center(child: HisaabLogo(size: 44))));
    expect(tester.getSize(find.byType(HisaabLogo)), const Size(44, 44));
    expect(find.bySemanticsLabel('HISAAB logo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
