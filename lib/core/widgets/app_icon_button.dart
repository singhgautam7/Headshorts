import 'package:flutter/material.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/pressable.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';

/// Back, share, overflow, "Aa" — every icon action in a top bar is *this*
/// button. One place decides the hit area, the shape, the fill and the tint,
/// so a bar can never grow a one-off.
///
/// The visual is a [size] circle on the primaryContainer tone (matching the
/// bottom nav's active tab accent); the tap target is never below
/// [HsSize.tapTarget]. Held, the disc relaxes to a 12 dp squircle at
/// Expressive and the fill goes a shade deeper.
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

  /// Null disables the button (38% opacity, announced as disabled).
  final VoidCallback? onPressed;

  /// Required — an icon-only control is invisible to a screen reader without
  /// it. Also the tooltip on a long press.
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
    final level = HsMotion.levelOf(context);
    final disabled = onPressed == null;
    final fg = tint ?? (active ? palette.onPrimary : palette.textPrimary);
    final bg = active
        ? palette.primary
        : (filled ? palette.primaryContainer : Colors.transparent);
    final target = size < HsSize.tapTarget ? HsSize.tapTarget : size;

    final glyph = child != null
        ? child!(fg)
        : _IconSwap(icon: icon!, size: glyphSize, color: fg);

    Widget button = SizedBox(
      width: target,
      height: target,
      child: Center(
        child: AnimatedOpacity(
          opacity: disabled ? 0.38 : 1,
          duration: level == MotionLevel.off
              ? HsMotion.fxInstant
              : HsMotion.fxFast,
          curve: HsMotion.curveEffects,
          child: Pressable(
            kind: PressKind.iconButton,
            enabled: !disabled,
            onTap: onPressed,
            restRadius: size / 2,
            pressedRadius: HsRadius.heldIcon,
            builder: (context, radius, pressed) => Material(
              color: bg == Colors.transparent || level != MotionLevel.expressive
                  ? bg
                  : Color.lerp(bg, fg, 0.1 * pressed.clamp(0.0, 1.0)),
              animationDuration: Duration.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
              child: SizedBox(
                width: size,
                height: size,
                child: Center(child: glyph),
              ),
            ),
          ),
        ),
      ),
    );

    button = Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      triggerMode: TooltipTriggerMode.longPress,
      child: button,
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// A changed icon scales 0.6 to 1 and fades in on springFast (Expressive);
/// at Subtle and Off it is a plain cross-fade.
class _IconSwap extends StatelessWidget {
  const new({required this.icon, required this.size, required this.color});

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final level = HsMotion.levelOf(context);
    final expressive = level == MotionLevel.expressive;
    return AnimatedSwitcher(
      duration: expressive
          ? HsMotion.fastCurve.settle
          : (level == MotionLevel.off ? HsMotion.fxInstant : HsMotion.fxFast),
      reverseDuration: HsMotion.fxInstant,
      switchInCurve: expressive ? HsMotion.fastCurve : Curves.linear,
      transitionBuilder: (child, anim) {
        final fade = FadeTransition(opacity: anim, child: child);
        if (!expressive) return fade;
        return ScaleTransition(
          scale: anim.drive(Tween(begin: 0.6, end: 1)),
          child: fade,
        );
      },
      child: Icon(icon, key: ValueKey(icon), size: size, color: color),
    );
  }
}
