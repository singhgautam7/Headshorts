import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/router.dart';
import 'package:headshorts/app/shell.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/sources/sources_screen.dart';
import 'package:headshorts/features/stats/stats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stats' "Review" button used to `push('/sources')`, which mounts a second
/// copy of the whole shell on top of the root navigator. It has to `go`.
void main() {
  late HsDatabase db;
  late GoRouter router;
  late SettingsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    db = HsDatabase.forTesting(NativeDatabase.memory());
    final id = await SourceRepository(db).add(
      title: 'Quiet Feed',
      feedUrl: 'https://example.com/feed',
      category: 'World',
    );
    await ArticleRepository(db).upsert(id, [
      ParsedArticle(
        guid: 'a',
        title: 'A distinct headline about harbours',
        link: 'https://example.com/a',
        publishedAt: DateTime.now(),
      ),
    ]);
    // Fetched a moment ago, so nothing is due and no real request starts.
    await db
        .update(db.sources)
        .write(SourcesCompanion(lastFetchedAt: Value(DateTime.now())));
    router = buildRouter(onboarded: true);
  });

  tearDown(() async {
    router.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(
          theme: buildHsTheme(HsPalette.amoled),
          routerConfig: router,
          builder: (_, child) => Material(child: child),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // Drift's stream teardown leaves zero-length timers; unmount and flush.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> review(WidgetTester tester) async {
    router.go('/more');
    await settle(tester);
    unawaited(router.push<void>('/stats'));
    await settle(tester);
    expect(find.byType(StatsScreen), findsOneWidget);
    final button = find.textContaining('Review the one you never open');
    // Mid-screen: the floating header covers the top edge of a short phone.
    await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(button);
    await settle(tester);
  }

  testWidgets('Review lands on the one Sources tab, not a second shell', (
    tester,
  ) async {
    await pump(tester);
    await review(tester);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(SourcesScreen), findsOneWidget);
    expect(find.byType(StatsScreen), findsNothing);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/sources');
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/today');
    expect(find.byType(AppShell), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('works a second time and across a rotation', (tester) async {
    await pump(tester);
    await review(tester);
    await tester.binding.setSurfaceSize(const Size(800, 390));
    await settle(tester);
    expect(find.byType(AppShell), findsOneWidget);
    await review(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(SourcesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  test('nothing in lib/ pushes a tab route', () {
    final bad = RegExp(
      r'''push(<[^>]*>)?\(\s*['"]/(today|linger|sources|search|more)['"]\s*\)''',
    );
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (bad.hasMatch(f.readAsStringSync())) hits.add(f.path);
    }
    expect(hits, isEmpty, reason: 'use go(), a tab is not a pushed page');
  });
}
