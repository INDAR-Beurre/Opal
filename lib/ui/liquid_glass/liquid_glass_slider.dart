import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Custom glass seek bar with glass thumb, buffered indicator, and smooth animation.
class LiquidGlassSlider extends StatefulWidget {
  final double value;
  final double buffered;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final double height;

  const LiquidGlassSlider({
    super.key,
    required this.value,
    this.buffered = 0,
    required this.max,
    this.onChanged,
    this.onChangeEnd,
    this.activeColor,
    this.height = 4,
  });

  @override
  State<LiquidGlassSlider> createState() => _LiquidGlassSliderState();
}

class _LiquidGlassSliderState extends State<LiquidGlassSlider> {
  bool _isDragging = false;
  double _dragValue = 0;

  double get _effectiveValue =>
      _isDragging ? _dragValue : widget.value.clamp(0, widget.max);
  double get _fraction => widget.max > 0 ? _effectiveValue / widget.max : 0;
  double get _bufferedFraction =>
      widget.max > 0 ? widget.buffered.clamp(0, widget.max) / widget.max : 0;

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? AppTheme.primaryAccent;

    return GestureDetector(
      onHorizontalDragStart: (details) {
        if (widget.onChanged == null) return;
        setState(() {
          _isDragging = true;
          _dragValue = _positionToValue(details.localPosition.dx, context);
        });
      },
      onHorizontalDragUpdate: (details) {
        if (!_isDragging) return;
        final newValue = _positionToValue(details.localPosition.dx, context);
        setState(() => _dragValue = newValue);
        widget.onChanged?.call(newValue);
      },
      onHorizontalDragEnd: (details) {
        if (!_isDragging) return;
        widget.onChangeEnd?.call(_dragValue);
        setState(() => _isDragging = false);
      },
      onTapUp: (details) {
        if (widget.onChanged == null) return;
        final newValue = _positionToValue(details.localPosition.dx, context);
        widget.onChanged?.call(newValue);
        widget.onChangeEnd?.call(newValue);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          final thumbSize = _isDragging ? 18.0 : 14.0;

          return SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                // Track background
                Positioned(
                  left: 0,
                  right: 0,
                  child: Container(
                    height: widget.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.height / 2),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),

                // Buffered progress
                if (_bufferedFraction > 0)
                  Positioned(
                    left: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: widget.height,
                      width: trackWidth * _bufferedFraction,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(widget.height / 2),
                        color: color.withValues(alpha: 0.2),
                      ),
                    ),
                  ),

                // Active progress
                Positioned(
                  left: 0,
                  child: AnimatedContainer(
                    duration: _isDragging
                        ? Duration.zero
                        : const Duration(milliseconds: 100),
                    height: widget.height,
                    width: trackWidth * _fraction,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.height / 2),
                      color: color,
                    ),
                  ),
                ),

                // Glass thumb
                Positioned(
                  left: (trackWidth * _fraction) - thumbSize / 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.3, -0.3),
                              radius: 0.7,
                              colors: [
                                Colors.white.withValues(alpha: 0.35),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _positionToValue(double dx, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    final fraction = (dx / box.size.width).clamp(0.0, 1.0);
    return fraction * widget.max;
  }
}
