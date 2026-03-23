import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted glass app bar that fades in/out based on scroll position.
class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final double scrollOffset;
  final bool showBackground;

  const LiquidGlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.scrollOffset = 0,
    this.showBackground = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final opacity =
        showBackground ? (scrollOffset / 100).clamp(0.0, 1.0) : 0.0;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 16 * opacity,
          sigmaY: 16 * opacity,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3 * opacity),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.08 * opacity),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  if (leading != null)
                    leading!
                  else
                    const SizedBox(width: 16),
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.headlineSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  if (actions != null) ...actions!,
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
