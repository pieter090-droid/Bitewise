import 'package:flutter/material.dart';

import 'package:bitewise/core/theme/app_colors.dart';

/// Code-native Bitewise marks. These stay sharp on every device and are the
/// implementation counterpart of docs/BRANDING.md.
enum BrandMark { bitewise, snackSwap }

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    this.mark = BrandMark.bitewise,
    this.fontSize = 24,
    super.key,
  });

  final BrandMark mark;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final parts = mark == BrandMark.bitewise
        ? ('Bite', 'ise')
        : ('SnackS', 'ap');
    final style = TextStyle(
      color: AppColors.navy,
      fontFamily: 'Georgia',
      fontSize: fontSize,
      height: 1,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
    );
    return Semantics(
      label: mark == BrandMark.bitewise ? 'Bitewise' : 'SnackSwap',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(parts.$1, style: style),
            Padding(
              padding: EdgeInsets.only(bottom: fontSize * .06),
              child: DoubleCheckW(size: fontSize * .9),
            ),
            Text(parts.$2, style: style),
          ],
        ),
      ),
    );
  }
}

class BrandMonogram extends StatelessWidget {
  const BrandMonogram({
    this.mark = BrandMark.bitewise,
    this.size = 32,
    super.key,
  });

  final BrandMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = mark == BrandMark.bitewise ? 'B' : 'S';
    return Semantics(
      label: mark == BrandMark.bitewise ? 'Bitewise' : 'SnackSwap',
      child: SizedBox(
        width: size * 1.35,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: -size * .12,
              child: Text(
                letter,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: size,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: DoubleCheckW(size: size * .7),
            ),
          ],
        ),
      ),
    );
  }
}

class DoubleCheckW extends StatelessWidget {
  const DoubleCheckW({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size * 1.25, size),
        painter: _DoubleCheckPainter(),
      );
}

class _DoubleCheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * .16;
    final navy = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final gold = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    final left = Path()
      ..moveTo(size.width * .04, size.height * .34)
      ..lineTo(size.width * .31, size.height * .78)
      ..lineTo(size.width * .58, size.height * .18);
    final right = Path()
      ..moveTo(size.width * .47, size.height * .48)
      ..lineTo(size.width * .68, size.height * .78)
      ..lineTo(size.width * .98, size.height * .08);
    canvas.drawPath(left, navy);
    canvas.drawPath(right, gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
