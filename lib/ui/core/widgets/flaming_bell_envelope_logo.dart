import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ícono vectorial nativo (`CustomPainter`) que plasma el concepto de marca:
/// "Un sobre con una campana en llamas".
class FlamingBellEnvelopeLogo extends StatelessWidget {
  const FlamingBellEnvelopeLogo({
    super.key,
    this.size = 88,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceSlate,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: AppTheme.flameAmber.withOpacity(0.35), width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.flameRed.withOpacity(0.28),
            blurRadius: size * 0.3,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _FlamingBellEnvelopePainter(),
      ),
    );
  }
}

class _FlamingBellEnvelopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final flameGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Color(0xFFFFD60A),
        AppTheme.flameAmber,
        AppTheme.flameRed,
      ],
    ).createShader(Rect.fromLTWH(0, h * 0.08, w, h * 0.65));

    // 1. Llamas estilizadas coronando la campana
    final flamePaint = Paint()
      ..shader = flameGradient
      ..style = PaintingStyle.fill;

    final flamePath = Path()
      ..moveTo(w * 0.50, h * 0.11)
      ..cubicTo(w * 0.63, h * 0.20, w * 0.72, h * 0.28, w * 0.66, h * 0.44)
      ..cubicTo(w * 0.74, h * 0.36, w * 0.77, h * 0.48, w * 0.68, h * 0.56)
      ..lineTo(w * 0.32, h * 0.56)
      ..cubicTo(w * 0.23, h * 0.48, w * 0.26, h * 0.36, w * 0.34, h * 0.44)
      ..cubicTo(w * 0.28, h * 0.28, w * 0.37, h * 0.20, w * 0.50, h * 0.11)
      ..close();
    canvas.drawPath(flamePath, flamePaint);

    // 2. Cuerpo de la campana de alarma emergiendo del sobre abierto
    final bellPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final bellPath = Path()
      ..moveTo(w * 0.50, h * 0.28)
      ..cubicTo(w * 0.38, h * 0.28, w * 0.35, h * 0.39, w * 0.35, h * 0.50)
      ..lineTo(w * 0.30, h * 0.57)
      ..lineTo(w * 0.70, h * 0.57)
      ..lineTo(w * 0.65, h * 0.50)
      ..cubicTo(w * 0.65, h * 0.39, w * 0.62, h * 0.28, w * 0.50, h * 0.28)
      ..close();
    canvas.drawPath(bellPath, bellPaint);

    // Badajo de la campana
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.60),
      w * 0.045,
      Paint()..color = AppTheme.flameAmber,
    );

    // 3. Base del sobre táctico (Envelope) en primer plano
    final envelopeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.20, h * 0.54, w * 0.60, h * 0.31),
      Radius.circular(w * 0.05),
    );
    final envelopePaint = Paint()
      ..color = const Color(0xFFE6EDF3)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(envelopeRect, envelopePaint);

    // Pliegues internos del sobre
    final creasePaint = Paint()
      ..color = AppTheme.backgroundObsidian
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.032
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final flapPath = Path()
      ..moveTo(w * 0.21, h * 0.56)
      ..lineTo(w * 0.50, h * 0.73)
      ..lineTo(w * 0.79, h * 0.56);
    canvas.drawPath(flapPath, creasePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
