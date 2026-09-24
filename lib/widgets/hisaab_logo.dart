import 'package:flutter/material.dart';

/// The same vector mark is used in the UI and to generate the Windows icon.
class HisaabLogo extends StatelessWidget {
  final double size;
  const HisaabLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'HISAAB logo',
        image: true,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: HisaabLogoPainter()),
        ),
      );
}

class HisaabLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    const bounds = Rect.fromLTWH(0, 0, 100, 100);
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF5B36C8), Color(0xFF31246F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds);
    canvas.drawRRect(
        RRect.fromRectAndRadius(bounds, const Radius.circular(23)), background);

    // Subtle inset rim gives the tile definition on both dark and light surfaces.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 2, 96, 96), const Radius.circular(21)),
        Paint()
          ..color = const Color(0x28FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    final ivory = Paint()..color = const Color(0xFFFFFCF5);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(24, 22, 13, 56), const Radius.circular(4)),
        ivory);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(63, 22, 13, 56), const Radius.circular(4)),
        ivory);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(33, 44, 34, 12), const Radius.circular(3)),
        Paint()..color = const Color(0xFFFFD166));

    // A small gold ledger tab is visible at larger sizes without cluttering 16px.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(45, 66, 10, 5), const Radius.circular(2.5)),
        Paint()..color = const Color(0xFFFFD166));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HisaabLogoPainter oldDelegate) => false;
}
