import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/shell.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/features/bookmarks/bookmarks_screen.dart';
import 'package:headshorts/features/home_widget/widget_sources_screen.dart';
import 'package:headshorts/features/linger/linger_screen.dart';
import 'package:headshorts/features/more/about_screen.dart';
import 'package:headshorts/features/more/appearance_screen.dart';
import 'package:headshorts/features/more/contact_screen.dart';
import 'package:headshorts/features/more/data_screen.dart';
import 'package:headshorts/features/more/header_screen.dart';
import 'package:headshorts/features/more/info_screens.dart';
import 'package:headshorts/features/more/more_screen.dart';
import 'package:headshorts/features/more/permissions_screen.dart';
import 'package:headshorts/features/more/settings_screen.dart';
import 'package:headshorts/features/onboarding/onboarding_screen.dart';
import 'package:headshorts/features/reader/reader_screen.dart';
import 'package:headshorts/features/search/search_screen.dart';
import 'package:headshorts/features/sources/add_source_screen.dart';
import 'package:headshorts/features/sources/opml_import_screen.dart';
import 'package:headshorts/features/sources/source_detail_screen.dart';
import 'package:headshorts/features/sources/sources_screen.dart';
import 'package:headshorts/features/stats/stats_screen.dart';
import 'package:headshorts/features/today/today_screen.dart';

/// Every pushed page, on [HsMotion.page].
/// Expressive: the page fades in and slides over a short way from the end.
/// Subtle: a fade with a small rise that never overshoots. Off: a 90 ms fade.
/// The pop plays the same animation backwards on the same clock.
Page<void> _page(Widget child) => _HsPage(child);

class _HsPage extends Page<void> {
  const new(this.child);

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => _HsRoute(this);
}

/// Starts its animation once the page's first frame is built. Flutter starts
/// the clock on push, so a heavy first frame (the Reader's) spends the
/// fastest part of the transition before anything shows, and the page pops
/// instead of arriving.
class _HsRoute extends PageRoute<void> {
  new(_HsPage page) : super(settings: page);

  _HsPage get _page => settings as _HsPage;

  @override
  Duration get transitionDuration => HsMotion.page;

  @override
  Duration get reverseTransitionDuration => HsMotion.page;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  TickerFuture didPush() {
    final future = super.didPush();
    if (controller case final AnimationController c when c.isAnimating) {
      c.stop();
      unawaited(
        WidgetsBinding.instance.endOfFrame.then((_) {
          // Popped or moved meanwhile: leave it.
          if (isActive &&
              !c.isAnimating &&
              c.value == 0 &&
              c.status == AnimationStatus.forward) {
            c.forward();
          }
        }),
      );
    }
    return future;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: _page.child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final level = HsMotion.levelOf(context);
    final page = RepaintBoundary(child: child);
    if (level == MotionLevel.off) {
      // The route runs 240 ms; the fade takes its first (or last) 90.
      final share =
          HsMotion.fxInstant.inMilliseconds / HsMotion.page.inMilliseconds;
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Interval(0, share),
          reverseCurve: Interval(1 - share, 1),
        ),
        child: page,
      );
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: HsMotion.decelerate,
      reverseCurve: Curves.easeInCubic,
    );
    if (level == MotionLevel.subtle) {
      return SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: page),
      );
    }
    // A slide, not a scale: text under a changing scale is rasterised again at
    // every step, which cost over 100 ms a frame on the way back from a long
    // article.
    return SlideTransition(
      position: Tween(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: curved, child: page),
    );
  }
}

/// Tab switches animate directionally in [AppShell] using FractionalTranslation.
/// The branch's own route does not animate on top of it.
NoTransitionPage<void> _tab(Widget child) =>
    NoTransitionPage<void>(child: child);

/// The root navigator, so something outside the widget tree (a home screen
/// widget tap) can reach the router.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter buildRouter({required bool onboarded}) {
  final shellKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: onboarded ? '/today' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _page(const OnboardingScreen()),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell),
        navigatorContainerBuilder: appBranchContainer,
        branches: [
          StatefulShellBranch(
            navigatorKey: shellKey,
            routes: [
              GoRoute(
                path: '/today',
                pageBuilder: (context, state) => _tab(const TodayScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/linger',
                pageBuilder: (context, state) => _tab(const LingerScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: '/sources',
                pageBuilder: (context, state) => _tab(
                  const WarmTab(branch: 2, slot: 0, child: SourcesScreen()),
                ),
              ),
            ],
          ),
          // Search sits fourth, as the v2 pill draws it.
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: '/search',
                pageBuilder: (context, state) => _tab(
                  const WarmTab(branch: 3, slot: 1, child: SearchScreen()),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: '/more',
                pageBuilder: (context, state) => _tab(
                  const WarmTab(branch: 4, slot: 2, child: MoreScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/reader/:id',
        pageBuilder: (context, state) =>
            _page(ReaderScreen(int.parse(state.pathParameters['id']!))),
      ),
      // A saved article whose row has been pruned or unsubscribed away. Same
      // Reader, reading the bookmark's own snapshot.
      GoRoute(
        path: '/bookmark/:id',
        pageBuilder: (context, state) => _page(
          ReaderScreen(
            null,
            bookmarkId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: '/bookmarks',
        pageBuilder: (context, state) => _page(const BookmarksScreen()),
      ),
      // Placed home screen widgets, and one widget's source choice. The
      // configure activity opens `/widget/:id` as its engine's initial route.
      GoRoute(
        path: '/widget',
        pageBuilder: (context, state) => _page(const WidgetsScreen()),
      ),
      GoRoute(
        path: '/widget/:id',
        pageBuilder: (context, state) =>
            _page(WidgetSourcesScreen(int.parse(state.pathParameters['id']!))),
      ),
      GoRoute(
        path: '/stats',
        pageBuilder: (context, state) => _page(const StatsScreen()),
      ),
      GoRoute(
        path: '/sources/add-url',
        pageBuilder: (context, state) => _page(const AddSourceScreen()),
      ),
      GoRoute(
        path: '/sources/opml',
        pageBuilder: (context, state) => _page(const OpmlImportScreen()),
      ),
      GoRoute(
        path: '/sources/:id',
        pageBuilder: (context, state) =>
            _page(SourceDetailScreen(int.parse(state.pathParameters['id']!))),
      ),
      GoRoute(
        path: '/more/settings',
        pageBuilder: (context, state) => _page(const SettingsScreen()),
      ),
      GoRoute(
        path: '/more/appearance',
        pageBuilder: (context, state) => _page(const AppearanceScreen()),
      ),
      GoRoute(
        path: '/more/header',
        pageBuilder: (context, state) => _page(const HeaderScreen()),
      ),
      GoRoute(
        path: '/more/permissions',
        pageBuilder: (context, state) => _page(const PermissionsScreen()),
      ),
      GoRoute(
        path: '/more/data',
        pageBuilder: (context, state) => _page(const DataScreen()),
      ),
      GoRoute(
        path: '/more/contact',
        pageBuilder: (context, state) => _page(const ContactScreen()),
      ),
      GoRoute(
        path: '/more/privacy',
        pageBuilder: (context, state) => _page(privacyScreen),
      ),
      GoRoute(
        path: '/more/about',
        pageBuilder: (context, state) => _page(const AboutScreen()),
      ),
    ],
  );
}
