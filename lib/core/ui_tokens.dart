import 'package:flutter/material.dart';

class FeliVetUi {
  static const double cardRadius = 16;
  static const Color mutedLight = Color(0xFF6B7280);
  static const Color mutedDark = Color(0xFF9CA3AF);

  static BoxDecoration cardDecoration(
    BuildContext context, {
    bool elevated = false,
    bool accent = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(cardRadius),
      border: accent
          ? Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 4,
              ),
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: isDark
                ? 0.28
                : elevated
                ? 0.12
                : 0.05,
          ),
          blurRadius: elevated ? 16 : 6,
          spreadRadius: elevated ? 2 : 0,
          offset: Offset(0, elevated ? 6 : 2),
        ),
      ],
    );
  }

  static TextStyle heading(BuildContext context, {double size = 18}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87,
    );
  }

  static TextStyle muted(BuildContext context, {double size = 13}) {
    return TextStyle(
      fontSize: size,
      color: Theme.of(context).brightness == Brightness.dark
          ? mutedDark
          : mutedLight,
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const DashedBorderPainter({required this.color, this.radius = 12});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 10) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
