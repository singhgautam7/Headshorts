import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/widgets/app_header.dart';

/// A settings row that something else in the app linked to: when [active] the
/// page scrolls to it and it glows once, so the reader sees which one was
/// meant. Kuber's arrival highlight. Costs nothing when not active.
class SettingsAnchor extends StatefulWidget {
  const new({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  @override
  State<SettingsAnchor> createState() => _SettingsAnchorState();
}

class _SettingsAnchorState extends State<SettingsAnchor>
    with SingleTickerProviderStateMixin {
  AnimationController? _glow;

  @override
  void initState() {
    super.initState();
    if (!widget.active) return;
    _glow = AnimationController(vsync: this, duration: HsMotion.arrival);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_arrive()));
  }

  Future<void> _arrive() async {
    if (!mounted) return;
    // Below the floating header, and nearer the middle on a short screen.
    final inset = HeaderPage.insetOf(context);
    final viewport = Scrollable.maybeOf(context)?.context.size?.height ?? 0;
    await Scrollable.ensureVisible(
      context,
      alignment: viewport > 0 ? (inset / viewport + 0.05).clamp(0.3, 0.6) : 0.3,
      duration: HsMotion.levelOf(context) == MotionLevel.off
          ? Duration.zero
          : HsMotion.page,
      curve: HsMotion.pageCurve,
    );
    if (mounted) _glow!.forward();
  }

  @override
  void dispose() {
    _glow?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = _glow;
    if (glow == null) return widget.child;
    final tint = context.hs.primary;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: glow,
              builder: (_, _) => ColoredBox(
                color: tint.withValues(
                  alpha: 0.16 * HsMotion.arrivalStrength(glow.value),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
