import 'package:flutter/cupertino.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/widgets/app_header.dart';

/// Pull to refresh, drawn the way the component sheet specifies.
///
/// The ring traces with the finger and turns once per fetch — the single
/// exception to the rule that nothing moves unless the reader moved it,
/// because here the reader is literally holding it. It never spins idly.
class PullToRefresh extends StatefulWidget {
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
  State<PullToRefresh> createState() => _PullToRefreshState();
}

/// What the sliver is showing, handed to the ring drawn over the list.
typedef _Pull = ({RefreshIndicatorMode mode, double progress, double pulled});

class _PullToRefreshState extends State<PullToRefresh> {
  static const _rest = (
    mode: RefreshIndicatorMode.inactive,
    progress: 0.0,
    pulled: 0.0,
  );

  /// The ring is drawn here, over the list, rather than inside the sliver:
  /// the sliver's region sits at the very top of the scroll view, which is
  /// under the floating header. Drawn below the header's rest height it is
  /// seen; the sliver only reports how far the reader has pulled.
  final _pull = ValueNotifier<_Pull>(_rest);
  _Pull? _pending;

  @override
  void dispose() {
    _pull.dispose();
    super.dispose();
  }

  /// Called from the sliver's builder, i.e. during layout, so the ring is
  /// told after the frame rather than while it is being built.
  void _report(_Pull next) {
    if (_pending == next || (_pending == null && _pull.value == next)) return;
    _pending = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = _pending;
      _pending = null;
      if (mounted && pending != null) _pull.value = pending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = HeaderPage.insetOf(context);
    return Stack(
      children: [
        CustomScrollView(
          controller: widget.controller,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverRefreshControl(
              refreshTriggerPullDistance: PullToRefresh._extent,
              refreshIndicatorExtent: 62,
              onRefresh: widget.onRefresh,
              builder: (context, mode, pulled, trigger, indicatorExtent) {
                _report((
                  mode: mode,
                  progress: (pulled / trigger).clamp(0.0, 1.0),
                  pulled: pulled,
                ));
                return const SizedBox.shrink();
              },
            ),
            SliverPadding(
              padding: widget.padding,
              sliver: SliverList(delegate: widget.delegate),
            ),
          ],
        ),
        Positioned(
          top: inset,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder<_Pull>(
              valueListenable: _pull,
              builder: (context, pull, _) => _Indicator(pull: pull),
            ),
          ),
        ),
      ],
    );
  }
}

/// The ring, centred in the room the pull has opened beneath the header.
class _Indicator extends StatelessWidget {
  const new({required this.pull});

  final _Pull pull;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final mode = pull.mode;

    // At rest there is no ring at all.
    if (mode == RefreshIndicatorMode.inactive || pull.progress == 0) {
      return const SizedBox.shrink();
    }

    final fetching =
        mode == RefreshIndicatorMode.refresh ||
        mode == RefreshIndicatorMode.armed;

    return SizedBox(
      height: pull.pulled,
      child: Center(
        child: HsPullRing(
          color: fetching ? palette.textPrimary : palette.textSecondary,
          progress: pull.progress,
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
