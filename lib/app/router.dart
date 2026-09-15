import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/shell.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/features/linger/linger_screen.dart';
import 'package:headshorts/features/more/about_screen.dart';
import 'package:headshorts/features/more/appearance_screen.dart';
import 'package:headshorts/features/more/data_screen.dart';
import 'package:headshorts/features/more/info_screens.dart';
import 'package:headshorts/features/more/more_screen.dart';
import 'package:headshorts/features/more/permissions_screen.dart';
import 'package:headshorts/features/onboarding/onboarding_screen.dart';
import 'package:headshorts/features/reader/reader_screen.dart';
import 'package:headshorts/features/sources/add_source_screen.dart';
import 'package:headshorts/features/sources/opml_import_screen.dart';
import 'package:headshorts/features/sources/source_detail_screen.dart';
import 'package:headshorts/features/sources/sources_screen.dart';
import 'package:headshorts/features/stats/stats_screen.dart';
import 'package:headshorts/features/today/today_screen.dart';

/// A page that slides in on motion-page, the app's one push transition. The
/// pop plays the same animation backwards on the same clock, so back never
/// feels like a different gesture from forward.
CustomTransitionPage<void> _page(Widget child) => CustomTransitionPage<void>(
  child: child,
  transitionDuration: HsMotion.page,
  reverseTransitionDuration: HsMotion.page,
  transitionsBuilder: (context, animation, _, child) {
    final fade = FadeTransition(opacity: animation, child: child);
    if (HsMotion.reduced(context)) return fade;
    return SlideTransition(
      position: Tween(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: HsMotion.pageCurve)),
      child: fade,
    );
  },
);

/// Tab switches animate directionally in [AppShell] using FractionalTranslation.
/// The branch's own route does not animate on top of it.
NoTransitionPage<void> _tab(Widget child) =>
    NoTransitionPage<void>(child: child);

GoRouter buildRouter({required bool onboarded}) {
  final shellKey = GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: onboarded ? '/today' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _page(const OnboardingScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell),
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
            routes: [
              GoRoute(
                path: '/sources',
                pageBuilder: (context, state) => _tab(const SourcesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                pageBuilder: (context, state) => _tab(const MoreScreen()),
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
        path: '/more/appearance',
        pageBuilder: (context, state) => _page(const AppearanceScreen()),
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
