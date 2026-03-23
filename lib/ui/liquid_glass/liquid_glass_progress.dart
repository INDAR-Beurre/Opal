import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Glass linear progress bar.
class LiquidGlassProgressBar extends StatelessWidget {
  final double? value; // null = indeterminate
  final Color? color;
  final double height;

  const LiquidGlassProgressBar({
    super.key,
    this.value,
    this.color,
    this.height = 3,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? AppTheme.primaryAccent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: value != null
            ? LinearProgressIndicator(
                value: value!,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(progressColor),
              )
            : LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(progressColor),
              ),
      ),
    );
  }
}

/// Glass circular progress indicator.
class LiquidGlassCircularProgress extends StatelessWidget {
  final double? value;
  final Color? color;
  final double size;
  final double strokeWidth;

  const LiquidGlassCircularProgress({
    super.key,
    this.value,
    this.color,
    this.size = 24,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: strokeWidth,
        valueColor:
            AlwaysStoppedAnimation(color ?? AppTheme.primaryAccent),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}
