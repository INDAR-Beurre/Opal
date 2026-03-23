import 'dart:ui';
import 'package:flutter/material.dart';

/// Enhanced Liquid Glass container with 5-layer architecture:
///   1. BackdropFilter blur (refraction)
///   2. Tint layer (semi-transparent wash)
///   3. Specular shine (gradient highlights)
///   4. Edge highlight border (inner glow)
///   5. Content
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double intensity;
  final bool reducedGlass;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? tintColor;
  final bool enableSpecular;
  final Alignment specularPosition;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.intensity = 1.0,
    this.reducedGlass = false,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tintColor,
    this.enableSpecular = true,
    this.specularPosition = const Alignment(-0.3, -0.6),
  });

  @override
  Widget build(BuildContext context) {
    final blurSigma = reducedGlass ? 8.0 : 20.0 * intensity;
    final tint = tintColor ?? Colors.white;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Stack(
            children: [
              // Layer 1: Tint
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    color: tint.withValues(alpha: reducedGlass ? 0.3 : 0.08 * intensity),
                  ),
                ),
              ),

              // Layer 2: Specular shine
              if (enableSpecular && !reducedGlass)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      gradient: RadialGradient(
                        center: specularPosition,
                        radius: 0.8,
                        colors: [
                          Colors.white.withValues(alpha: 0.18 * intensity),
                          Colors.white.withValues(alpha: 0.04 * intensity),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),

              // Layer 3: Edge shine + border
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    gradient: reducedGlass
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.22 * intensity),
                              Colors.white.withValues(alpha: 0.06 * intensity),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.04 * intensity),
                            ],
                            stops: const [0.0, 0.25, 0.55, 1.0],
                          ),
                    border: Border.all(
                      color: Colors.white.withValues(
                          alpha: reducedGlass ? 0.08 : 0.2 * intensity),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12 * intensity),
                        blurRadius: 28 * intensity,
                        spreadRadius: -6,
                        offset: Offset(0, 10 * intensity),
                      ),
                    ],
                  ),
                ),
              ),

              // Layer 4: Small specular blob
              if (enableSpecular && !reducedGlass)
                Positioned(
                  top: borderRadius * 0.3,
                  left: borderRadius * 0.5,
                  child: Transform.rotate(
                    angle: -0.25,
                    child: Container(
                      width: borderRadius * 1.8,
                      height: borderRadius * 0.6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(borderRadius),
                        color: Colors.white.withValues(alpha: 0.12 * intensity),
                      ),
                    ),
                  ),
                ),

              // Layer 5: Content
              Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
