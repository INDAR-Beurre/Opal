import 'package:flutter/material.dart';
import 'liquid_glass_container.dart';

class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool reducedGlass;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 20.0,
    this.padding,
    this.margin,
    this.reducedGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassContainer(
        borderRadius: borderRadius,
        intensity: 0.75,
        reducedGlass: reducedGlass,
        padding: padding ?? const EdgeInsets.all(12),
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: child,
      ),
    );
  }
}
