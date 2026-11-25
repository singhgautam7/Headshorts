import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/shell.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/widgets/nav_pill.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsStore store;
  late GoRouter router;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    router = GoRouter(
      initialLocation: '/today',
      routes: [
        StatefulShellRoute(
          navigatorContainerBuilder: appBranchContainer,
          builder: (context, state, shell) => AppShell(shell),
          branches: [
            // The v2 order, as the board's pill draws it.
            for (final tab in const [
              'today',
              'linger',
              'sources',
              'search',
              'more',
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/$tab',
                    builder: (context, state) => _Page(tab),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(
          theme: buildHsTheme(HsPalette.amoled),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('horizontal fling left switches to next tab', (tester) async {
    await pump(tester);
    expect(router.state.uri.path, '/today');

    // Swipe left (negative dx) moves from Today -> Linger
    await tester.fling(find.byType(AppShell), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/linger');

    // Linger -> Sources
    await tester.fling(find.byType(AppShell), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/sources');

    // Sources -> Search
    await tester.fling(find.byType(AppShell), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/search');

    // Search -> More
    await tester.fling(find.byType(AppShell), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/more');

    // More has no next tab; swiping left stays on More
    await tester.fling(find.byType(AppShell), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/more');
  });

  testWidgets('horizontal fling right switches to previous tab', (
    tester,
  ) async {
    await pump(tester);
    router.go('/more');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/more');

    // Swipe right (positive dx) moves from More -> Search
    await tester.fling(find.byType(AppShell), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/search');

    // Search -> Sources
    await tester.fling(find.byType(AppShell), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/sources');

    // Sources -> Linger
    await tester.fling(find.byType(AppShell), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/linger');

    // Linger -> Today
    await tester.fling(find.byType(AppShell), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/today');

    // Today has no previous tab; swiping right stays on Today
    await tester.fling(find.byType(AppShell), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/today');
  });

  testWidgets('slow drag below velocity threshold does not switch tab', (
    tester,
  ) async {
    await pump(tester);
    expect(router.state.uri.path, '/today');

    // Drag with velocity below 240
    await tester.fling(find.byType(AppShell), const Offset(-300, 0), 100);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/today');
  });

  testWidgets('tapping the active tab scrolls its list to the top', (
    tester,
  ) async {
    router = GoRouter(
      initialLocation: '/sources',
      routes: [
        StatefulShellRoute(
          navigatorContainerBuilder: appBranchContainer,
          builder: (context, state, shell) => AppShell(shell),
          branches: [
            for (final tab in const [
              'today',
              'linger',
              'sources',
              'search',
              'more',
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/$tab',
                    builder: (context, state) => tab == 'sources'
                        ? ListView.builder(
                            itemCount: 100,
                            itemBuilder: (_, i) =>
                                SizedBox(height: 60, child: Text('row $i')),
                          )
                        : _Page(tab),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    await pump(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, greaterThan(500));

    await tester.tap(
      find.descendant(of: find.byType(NavPill), matching: find.text('Sources')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // On its way, not jumped.
    expect(scrollable.position.pixels, greaterThan(0));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 0);
    expect(router.state.uri.path, '/sources');
  });

  testWidgets('a warm tab builds after its idle slot, not before', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: TickerMode(
          enabled: false,
          child: WarmTab(branch: 2, slot: 0, child: Text('built')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('built'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('built'), findsOneWidget);
  });
}

class _Page extends StatelessWidget {
  const new(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Center(child: Text('page:$name'));
}
