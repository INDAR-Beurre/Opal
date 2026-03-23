import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidGlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double size;

  const LiquidGlassButton({
    super.key, this.onPressed, required this.child, this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.6),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color iconColor;

  const LiquidGlassIconButton({
    super.key, required this.icon, this.onPressed,
    this.size = 48, this.iconSize = 22, this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassButton(
      onPressed: onPressed, size: size,
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}
