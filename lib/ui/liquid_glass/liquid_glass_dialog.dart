import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Glass alert/confirm dialog.
class LiquidGlassDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? content;
  final List<LiquidGlassDialogAction> actions;

  const LiquidGlassDialog({
    super.key,
    this.title,
    this.message,
    this.content,
    this.actions = const [],
  });

  /// Show this dialog.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    Widget? content,
    List<LiquidGlassDialogAction> actions = const [],
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => LiquidGlassDialog(
        title: title,
        message: message,
        content: content,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 340),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF14141C).withValues(alpha: 0.9),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 32,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(title!,
                        style:
                            Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                  ],
                  if (message != null) ...[
                    Text(message!,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),
                  ],
                  if (content != null) ...[
                    content!,
                    const SizedBox(height: 20),
                  ],
                  if (actions.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions.map((action) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: TextButton(
                            onPressed: () {
                              action.onPressed?.call();
                              if (action.dismissOnTap) {
                                Navigator.of(context).pop(action.value);
                              }
                            },
                            child: Text(
                              action.label,
                              style: TextStyle(
                                color: action.isDestructive
                                    ? AppTheme.errorRed
                                    : AppTheme.primaryAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassDialogAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final bool dismissOnTap;
  final dynamic value;

  const LiquidGlassDialogAction({
    required this.label,
    this.onPressed,
    this.isDestructive = false,
    this.dismissOnTap = true,
    this.value,
  });
}
