import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const LiquidGlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: preferredSize.height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.04),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.08),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              if (leading != null) ...[const SizedBox(width: 4), leading!]
              else const SizedBox(width: 16),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3)),
              ),
              if (actions != null) ...actions!,
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
