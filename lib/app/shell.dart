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
class AppShell extends ConsumerWidget {
  const new(this.navigationShell, {super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blur = ref.watch(settingsProvider).blurBehindNav;
    final visible = ref.watch(navVisibilityProvider);

    return ColoredBox(
      color: context.hs.background,
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
                  duration: HsMotion.page,
                  curve: HsMotion.pageCurve,
                  child: NavPill(
                    destinations: NavPill.destinationsForApp,
                    selectedIndex: navigationShell.currentIndex,
                    blur: blur,
                    onSelected: (index) {
                      ref.read(navVisibilityProvider.notifier).show();
                      navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
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
