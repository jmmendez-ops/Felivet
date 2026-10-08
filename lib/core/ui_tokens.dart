import 'package:flutter/material.dart';

class FeliVetUi {
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double cardRadius = 16;
  static const double compactRadius = 12;
  static const Color accent = Color(0xFF7C3AED);
  static const Color accentDark = Color(0xFF9B5CFF);
  static const Color mutedLight = Color(0xFF6B7280);
  static const Color mutedDark = Color(0xFF9CA3AF);

  static const EdgeInsets cardPadding = EdgeInsets.all(spaceLg);

  static BoxDecoration cardDecoration(
    BuildContext context, {
    bool elevated = false,
    bool accent = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(
        color: accent
            ? scheme.primary.withValues(alpha: 0.2)
            : isDark
            ? scheme.outlineVariant.withValues(alpha: 0.4)
            : Colors.transparent,
      ),
      boxShadow: [
        if (!isDark)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: elevated ? 12 : 9,
            spreadRadius: 0,
            offset: Offset(0, elevated ? 4 : 3),
          ),
      ],
    );
  }

  static BoxDecoration iconBadge(BuildContext context, {Color? color}) {
    final badgeColor = color ?? Theme.of(context).colorScheme.primary;
    return BoxDecoration(
      color: badgeColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(compactRadius),
    );
  }

  static BoxDecoration emptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Colors.white,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(
        color: isDark
            ? Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.4)
            : Colors.grey.shade300,
      ),
    );
  }

  static TextStyle heading(BuildContext context, {double size = 18}) {
    return TextStyle(
      fontSize: size.clamp(16, 18),
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.onSurface
          : Colors.black87,
    );
  }

  static TextStyle muted(BuildContext context, {double size = 13}) {
    return TextStyle(
      fontSize: size.clamp(10, 13),
      height: 1.25,
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.onSurfaceVariant
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
