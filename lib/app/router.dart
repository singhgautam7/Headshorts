import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/shell.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/features/linger/linger_screen.dart';
import 'package:headshorts/features/more/ai_summaries_screen.dart';
import 'package:headshorts/features/more/info_screens.dart';
import 'package:headshorts/features/more/more_screen.dart';
import 'package:headshorts/features/onboarding/onboarding_screen.dart';
import 'package:headshorts/features/reader/reader_screen.dart';
import 'package:headshorts/features/sources/add_source_screen.dart';
import 'package:headshorts/features/sources/opml_import_screen.dart';
import 'package:headshorts/features/sources/source_detail_screen.dart';
import 'package:headshorts/features/sources/sources_screen.dart';
import 'package:headshorts/features/sources/starter_set_screen.dart';
import 'package:headshorts/features/stats/stats_screen.dart';
import 'package:headshorts/features/today/today_screen.dart';

/// A page that slides in on motion-page, the app's one push transition.
CustomTransitionPage<void> _page(Widget child) => CustomTransitionPage<void>(
  child: child,
  transitionsBuilder: (context, animation, _, child) => SlideTransition(
    position: Tween(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: HsMotion.pageCurve)),
    child: FadeTransition(opacity: animation, child: child),
  ),
);

/// Tab switches cross-fade rather than slide — there is no left or right
/// relationship between destinations.
CustomTransitionPage<void> _tab(Widget child) => CustomTransitionPage<void>(
  child: child,
  transitionsBuilder: (context, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
);

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
        path: '/sources/add',
        pageBuilder: (context, state) => _page(const AddSourceScreen()),
      ),
      GoRoute(
        path: '/sources/opml',
        pageBuilder: (context, state) => _page(const OpmlImportScreen()),
      ),
      GoRoute(
        path: '/sources/starter',
        pageBuilder: (context, state) => _page(const StarterSetScreen()),
      ),
      GoRoute(
        path: '/sources/:id',
        pageBuilder: (context, state) =>
            _page(SourceDetailScreen(int.parse(state.pathParameters['id']!))),
      ),
      GoRoute(
        path: '/more/ai',
        pageBuilder: (context, state) => _page(const AiSummariesScreen()),
      ),
      GoRoute(
        path: '/more/text-size',
        pageBuilder: (context, state) => _page(const TextSizeScreen()),
      ),
      GoRoute(
        path: '/more/privacy',
        pageBuilder: (context, state) => _page(privacyScreen),
      ),
      GoRoute(
        path: '/more/about',
        pageBuilder: (context, state) => _page(aboutScreen),
      ),
    ],
  );
}
