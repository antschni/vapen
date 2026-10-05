import 'package:flutter/material.dart';

/// Brand mark: three rising vapor shapes on a rounded tile.
/// Matches the web logo (`favicon.svg` / PWA icon).
class VapenLogo extends StatelessWidget {
  const VapenLogo({super.key, this.size = 40});

  final double size;

  static const brand = Color(0xFF4466AA);

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _VapenLogoPainter()),
    );
  }
}

class _VapenLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final radius = s * 0.25;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      Paint()..color = VapenLogo.brand,
    );

    final scale = s / 32;
    canvas.save();
    canvas.scale(scale);
    _puff(canvas, 16, 11, 5.5, 3, 0.65);
    _puff(canvas, 16, 16, 4, 2.5, 0.85);
    _puff(canvas, 16, 21, 2.25, 2.25, 1);
    canvas.restore();
  }

  void _puff(Canvas canvas, double cx, double cy, double rx, double ry, double opacity) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
