import 'package:flutter/material.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';

/// Back, share, overflow, "Aa" — every icon action in a top bar is *this*
/// button. One place decides the hit area, the shape, the fill and the tint,
/// so a bar can never grow a one-off.
///
/// The visual is a [size] circle on the surface-variant tone; the tap target
/// is never below [HsSize.buttonMedium].
class HsIconButton extends StatelessWidget {
  const new({
    required this.onPressed,
    required this.semanticLabel,
    this.icon,
    this.child,
    this.size = 40,
    this.glyphSize = 20,
    this.filled = true,
    this.active = false,
    this.tint,
    super.key,
  });

  /// Either an [icon] or a custom [child] glyph — never both.
  final IconData? icon;
  final Widget Function(Color color)? child;
  final VoidCallback? onPressed;

  /// Required — an icon-only control is invisible to a screen reader without it.
  final String semanticLabel;
  final double size;
  final double glyphSize;

  /// False only for a quiet dismiss that already sits on a tinted surface.
  final bool filled;

  /// The one variation allowed: an open toggle (the Reader's text-size panel).
  final bool active;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final fg = tint ?? palette.textPrimary;
    final bg = active
        ? palette.navActive
        : (filled ? palette.surfaceVariant : Colors.transparent);

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: HsSize.buttonMedium,
        height: HsSize.buttonMedium,
        child: Center(
          child: Material(
            color: bg,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: child != null
                      ? child!(fg)
                      : Icon(icon, size: glyphSize, color: fg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
