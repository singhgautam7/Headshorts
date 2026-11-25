import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/nav_visibility.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/spring_curve.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/widgets/nav_pill.dart';

/// The five destinations, with the pill floating over them.
///
/// Content is not inset by the pill: it scrolls beneath it and reserves
/// clearance at the foot of each list, so the pill reads as an object over the
/// page rather than a bar that owns the bottom of the screen.
///
/// Each branch page paints its own ground inside the layer that slides: Linger
/// reads on pure black or pure white rather than the page ground, so two pages
/// side by side keep their own.
class AppShell extends ConsumerStatefulWidget {
  const new(this.navigationShell, {super.key});

  /// The branch whose ground is `HsPalette.lingerBackground`.
  static const lingerIndex = 1;

  /// Home. Back from any other tab lands here; back from here exits.
  static const homeIndex = 0;

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex !=
        oldWidget.navigationShell.currentIndex) {
      // A swipe changes the tab without going through the pill, so the pill
      // is brought back here. After the frame: a provider must not change
      // while the tree is building.
      // A fling on the page left behind is muted and never reports its end.
      HsHaptics.scrolling = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(navVisibilityProvider.notifier).show();
      });
    }
  }

  /// Tapping the tab you are on takes its list back to the top: one
  /// ordinary animated scroll, nothing at the top. Linger keeps its own
  /// behaviour (its vertical list is a card stack, not a page of rows).
  void _scrollActiveToTop() {
    final index = widget.navigationShell.currentIndex;
    if (index == AppShell.lingerIndex) return;
    // The branch's own navigator, not the whole shell: a tab being warmed is
    // painted too, and its list must not answer for the one on stage.
    final nav = widget
        .navigationShell
        .route
        .branches[index]
        .navigatorKey
        .currentContext;
    if (nav == null) return;
    ScrollableState? found;
    void visit(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is ScrollableState) {
        final st = e.state as ScrollableState;
        if (axisDirectionToAxis(st.axisDirection) == Axis.vertical &&
            st.position.hasPixels) {
          found = st;
          return;
        }
      }
      e.visitChildren(visit);
    }

    (nav as Element).visitChildren(visit);
    final position = found?.position;
    if (position == null || position.pixels <= position.minScrollExtent) {
      return;
    }
    unawaited(
      position.animateTo(
        position.minScrollExtent,
        duration: HsMotion.of(context, HsMotion.page),
        curve: HsMotion.curveOf(context, HsMotion.pageCurve),
      ),
    );
  }

  void _onSelected(int tapped) {
    ref.read(navVisibilityProvider.notifier).show();
    final index = widget.navigationShell.currentIndex;
    if (tapped == index) _scrollActiveToTop();
    widget.navigationShell.goBranch(tapped, initialLocation: tapped == index);
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;

    // Back from any other tab lands on Headlines, as in Perch. A pushed
    // screen or a sheet sits above this route on the root navigator, so it
    // pops first; only once nothing is over the shell does the press reach
    // here. On Headlines the disposition is the platform's, and the app exits
    // as usual.
    return PopScope(
      canPop: index == AppShell.homeIndex,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(navVisibilityProvider.notifier).show();
        widget.navigationShell.goBranch(AppShell.homeIndex);
      },
      // Each branch page paints its own ground inside the layer that slides
      // (see BranchStack), so two pages side by side each keep theirs. This
      // box is only what shows through before a page has built.
      child: ColoredBox(
        color: context.hs.background,
        child: Stack(
          children: [
            Positioned.fill(child: widget.navigationShell),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _PillLayer(index: index, onSelected: _onSelected),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The branch container for `StatefulShellRoute`: [BranchStack] in place of
/// the default `IndexedStack`.
Widget appBranchContainer(
  BuildContext context,
  StatefulNavigationShell shell,
  List<Widget> children,
) => BranchStack(
  index: shell.currentIndex,
  onSelect: shell.goBranch,
  children: children,
);

/// The branches as pages side by side, switched as Kuber's tab pager does: a
/// tap slides the whole page over, a far tab slides in from next door, a
/// sideways drag follows the finger, and a new tap mid-slide carries on from
/// where the pages are. Subtle is the same (a slide has no overshoot); Off
/// switches at once.
///
/// Not a `PageView`: that lays out a third page in the frame of a far jump
/// and cannot paint a page ahead of its visit. Here a slide moves finished
/// layers, and a tab being warmed ([WarmTab]) is painted for a frame or two at
/// an opacity nobody can see.
///
/// Vertical lists and rows that scroll sideways sit deeper in the arena and
/// win over the drag recogniser here.
class BranchStack extends StatefulWidget {
  const new({
    required this.index,
    required this.onSelect,
    required this.children,
    super.key,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<Widget> children;

  /// The branch being painted ahead of its first visit, if any.
  static final ValueNotifier<int?> warming = ValueNotifier<int?>(null);

  /// A fling at or above this switches whatever the distance.
  static const flingVelocity = 240.0;

  @override
  State<BranchStack> createState() => _BranchStackState();
}

class _BranchStackState extends State<BranchStack>
    with SingleTickerProviderStateMixin {
  /// One step of 8-bit alpha: painted, and not visible.
  static const _unseen = 1 / 255;

  /// Where the view is on the strip, in pages.
  late final AnimationController _cam = AnimationController.unbounded(
    vsync: this,
    value: widget.index.toDouble(),
  );

  /// Pages on the strip now, and where. At rest only the active one.
  late Map<int, int> _strip = {widget.index: widget.index};

  bool _dragging = false;

  @override
  void didUpdateWidget(BranchStack old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index) return;
    if (HsMotion.levelOf(context) == MotionLevel.off) {
      _rest();
      return;
    }
    _strip.putIfAbsent(widget.index, () {
      final at = _strip[old.index]! + (widget.index > old.index ? 1 : -1);
      // Whatever was mid-slide there gives up its place.
      _strip.removeWhere((_, p) => p == at);
      return at;
    });
    // After this frame: a first visit builds the page in it, and the slide
    // must not spend its start on that.
    unawaited(
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted && !_dragging) {
          _settle(duration: HsMotion.pageSlide, curve: HsMotion.pageSlideCurve);
        }
      }),
    );
  }

  /// Slides to the active page and then leaves only it on the strip.
  void _settle({Duration? duration, Curve curve = Curves.easeOut}) {
    final to = _strip[widget.index]!.toDouble();
    final f = duration != null
        ? _cam.animateTo(to, duration: duration, curve: curve)
        : _cam.springTo(to, HsMotion.springStandard);
    unawaited(f.whenComplete(_trim));
  }

  void _trim() {
    if (!mounted || _dragging || _cam.isAnimating) return;
    setState(_rest);
  }

  void _rest() {
    _strip = {widget.index: widget.index};
    _cam.value = widget.index.toDouble();
  }

  void _place(int page, int at) {
    _strip
      ..remove(page)
      ..removeWhere((_, p) => p == at)
      ..[page] = at;
  }

  void _dragStart(DragStartDetails d) {
    if (HsMotion.levelOf(context) == MotionLevel.off) return;
    _cam.stop();
    final at = _strip[widget.index]!;
    setState(() {
      _dragging = true;
      if (widget.index > 0) _place(widget.index - 1, at - 1);
      if (widget.index < widget.children.length - 1) {
        _place(widget.index + 1, at + 1);
      }
    });
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final at = _strip[widget.index]!;
    final lo = at - (widget.index > 0 ? 1.0 : 0.0);
    final hi = at + (widget.index < widget.children.length - 1 ? 1.0 : 0.0);
    _cam.value = (_cam.value - d.primaryDelta! / context.size!.width).clamp(
      lo,
      hi,
    );
  }

  void _dragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final fling = v.abs() >= BranchStack.flingVelocity;
    final step = fling
        ? (v < 0 ? 1 : -1)
        : _dragging
        ? (_cam.value - _strip[widget.index]!).round().clamp(-1, 1)
        : 0;
    _dragging = false;
    final next = widget.index + step;
    if (step != 0 && next >= 0 && next < widget.children.length) {
      widget.onSelect(next); // didUpdateWidget slides the rest of the way
    } else {
      _settle();
    }
  }

  @override
  void dispose() {
    _cam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _dragStart,
      onHorizontalDragUpdate: _dragUpdate,
      onHorizontalDragEnd: _dragEnd,
      onHorizontalDragCancel: () {
        if (!_dragging) return;
        _dragging = false;
        _settle();
      },
      child: ValueListenableBuilder<int?>(
        valueListenable: BranchStack.warming,
        builder: (context, warm, _) => Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++) _page(i, warm),
          ],
        ),
      ),
    ),
  );

  Widget _page(int i, int? warm) {
    final active = i == widget.index;
    final at = _strip[i];
    final palette = context.hs;
    return Offstage(
      offstage: at == null && i != warm,
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeSemantics(
          excluding: !active,
          child: ExcludeFocus(
            excluding: !active,
            child: AnimatedBuilder(
              animation: _cam,
              builder: (_, child) => FractionalTranslation(
                translation: Offset(at == null ? 0 : at - _cam.value, 0),
                child: child,
              ),
              child: Opacity(
                opacity: at == null ? _unseen : 1,
                child: RepaintBoundary(
                  // Its own ground, so two pages side by side each keep
                  // theirs: Linger reads on pure black / white.
                  child: ColoredBox(
                    color: i == AppShell.lingerIndex
                        ? palette.lingerBackground
                        : palette.background,
                    child: TickerMode(
                      enabled: active,
                      child: widget.children[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pill and its hide on scroll. Watches the visibility itself, so
/// a hide rebuilds this and nothing else.
class _PillLayer extends ConsumerWidget {
  const new({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(navVisibilityProvider);
    final duration = HsMotion.of(context, HsMotion.navHide);
    final curve = HsMotion.curveOf(context, HsMotion.navHideCurve);
    return AnimatedSlide(
      // Detached, so sliding it past the bottom inset costs no layout — the
      // content underneath does not move at all.
      offset: visible ? Offset.zero : const Offset(0, 1.2),
      duration: duration,
      curve: curve,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: duration,
        curve: curve,
        child: IgnorePointer(
          ignoring: !visible,
          // Five items share one row: past this the label has nowhere to go.
          // TalkBack and the icons carry the rest, as in Material's own bar.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.2,
            child: NavPill(
              destinations: NavPill.destinationsForApp,
              selectedIndex: index,
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds a tab ahead of its first visit, while the app idles on another.
///
/// Used from the router with `StatefulShellBranch(preload: true)`: go_router
/// then creates the branch's navigator straight away (cheap, the route builds
/// only this widget) and the page itself waits here until [slot] idle slots
/// after start-up with no animation or scroll under way. Offstage branches are
/// laid out but not painted, so by the first visit the build and layout are
/// done. Never wrap Linger: its build starts a queue and marks cards seen.
class WarmTab extends StatefulWidget {
  const new({
    required this.branch,
    required this.slot,
    required this.child,
    super.key,
  });

  /// This tab's index in the shell, so the stack can paint it ahead.
  final int branch;

  /// 0 is the first tab to warm; each later slot waits a little longer.
  final int slot;
  final Widget child;

  @override
  State<WarmTab> createState() => _WarmTabState();
}

class _WarmTabState extends State<WarmTab> {
  static const _first = Duration(milliseconds: 1500);
  static const _step = Duration(milliseconds: 700);
  static const _retry = Duration(milliseconds: 200);

  bool _built = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_first + _step * widget.slot, _tryWarm);
  }

  Future<void> _tryWarm() async {
    if (!mounted || _built) return;
    if (HsHaptics.scrolling ||
        SchedulerBinding.instance.transientCallbackCount > 0) {
      _timer = Timer(_retry, _tryWarm);
      return;
    }
    setState(() => _built = true);
    // Paint it once, at an opacity nobody can see, so the first visit is a
    // repaint rather than a first paint.
    await WidgetsBinding.instance.endOfFrame;
    BranchStack.warming.value = widget.branch;
    await WidgetsBinding.instance.endOfFrame;
    if (BranchStack.warming.value == widget.branch) {
      BranchStack.warming.value = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Visited before its slot came: build at once.
    if (TickerMode.valuesOf(context).enabled) _built = true;
    return _built ? widget.child : const SizedBox.expand();
  }
}
