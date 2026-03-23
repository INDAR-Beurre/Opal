import 'dart:ui';
import 'package:flutter/material.dart';

/// A modal bottom sheet with the Liquid Glass aesthetic.
/// Inspired by Demo 5's layered glass panels.
class LiquidGlassBottomSheet extends StatelessWidget {
  final Widget child;
  final double maxHeightFraction;

  const LiquidGlassBottomSheet({
    super.key,
    required this.child,
    this.maxHeightFraction = 0.85,
  });

  /// Show this sheet as a modal.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    double maxHeightFraction = 0.85,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => LiquidGlassBottomSheet(
        maxHeightFraction: maxHeightFraction,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeightFraction,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.14),
                  Colors.white.withOpacity(0.04),
                  Colors.black.withOpacity(0.08),
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
              border: Border(
                top: BorderSide(
                    color: Colors.white.withOpacity(0.18), width: 0.7),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
