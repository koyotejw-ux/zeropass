import 'package:flutter/material.dart';

/// ZeroPass 하이엔드 럭셔리 B2B 시그니처 브랜드 엠블럼 (ZeroPass Luxury Brand Emblem)
///
/// Apple / Toss / Linear 규격의 미니멀하고 고급스러운 기하학적 패스 심볼.
/// - 딥 옵시디언 & 로열 코발트 그라디언트
/// - 아이스 시안 네온 코어 엑센트
/// - 벡터 커스텀 페인팅으로 어떤 해상도에서도 왜곡 없는 초정밀 렌더링
class ZeroPassBrandEmblem extends StatelessWidget {
  final double size;
  final bool withGlow;
  final List<BoxShadow>? customShadow;

  const ZeroPassBrandEmblem({
    super.key,
    this.size = 64,
    this.withGlow = true,
    this.customShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A), // Deep Royal Cobalt
            Color(0xFF0F172A), // Slate Obsidian
            Color(0xFF090D16), // Pure Void Black
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.1,
        ),
        boxShadow: customShadow ??
            (withGlow
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                      blurRadius: size * 0.35,
                      offset: Offset(0, size * 0.1),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: size * 0.2,
                      offset: Offset(0, size * 0.06),
                    ),
                  ]
                : null),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.52, size * 0.52),
          painter: _ZeroPassEmblemPainter(),
        ),
      ),
    );
  }
}

class _ZeroPassEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = w * 0.14;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Linear gradient for Z-Pass ribbon: Pure White to Electric Sky Blue to Cobalt
    trackPaint.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white,
        Color(0xFF60A5FA), // Light Blue
        Color(0xFF38BDF8), // Electric Ice Cyan
      ],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path = Path();
    // Modern geometric 'Z' with diagonal flow
    path.moveTo(w * 0.15, h * 0.20);
    path.lineTo(w * 0.85, h * 0.20);
    path.lineTo(w * 0.15, h * 0.80);
    path.lineTo(w * 0.85, h * 0.80);

    canvas.drawPath(path, trackPaint);

    // Glowing Neon Cyan Center Pass Core (Micro beacon)
    final dotPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.85, h * 0.20), strokeWidth * 0.45, dotPaint);

    // Subtle white sparkle center
    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.85, h * 0.20), strokeWidth * 0.22, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

