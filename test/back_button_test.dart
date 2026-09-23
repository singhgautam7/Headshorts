import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/shell.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android back, as the app's shell handles it.
///
/// The real router's branches need a database; this one wires the real
/// [AppShell] to four plain pages and one pushed detail, which is the whole
/// of what back has to decide between.
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
        GoRoute(
          path: '/detail',
          builder: (context, state) => const _Page('detail'),
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

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Finder page(String name) => find.text('page:$name', skipOffstage: false);

  testWidgets('back from every other tab lands on Headlines', (tester) async {
    await pump(tester);
    for (final tab in const ['linger', 'sources', 'search', 'more']) {
      router.go('/$tab');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/$tab');

      await back(tester);
      expect(router.state.uri.path, '/today', reason: 'back from $tab');
    }
  });

  testWidgets('a pushed detail pops first, then the tab', (tester) async {
    await pump(tester);
    router.go('/sources');
    unawaited(router.push('/detail'));
    await tester.pumpAndSettle();
    expect(page('detail'), findsOneWidget);

    await back(tester);
    expect(page('detail'), findsNothing);
    expect(router.state.uri.path, '/sources');

    await back(tester);
    expect(router.state.uri.path, '/today');
  });

  testWidgets('a sheet closes first, and the tab stays', (tester) async {
    await pump(tester);
    router.go('/more');
    await tester.pumpAndSettle();

    final context = tester.element(page('more'));
    unawaited(showHsSheet<void>(context, (_) => const Text('sheet body')));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsOneWidget);

    await back(tester);
    expect(find.text('sheet body'), findsNothing);
    expect(router.state.uri.path, '/more');
  });

  testWidgets('on Headlines the press is left to the platform', (tester) async {
    await pump(tester);
    // Nothing to pop: the shell must not swallow the event, or the app can
    // never be left with the back button.
    expect(await tester.binding.handlePopRoute(), isFalse);
  });
}

class _Page extends StatelessWidget {
  const new(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Center(child: Text('page:$name'));
}
