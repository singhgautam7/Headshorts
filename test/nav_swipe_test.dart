import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/shell.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
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
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell),
          branches: [
            for (final tab in const ['today', 'linger', 'sources', 'more'])
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

    // Sources -> More
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

    // Swipe right (positive dx) moves from More -> Sources
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
}

class _Page extends StatelessWidget {
  const new(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Center(child: Text('page:$name'));
}
