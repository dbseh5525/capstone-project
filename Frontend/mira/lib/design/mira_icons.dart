import 'package:flutter/material.dart';

enum MiraSymbol { home, paw, family, album, sparkle, settings }

/// A single rounded, two-tone stroke language for MIRA's main destinations.
class MiraIcon extends StatelessWidget {
  const MiraIcon(this.symbol, {this.selected = false, super.key});
  final MiraSymbol symbol;
  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 28,
    child: CustomPaint(painter: _SymbolPainter(symbol, selected)),
  );
}

class _SymbolPainter extends CustomPainter {
  _SymbolPainter(this.symbol, this.selected);
  final MiraSymbol symbol;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28, size.height / 28);
    final stroke = Paint()
      ..color = selected ? const Color(0xFF315E50) : const Color(0xFF737B75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = const Color(0xFFE8B78E);
    void path(Path p) => canvas.drawPath(p, stroke);
    void circle(double x, double y, double r) =>
        canvas.drawCircle(Offset(x, y), r, stroke);
    switch (symbol) {
      case MiraSymbol.home:
        path(
          Path()
            ..moveTo(3, 12)
            ..lineTo(14, 3)
            ..lineTo(25, 12),
        );
        path(
          Path()
            ..moveTo(6, 11)
            ..lineTo(6, 24)
            ..lineTo(22, 24)
            ..lineTo(22, 11),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(11, 16, 6, 8),
            const Radius.circular(2),
          ),
          fill,
        );
      case MiraSymbol.paw:
        canvas.drawOval(const Rect.fromLTWH(7, 14, 14, 11), fill);
        path(
          Path()
            ..moveTo(8, 23)
            ..cubicTo(2, 20, 10, 12, 14, 13)
            ..cubicTo(18, 12, 26, 20, 20, 23)
            ..quadraticBezierTo(14, 20, 8, 23),
        );
        for (final point in [
          const Offset(5, 11),
          const Offset(10, 6),
          const Offset(18, 6),
          const Offset(23, 11),
        ]) {
          canvas.drawOval(
            Rect.fromCenter(center: point, width: 4, height: 5),
            stroke,
          );
        }
      case MiraSymbol.family:
        circle(14, 8, 3.5);
        circle(5, 12, 2.5);
        circle(23, 12, 2.5);
        canvas.drawCircle(const Offset(14, 20), 5, fill);
        path(
          Path()
            ..moveTo(8, 24)
            ..lineTo(8, 21)
            ..cubicTo(8, 13, 20, 13, 20, 21)
            ..lineTo(20, 24),
        );
        path(
          Path()
            ..moveTo(2, 23)
            ..lineTo(2, 20)
            ..quadraticBezierTo(2, 16, 6, 17),
        );
        path(
          Path()
            ..moveTo(26, 23)
            ..lineTo(26, 20)
            ..quadraticBezierTo(26, 16, 22, 17),
        );
      case MiraSymbol.album:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 5, 20, 18),
            const Radius.circular(4),
          ),
          stroke,
        );
        path(
          Path()
            ..moveTo(2, 9)
            ..lineTo(2, 23)
            ..quadraticBezierTo(2, 26, 6, 26)
            ..lineTo(21, 26),
        );
        canvas.drawCircle(const Offset(19, 10), 2.3, fill);
        path(
          Path()
            ..moveTo(6, 20)
            ..lineTo(12, 13)
            ..lineTo(17, 18)
            ..lineTo(20, 15)
            ..lineTo(24, 20),
        );
      case MiraSymbol.sparkle:
        canvas.drawCircle(const Offset(14, 14), 8, fill);
        path(
          Path()
            ..moveTo(14, 3)
            ..quadraticBezierTo(15, 13, 25, 14)
            ..quadraticBezierTo(15, 15, 14, 25)
            ..quadraticBezierTo(13, 15, 3, 14)
            ..quadraticBezierTo(13, 13, 14, 3)
            ..close(),
        );
        path(
          Path()
            ..moveTo(23, 2)
            ..lineTo(23, 7)
            ..moveTo(20.5, 4.5)
            ..lineTo(25.5, 4.5),
        );
      case MiraSymbol.settings:
        for (var i = 0; i < 3; i++) {
          final y = 6.0 + i * 8;
          final x = i == 1 ? 18.0 : 10.0;
          path(
            Path()
              ..moveTo(3, y)
              ..lineTo(x - 3, y)
              ..moveTo(x + 3, y)
              ..lineTo(25, y),
          );
          canvas.drawCircle(Offset(x, y), 3, fill);
          circle(x, y, 3);
        }
    }
  }

  @override
  bool shouldRepaint(_SymbolPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.selected != selected;
}
