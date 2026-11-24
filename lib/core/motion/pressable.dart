// Every spring and haptic here is fire-and-forget by design; nothing awaits
// an animation in this kit.
// ignore_for_file: discarded_futures
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/spring_curve.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';

/// What is being pressed. Sets the scale and the corner morph (motion.md
/// "Press amounts").
enum PressKind { card, row, button, iconButton, fab, chip }

/// Press response: scale (card / row .98, fab / chip .96; Subtle .99 for
/// card / row / button; none at Off) and, for buttons, a corner morph.
///
/// Listener-based, so an InkWell / GestureDetector inside keeps its own tap
/// and state layer. Pass [onTap] / [onLongPress] only when there is no inner
/// tap handler. Down on springFast, up on springDefault (card / row) or
/// springFast (buttons); Subtle uses springSubtle; Off does nothing. Retargets
/// from the current value and velocity; no ticker runs at rest.
///
/// Use [child] for scale only. For the corner morph use [builder], which gets
/// the current corner radius (dp) to apply to the shape and the press
/// progress (0 at rest, 1 pressed, can overshoot) for fills.
class Pressable extends StatefulWidget {
  const new({
    super.key,
    this.child,
    this.builder,
    this.onTap,
    this.onLongPress,
    this.kind = PressKind.card,
    this.restRadius,
    this.pressedRadius,
    this.morphCorners,
    this.enabled = true,
    this.haptic = false,
    this.semanticLabel,
    this.selected,
  }) : assert(
         (child == null) != (builder == null),
         'Give a child or a builder, not both',
       );

  final Widget? child;

  /// Gets the animated corner radius (dp). Only buttons / icon buttons / fab /
  /// chips morph, and only at Expressive; otherwise it stays [restRadius].
  final Widget Function(BuildContext context, double radius, double pressed)?
  builder;
  final VoidCallback? onTap;

  /// Fires with the long-press haptic.
  final VoidCallback? onLongPress;
  final PressKind kind;

  /// Corner radius at rest (pill: half the height). Defaults by [kind].
  final double? restRadius;

  /// Corner radius while pressed. Defaults by [kind] (button 8, icon 12,
  /// fab 12, chip 6).
  final double? pressedRadius;

  /// Morph the corners on press. Null: buttons, icon buttons, fab and chips
  /// do; cards and rows do not (they keep the parent's shape).
  final bool? morphCorners;
  final bool enabled;

  /// A light tick when a press ends as a tap. Selection controls (chips,
  /// toggles, segments) pass true; plain taps stay silent, as in Kuber.
  final bool haptic;

  /// What TalkBack reads. Announced as a button whenever there is a tap.
  final String? semanticLabel;

  /// Announced state for a selection control; null for a plain button.
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _v = ValueNotifier(0);
  AnimationController? _c;
  Offset? _down;

  /// Where the current press began, for the tap haptic; null once the
  /// pointer has moved past the slop (a scroll, not a tap).
  Offset? _tapAt;

  AnimationController get _ctrl =>
      _c ??= AnimationController.unbounded(vsync: this)
        ..addListener(() => _v.value = _c!.value);

  @override
  void dispose() {
    _c?.dispose();
    _v.dispose();
    super.dispose();
  }

  bool get _morphs =>
      widget.morphCorners ??
      switch (widget.kind) {
        PressKind.card || PressKind.row => false,
        _ => true,
      };

  double _scale(MotionLevel l) {
    if (l == MotionLevel.off) return 1;
    if (l == MotionLevel.subtle) {
      return switch (widget.kind) {
        PressKind.card ||
        PressKind.row ||
        PressKind.button => HsMotion.pressScaleSubtle,
        _ => 1,
      };
    }
    return switch (widget.kind) {
      PressKind.card || PressKind.row => HsMotion.pressScaleCard,
      PressKind.fab => HsMotion.pressScaleFab,
      PressKind.chip => HsMotion.pressScaleChip,
      _ => 1,
    };
  }

  double get _rest =>
      widget.restRadius ??
      switch (widget.kind) {
        PressKind.button || PressKind.iconButton => 20,
        PressKind.fab => 16,
        PressKind.chip => 8,
        _ => HsRadius.card.x,
      };

  double get _pressed =>
      widget.pressedRadius ??
      switch (widget.kind) {
        PressKind.button => 8,
        PressKind.iconButton || PressKind.fab => 12,
        PressKind.chip => 6,
        _ => _rest,
      };

  void _press(PointerDownEvent e) {
    if (!widget.enabled) return;
    _tapAt = e.position;
    final l = HsMotion.levelOf(context);
    if (l == MotionLevel.off) return;
    _down = e.position;
    _ctrl.springTo(1, HsMotion.spatial(l, HsMotion.springFast));
  }

  void _release([PointerEvent? e]) {
    if (_down == null) return;
    _down = null;
    final l = HsMotion.levelOf(context);
    final up = _morphs ? HsMotion.springFast : HsMotion.springDefault;
    _ctrl.springTo(0, HsMotion.spatial(l, up));
  }

  void _up(PointerUpEvent e) {
    if (_tapAt != null && widget.haptic && widget.enabled) HsHaptics.tick();
    _tapAt = null;
    _release(e);
  }

  void _cancel(PointerCancelEvent e) {
    _tapAt = null;
    _release(e);
  }

  void _move(PointerMoveEvent e) {
    final t = _tapAt;
    if (t != null && (e.position - t).distance > kTouchSlop) _tapAt = null;
    final d = _down;
    // A drag (scroll) is not a press: let go once it passes the touch slop.
    if (d != null && (e.position - d).distance > kTouchSlop) _release();
  }

  @override
  Widget build(BuildContext context) {
    final level = HsMotion.levelOf(context);
    final scale = _scale(level);
    final morph = _morphs && level == MotionLevel.expressive;
    final rest = _rest;
    final pressed = _pressed;

    Widget body = AnimatedBuilder(
      animation: _v,
      child: widget.child,
      builder: (context, child) {
        final v = _v.value;
        final inner =
            widget.builder?.call(
              context,
              morph ? math.max(0.0, rest + (pressed - rest) * v) : rest,
              v,
            ) ??
            child!;
        return Transform.scale(scale: 1 + (scale - 1) * v, child: inner);
      },
    );
    if (widget.onTap != null || widget.onLongPress != null) {
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled && widget.onLongPress != null
            ? () {
                HsHaptics.longPress();
                widget.onLongPress!();
              }
            : null,
        child: body,
      );
    }
    final tappable =
        widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    body = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _press,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: body,
    );
    if (!tappable && widget.semanticLabel == null) return body;
    return Semantics(
      button: true,
      enabled: widget.enabled ? null : false,
      label: widget.semanticLabel,
      selected: widget.selected,
      child: body,
    );
  }
}
