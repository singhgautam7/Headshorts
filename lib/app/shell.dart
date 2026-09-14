import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/nav_visibility.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/widgets/nav_pill.dart';

/// The four destinations, with the pill floating over them.
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
  bool _forward = true;

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex !=
        oldWidget.navigationShell.currentIndex) {
      _forward = widget.navigationShell.currentIndex >
          oldWidget.navigationShell.currentIndex;
      _page.forward(from: 0);
    }
  }

  @override
  void dispose() {
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
    if (next < 0 || next >= 4) return;
    ref.read(navVisibilityProvider.notifier).show();
    widget.navigationShell.goBranch(next);
  }

  @override
  Widget build(BuildContext context) {
    final blur = ref.watch(settingsProvider.select((s) => s.blurBehindNav));
    final visible = ref.watch(navVisibilityProvider);
    final palette = context.hs;
    final index = widget.navigationShell.currentIndex;
    final reduced = HsMotion.reduced(context);
    final pageCurved = CurvedAnimation(
      parent: _page,
      curve: HsMotion.curveOf(context, HsMotion.pageCurve),
    );

    // Back from any other tab lands on Today, as in Perch. A pushed screen or
    // a sheet sits above this route on the root navigator, so it pops first;
    // only once nothing is over the shell does the press reach here. On Today
    // the disposition is the platform's, and the app exits as usual.
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(navVisibilityProvider.notifier).show();
        widget.navigationShell.goBranch(0);
      },
      child: AnimatedContainer(
        duration: HsMotion.of(context, HsMotion.page),
        curve: HsMotion.curveOf(context, HsMotion.pageCurve),
        color: index == AppShell.lingerIndex
            ? palette.lingerBackground
            : palette.background,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onHorizontalDragEnd: _onHorizontalFling,
                // Transparent, not opaque: the pages underneath still get their
                // own taps and vertical drags.
                behavior: HitTestBehavior.translucent,
                child: ClipRect(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: pageCurved,
                      builder: (context, child) {
                        final t = pageCurved.value;
                        if (t == 1 || reduced) return child!;
                        final dx = _forward ? (1 - t) : -(1 - t);
                        return FractionalTranslation(
                          translation: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: widget.navigationShell,
                    ),
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
                  child: AnimatedSlide(
                    // Detached, so sliding it past the bottom inset costs no
                    // layout — the content underneath does not move at all.
                    offset: visible ? Offset.zero : const Offset(0, 1.2),
                    duration: HsMotion.of(context, HsMotion.navHide),
                    curve: HsMotion.curveOf(context, HsMotion.navHideCurve),
                    child: AnimatedOpacity(
                      opacity: visible ? 1.0 : 0.0,
                      duration: HsMotion.of(context, HsMotion.navHide),
                      curve: HsMotion.curveOf(context, HsMotion.navHideCurve),
                      child: IgnorePointer(
                        ignoring: !visible,
                        child: NavPill(
                          destinations: NavPill.destinationsForApp,
                          selectedIndex: index,
                          blur: blur,
                          onSelected: (tapped) {
                            ref.read(navVisibilityProvider.notifier).show();
                            widget.navigationShell.goBranch(
                              tapped,
                              initialLocation: tapped == index,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
