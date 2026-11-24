import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/nav_visibility.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/widgets/nav_pill.dart';

/// The five destinations, with the pill floating over them.
///
/// Content is not inset by the pill: it scrolls beneath it and reserves
/// clearance at the foot of each list, so the pill reads as an object over the
/// page rather than a bar that owns the bottom of the screen.
///
/// The shell owns the ground colour. Linger reads on pure black or pure white
/// rather than the page ground, and the change is animated here on the same
/// clock as the branch cross-fade, so it never snaps between tabs.
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

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _page = AnimationController(
    vsync: this,
    duration: HsMotion.page,
    value: 1,
  );
  // Once, not per build: a CurvedAnimation listens to its parent until it is
  // disposed, so one per build leaked a listener each time.
  late final CurvedAnimation _eased = CurvedAnimation(
    parent: _page,
    curve: HsMotion.pageCurve,
  );
  bool _forward = true;

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex !=
        oldWidget.navigationShell.currentIndex) {
      _forward =
          widget.navigationShell.currentIndex >
          oldWidget.navigationShell.currentIndex;
      // Park the incoming tab off to the side now and start the clock after
      // this frame: a first visit builds its page in it, and the slide must
      // not spend its start on that.
      _page.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _page.forward();
      });
    }
  }

  @override
  void dispose() {
    _eased.dispose();
    _page.dispose();
    super.dispose();
  }

  /// A horizontal fling anywhere on the page moves to the next destination.
  /// Vertical drags belong to the list, so only a decisive horizontal one wins.
  void _onHorizontalFling(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 240) return;
    final index = widget.navigationShell.currentIndex;
    final next = velocity < 0 ? index + 1 : index - 1;
    if (next < 0 || next >= widget.navigationShell.route.branches.length) {
      return;
    }
    ref.read(navVisibilityProvider.notifier).show();
    widget.navigationShell.goBranch(next);
  }

  /// Tapping the tab you are on takes its list back to the top: one
  /// ordinary animated scroll, nothing at the top. Linger keeps its own
  /// behaviour (its vertical list is a card stack, not a page of rows).
  void _scrollActiveToTop() {
    if (widget.navigationShell.currentIndex == AppShell.lingerIndex) return;
    ScrollableState? found;
    void visit(Element e) {
      if (found != null) return;
      final w = e.widget;
      // An inactive branch is offstage: only the one on stage counts.
      if (w is Offstage && w.offstage) return;
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

    (context as Element).visitChildren(visit);
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
    final palette = context.hs;
    final index = widget.navigationShell.currentIndex;
    // One InheritedWidget read, no MediaQuery: keyboard frames do not
    // rebuild the shell.
    final reduced = HsMotion.reduced(context);

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
      child: AnimatedContainer(
        duration: HsMotion.of(context, HsMotion.page),
        curve: HsMotion.curveOf(context, HsMotion.pageCurve),
        color: index == AppShell.lingerIndex
            ? palette.lingerBackground
            : palette.background,
        // The child is built once per tab change, not per ground frame or
        // per pill hide: the pill watches its own providers below.
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onHorizontalDragEnd: _onHorizontalFling,
                // Transparent, not opaque: the pages underneath still get their
                // own taps and vertical drags.
                behavior: HitTestBehavior.translucent,
                child: ClipRect(
                  // The translation stays in the tree at rest (offset zero)
                  // rather than being added for the animation: swapping the
                  // wrapper re-parents every branch's subtree at the start
                  // and end of each switch, which is what made the slide
                  // stutter. The boundary sits *inside* it, so the page is
                  // rasterised once and only moved, frame to frame.
                  child: AnimatedBuilder(
                    animation: _eased,
                    builder: (context, child) {
                      final t = reduced ? 1.0 : _eased.value;
                      final dx = _forward ? (1 - t) : -(1 - t);
                      return FractionalTranslation(
                        translation: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: RepaintBoundary(child: widget.navigationShell),
                  ),
                ),
              ),
            ),
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

/// The pill and its hide on scroll. Watches the visibility and blur itself, so
/// a hide rebuilds this and nothing else.
class _PillLayer extends ConsumerWidget {
  const new({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blur = ref.watch(settingsProvider.select((s) => s.blurBehindNav));
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
          child: NavPill(
            destinations: NavPill.destinationsForApp,
            selectedIndex: index,
            blur: blur,
            onSelected: onSelected,
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
  const new({required this.slot, required this.child, super.key});

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

  void _tryWarm() {
    if (!mounted || _built) return;
    if (HsHaptics.scrolling ||
        SchedulerBinding.instance.transientCallbackCount > 0) {
      _timer = Timer(_retry, _tryWarm);
      return;
    }
    setState(() => _built = true);
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
