import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Enhanced Liquid Glass container inspired by CSS demos:
/// - Demo 2 (DaftPlug): SVG displacement-based distortion → simulated with
///   layered blur + gradient overlays + inner box-shadows
/// - Demo 5 (David Lassiter): Multi-layer glass (effect, tint, shine, content)
/// - Demo 3 (Maxuiux): Specular highlight blobs
///
/// Layers (from back to front):
///   1. BackdropFilter blur (refraction approximation)
///   2. Tint layer (semi-transparent color wash)
///   3. Specular shine layer (gradient highlights)
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
              // Layer 1: Tint (from Demo 5 .liquidGlass-tint)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    color: tint.withOpacity(reducedGlass ? 0.3 : 0.08 * intensity),
                  ),
                ),
              ),

              // Layer 2: Specular shine (from Demo 3 .slider-thumb-glass-overlay)
              if (enableSpecular && !reducedGlass)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      gradient: RadialGradient(
                        center: specularPosition,
                        radius: 0.8,
                        colors: [
                          Colors.white.withOpacity(0.18 * intensity),
                          Colors.white.withOpacity(0.04 * intensity),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),

              // Layer 3: Edge shine (from Demo 5 .liquidGlass-shine box-shadow)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    // Top-left to bottom-right gradient for directional light
                    gradient: reducedGlass
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.22 * intensity),
                              Colors.white.withOpacity(0.06 * intensity),
                              Colors.transparent,
                              Colors.black.withOpacity(0.04 * intensity),
                            ],
                            stops: const [0.0, 0.25, 0.55, 1.0],
                          ),
                    // Inner glow border (from Demo 2 box-shadow: inset)
                    border: Border.all(
                      color: Colors.white
                          .withOpacity(reducedGlass ? 0.08 : 0.2 * intensity),
                      width: 0.8,
                    ),
                    boxShadow: [
                      // Outer depth shadow
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12 * intensity),
                        blurRadius: 28 * intensity,
                        spreadRadius: -6,
                        offset: Offset(0, 10 * intensity),
                      ),
                    ],
                  ),
                ),
              ),

              // Layer 4: Small specular blob (from Demo 3 .slider-thumb-glass-specular)
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
                        color: Colors.white.withOpacity(0.12 * intensity),
                      ),
                    ),
                  ),
                ),

              // Layer 5: Content
              Container(
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
