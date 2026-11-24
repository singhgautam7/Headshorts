import 'package:flutter/cupertino.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';

/// Pull to refresh, drawn the way the component sheet specifies.
///
/// The ring traces with the finger and turns once per fetch — the single
/// exception to the rule that nothing moves unless the reader moved it,
/// because here the reader is literally holding it. It never spins idly.
class PullToRefresh extends StatelessWidget {
  new({
    required this.onRefresh,
    required List<Widget> children,
    this.padding = EdgeInsets.zero,
    this.controller,
    super.key,
  }) : delegate = SliverChildListDelegate(children);

  new builder({
    required this.onRefresh,
    required NullableIndexedWidgetBuilder itemBuilder,
    int? itemCount,
    ChildIndexGetter? findChildIndexCallback,
    this.padding = EdgeInsets.zero,
    this.controller,
    super.key,
  }) : delegate = SliverChildBuilderDelegate(
         itemBuilder,
         childCount: itemCount,
         // With keys on the rows, a refresh that prepends items moves the
         // existing elements instead of re-binding each to the wrong row.
         findChildIndexCallback: findChildIndexCallback,
       );

  final Future<void> Function() onRefresh;
  final SliverChildDelegate delegate;
  final EdgeInsets padding;

  /// For a caller that scrolls the list itself ("back to the top").
  final ScrollController? controller;

  static const _extent = 96.0;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    controller: controller,
    physics: const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ),
    slivers: [
      CupertinoSliverRefreshControl(
        refreshTriggerPullDistance: _extent,
        refreshIndicatorExtent: 62,
        onRefresh: onRefresh,
        builder: (context, mode, pulled, trigger, indicatorExtent) =>
            _Indicator(
              mode: mode,
              progress: (pulled / trigger).clamp(0.0, 1.0),
              extent: indicatorExtent,
            ),
      ),
      SliverPadding(
        padding: padding,
        sliver: SliverList(delegate: delegate),
      ),
    ],
  );
}

class _Indicator extends StatelessWidget {
  const new({required this.mode, required this.progress, required this.extent});

  final RefreshIndicatorMode mode;
  final double progress;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    // rest — a plain rule, no ring at all.
    if (mode == RefreshIndicatorMode.inactive || progress == 0) {
      return SizedBox(
        height: extent,
        child: Center(
          child: Container(
            width: 26,
            height: 2,
            decoration: BoxDecoration(
              color: palette.textMuted,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      );
    }

    final fetching =
        mode == RefreshIndicatorMode.refresh ||
        mode == RefreshIndicatorMode.armed;

    return SizedBox(
      height: extent,
      child: Center(
        child: HsPullRing(
          color: fetching ? palette.textPrimary : palette.textSecondary,
          progress: progress,
          spinning: mode == RefreshIndicatorMode.refresh,
        ),
      ),
    );
  }
}

class HsPullRing extends StatefulWidget {
  const new({
    required this.color,
    required this.progress,
    required this.spinning,
    super.key,
  });

  final Color color;
  final double progress;
  final bool spinning;

  @override
  State<HsPullRing> createState() => _HsPullRingState();
}

class _HsPullRingState extends State<HsPullRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: HsMotion.refreshTurn,
  );

  /// Turns only while a fetch is running, and only if the reader has not
  /// switched motion off. The ticker is muted by [TickerMode] whenever the
  /// list is off screen, so a hidden tab never spins it.
  void _sync() {
    final turn =
        widget.spinning && HsMotion.levelOf(context) != MotionLevel.off;
    if (turn && !_turn.isAnimating) {
      _turn.repeat();
    } else if (!turn && (_turn.isAnimating || _turn.value != 0)) {
      _turn
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HsPullRing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _turn,
    builder: (context, _) => Transform.rotate(
      angle: _turn.value * 6.283185307179586,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CustomPaint(
          painter: _RingPainter(
            color: widget.color,
            sweep: widget.spinning ? 0.75 : widget.progress,
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const new({required this.color, required this.sweep});

  final Color color;
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      Rect.fromLTWH(
        HsSize.glyphStroke / 2,
        HsSize.glyphStroke / 2,
        size.width - HsSize.glyphStroke,
        size.height - HsSize.glyphStroke,
      ),
      -1.5707963267948966,
      6.283185307179586 * sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = HsSize.glyphStroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.sweep != sweep || old.color != color;
}
