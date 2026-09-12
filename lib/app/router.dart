import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/shell.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/features/linger/linger_screen.dart';
import 'package:headshorts/features/more/ai_summaries_screen.dart';
import 'package:headshorts/features/more/info_screens.dart';
import 'package:headshorts/features/more/more_screen.dart';
import 'package:headshorts/features/more/settings_screen.dart';
import 'package:headshorts/features/onboarding/onboarding_screen.dart';
import 'package:headshorts/features/reader/reader_screen.dart';
import 'package:headshorts/features/sources/add_source_screen.dart';
import 'package:headshorts/features/sources/opml_import_screen.dart';
import 'package:headshorts/features/sources/source_detail_screen.dart';
import 'package:headshorts/features/sources/sources_screen.dart';
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
/// relationship between destinations. The fade lives in [_BranchSwitcher];
/// the branch's own route does not animate on top of it.
NoTransitionPage<void> _tab(Widget child) =>
    NoTransitionPage<void>(child: child);

/// Holds every branch alive and cross-fades between them on motion-page.
///
/// `StatefulShellRoute.indexedStack` swaps branches instantly, so a page
/// transition on the branch route never plays. Building the container here
/// keeps each branch's navigator and scroll position exactly as the indexed
/// stack would, and animates the swap.
class _BranchSwitcher extends StatelessWidget {
  const new({required this.index, required this.branches});

  final int index;
  final List<Widget> branches;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      for (var i = 0; i < branches.length; i++)
        // Prevent background focus traversal into hidden branches (e.g. search field in Sources)
        Focus(
          canRequestFocus: i == index,
          skipTraversal: i != index,
          descendantsAreFocusable: i == index,
          child: RepaintBoundary(
            child: AnimatedSlide(
              offset: i == index
                  ? Offset.zero
                  : Offset((i - index).sign * 0.08, 0),
              duration: HsMotion.page,
              curve: HsMotion.pageCurve,
              child: AnimatedOpacity(
                opacity: i == index ? 1 : 0,
                duration: HsMotion.page,
                curve: HsMotion.pageCurve,
                child: IgnorePointer(
                  // The outgoing branch stays mounted, and so keeps its state, but
                  // must not be touchable, tick, or be read out once it is off.
                  ignoring: i != index,
                  child: TickerMode(
                    enabled: i == index,
                    child: ExcludeSemantics(
                      excluding: i != index,
                      child: branches[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

GoRouter buildRouter({required bool onboarded}) {
  final shellKey = GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: onboarded ? '/today' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _page(const OnboardingScreen()),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell),
        // An IndexedStack swaps branches with no transition at all, so a page
        // animation on the branch routes never plays. Building the container
        // ourselves keeps every branch alive and cross-fades between them.
        navigatorContainerBuilder: (context, shell, children) =>
            _BranchSwitcher(index: shell.currentIndex, branches: children),
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
        path: '/more/settings',
        pageBuilder: (context, state) => _page(const SettingsScreen()),
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
