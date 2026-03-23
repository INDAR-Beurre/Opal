import 'dart:ui';
import 'package:flutter/material.dart';

/// Pill-shaped Liquid Glass bottom nav bar inspired by Demo 5's dock.
class LiquidGlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const LiquidGlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.white.withOpacity(0.06),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.14),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 0.7,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  spreadRadius: -6,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Home',
                    isSelected: currentIndex == 0, onTap: () => onTap(0)),
                _NavItem(icon: Icons.search_rounded, label: 'Search',
                    isSelected: currentIndex == 1, onTap: () => onTap(1)),
                _NavItem(icon: Icons.explore_rounded, label: 'Explore',
                    isSelected: currentIndex == 2, onTap: () => onTap(2)),
                _NavItem(icon: Icons.library_music_rounded, label: 'Library',
                    isSelected: currentIndex == 3, onTap: () => onTap(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected ? Colors.white.withOpacity(0.14) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.45),
                size: 21),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
