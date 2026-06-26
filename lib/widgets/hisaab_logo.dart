import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class HisaabLogo extends StatelessWidget {
  final double size;

  const HisaabLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _HisaabLogoPainter(),
        child: Center(
          child: Text(
            'H',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: size * 0.46,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _HisaabLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.24);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.accent, AppColors.accentLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), bgPaint);

    final pagePaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;

    final left = size.width * 0.23;
    final top = size.height * 0.22;
    final right = size.width * 0.77;
    final bottom = size.height * 0.78;

    final bookPath = Path()
      ..moveTo(left, top)
      ..lineTo(left, bottom)
      ..quadraticBezierTo(size.width * 0.50, size.height * 0.66, right, bottom)
      ..lineTo(right, top);
    canvas.drawPath(bookPath, pagePaint);

    final rupeePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.37, size.height * 0.32),
      Offset(size.width * 0.65, size.height * 0.32),
      rupeePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.37, size.height * 0.43),
      Offset(size.width * 0.60, size.height * 0.43),
      rupeePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
