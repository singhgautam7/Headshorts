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
class AppShell extends ConsumerWidget {
  const new(this.navigationShell, {super.key});

  /// The branch whose ground is `HsPalette.lingerBackground`.
  static const lingerIndex = 1;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blur = ref.watch(settingsProvider.select((s) => s.blurBehindNav));
    final visible = ref.watch(navVisibilityProvider);
    final palette = context.hs;
    final index = navigationShell.currentIndex;

    return AnimatedContainer(
      duration: HsMotion.of(context, HsMotion.page),
      curve: HsMotion.curveOf(context, HsMotion.pageCurve),
      color: index == lingerIndex
          ? palette.lingerBackground
          : palette.background,
      child: Stack(
        children: [
          Positioned.fill(child: navigationShell),
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
                  offset: visible ? Offset.zero : const Offset(0, 1.5),
                  duration: HsMotion.of(context, HsMotion.navHide),
                  curve: HsMotion.curveOf(context, HsMotion.pageCurve),
                  child: NavPill(
                    destinations: NavPill.destinationsForApp,
                    selectedIndex: index,
                    blur: blur,
                    onSelected: (tapped) {
                      ref.read(navVisibilityProvider.notifier).show();
                      navigationShell.goBranch(
                        tapped,
                        initialLocation: tapped == index,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
