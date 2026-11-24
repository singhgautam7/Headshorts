import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/home_widget_bridge.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/app/router.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/feed/refresh_service.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/home_widget/widget_refresh.dart';
import 'package:headshorts/features/home_widget/widget_sources.dart';
import 'package:headshorts/features/home_widget/widget_sources_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('headshorts/widget');

/// Answers by feed address: a list of titles is a fresh feed, null is a
/// failure, and a feed named 'hang' never answers.
class _FakeAdapter implements SourceAdapter {
  final fetched = <String>[];

  @override
  bool canHandle(SourceType type) => true;

  @override
  Future<FetchResult> fetch(SourceRef ref) {
    fetched.add(ref.feedUrl);
    if (ref.feedUrl.contains('hang')) return Completer<FetchResult>().future;
    if (ref.feedUrl.contains('bad')) {
      return Future.value(const FetchResult.failed('nope'));
    }
    return Future.value(
      FetchResult.fresh(
        articles: [
          ParsedArticle(
            guid: ref.feedUrl,
            title: 'Story from ${ref.feedUrl}',
            link: '${ref.feedUrl}/1',
            publishedAt: DateTime.now(),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('WidgetSources', () {
    test('parses and encodes the choice', () {
      expect(WidgetSources.parse(null), isNull);
      expect(WidgetSources.parse('all'), isNull);
      expect(WidgetSources.parse(' '), isNull);
      expect(WidgetSources.parse('3, 1,x,2'), {1, 2, 3});
      expect(WidgetSources.encode(null), 'all');
      expect(WidgetSources.encode({3, 1, 2}), '1,2,3');
      expect(WidgetSources.encode({}), '');
      expect(WidgetSources.key(7), 'widget_sources_7');
    });

    test(
      'round-trips through the shared file under the flutter. prefix',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await WidgetSources.write(prefs, 4, {2, 9});
        expect(await WidgetSources.read(prefs, 4), {2, 9});
        await WidgetSources.write(prefs, 4, null);
        expect(await WidgetSources.read(prefs, 4), isNull);
      },
    );
  });

  group('runWidgetRefresh', () {
    late HsDatabase db;
    late SourceRepository sources;
    late ArticleRepository articles;
    late _FakeAdapter adapter;
    final ids = <String, int>{};

    setUp(() async {
      db = HsDatabase.forTesting(NativeDatabase.memory());
      sources = SourceRepository(db);
      articles = ArticleRepository(db);
      adapter = _FakeAdapter();
      for (final name in ['a', 'b', 'bad', 'hang']) {
        ids[name] = await sources.add(
          title: name,
          feedUrl: 'https://$name.test/rss',
          category: 'News',
        );
      }
    });

    tearDown(() => db.close());

    Future<WidgetRefreshResult> run(Set<int>? only, {Duration? deadline}) =>
        runWidgetRefresh(
          sources: sources,
          articles: articles,
          registry: SourceAdapterRegistry([adapter]),
          ids: only,
          deadline: deadline ?? const Duration(seconds: 5),
        );

    test(
      'refreshes only the chosen sources and counts ok and failed',
      () async {
        final r = await run({ids['a']!, ids['bad']!});
        expect(adapter.fetched.toSet(), {
          'https://a.test/rss',
          'https://bad.test/rss',
        });
        expect((r.ok, r.failed, r.total), (1, 1, 2));
        expect((await db.select(db.articles).get()).length, 1);
      },
    );

    test('null means every enabled source; a paused one is skipped', () async {
      await sources.setEnabled(ids['b']!, enabled: false);
      final r = await run(null, deadline: const Duration(milliseconds: 300));
      expect(adapter.fetched, isNot(contains('https://b.test/rss')));
      expect(r.total, 3);
    });

    test('the overall deadline counts a stalled feed as failed', () async {
      final r = await run({
        ids['a']!,
        ids['hang']!,
      }, deadline: const Duration(milliseconds: 200));
      expect((r.ok, r.failed, r.total), (1, 1, 2));
    });

    test('an empty choice refreshes nothing', () async {
      final r = await run({});
      expect(r.total, 0);
      expect(adapter.fetched, isEmpty);
    });
  });

  group('config screen', () {
    final calls = <MethodCall>[];

    Future<void> pump(WidgetTester tester, List<SourceRow> rows) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'finishConfig';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _channel,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            widgetSourcesProvider.overrideWith((ref) => Stream.value(rows)),
          ],
          child: MaterialApp(
            theme: buildHsTheme(HsPalette.amoled),
            home: const WidgetSourcesScreen(42),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    setUp(() {
      calls.clear();
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('saving a choice writes the key and finishes the config', (
      tester,
    ) async {
      final rows = await tester.runAsync(() async {
        final db = HsDatabase.forTesting(NativeDatabase.memory());
        final repo = SourceRepository(db);
        for (final n in ['One', 'Two']) {
          await repo.add(
            title: n,
            feedUrl: 'https://$n.test',
            category: 'News',
          );
        }
        final all = await repo.all();
        await db.close();
        return all;
      });
      await pump(tester, rows!);

      await tester.tap(find.text('All sources').first);
      await tester.pump();
      // All sources toggled off selects every source; drop the second.
      await tester.tap(find.text('Two'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('widget_sources_42'), '${rows.first.id}');
      expect(calls.map((c) => c.method), contains('finishConfig'));
      expect(calls.firstWhere((c) => c.method == 'finishConfig').arguments, 42);
    });

    testWidgets('no sources shows the note and cannot save', (tester) async {
      await pump(tester, const []);
      expect(find.text('Choose some sources in HeadShorts'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(calls.where((c) => c.method == 'finishConfig'), isEmpty);
    });
  });

  group('bridge', () {
    testWidgets('a widget tap lands on Headlines with the Reader on top', (
      tester,
    ) async {
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/more',
        routes: [
          for (final p in ['/today', '/more', '/reader/:id'])
            GoRoute(
              path: p,
              builder: (context, state) => Text('page $p ${state.uri.path}'),
            ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final found = GoRouter.maybeOf(rootNavigatorKey.currentContext!);
      expect(found, isNotNull);

      openArticleFromWidget(found!, 7, onboarded: false);
      await tester.pumpAndSettle();
      expect(find.text('page /more /more'), findsOneWidget);

      openArticleFromWidget(found, 7, onboarded: true);
      await tester.pumpAndSettle();
      expect(find.text('page /reader/:id /reader/7'), findsOneWidget);

      // Same article again does not stack a second Reader.
      openArticleFromWidget(found, 7, onboarded: true);
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('page /today /today'), findsOneWidget);
    });

    testWidgets(
      'notifies the widgets when a refresh finishes, and routes openArticle',
      (tester) async {
        SharedPreferences.setMockInitialValues({'onboarded': true});
        final prefs = await SharedPreferences.getInstance();
        final calls = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _channel,
          (call) async {
            calls.add(call.method);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            _channel,
            null,
          ),
        );

        final router = GoRouter(
          navigatorKey: rootNavigatorKey,
          initialLocation: '/today',
          routes: [
            for (final p in ['/today', '/reader/:id'])
              GoRoute(
                path: p,
                builder: (context, state) => Text('page ${state.uri.path}'),
              ),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            settingsStoreProvider.overrideWithValue(SettingsStore(prefs)),
            refreshProvider.overrideWith(_FakeRefresh.new),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        container.read(homeWidgetBridgeProvider);
        await tester.pump();
        calls.clear();

        (container.read(refreshProvider.notifier) as _FakeRefresh).emit(
          const RefreshProgress(total: 1, done: 1, added: 0, finished: true),
        );
        await tester.pump();
        expect(calls, contains('update'));

        // Kotlin calls openArticle on a warm start.
        final settings = container.read(settingsStoreProvider).read();
        if (settings.onboarded) {
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'headshorts/widget',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('openArticle', 9),
            ),
            (_) {},
          );
          await tester.pumpAndSettle();
          expect(find.text('page /reader/9'), findsOneWidget);
        }
      },
    );

    test('theme values follow family, mode and true black', () {
      final dark = widgetThemeValues(
        familyId: 'paper',
        mode: ThemeMode.dark,
        amoled: true,
        systemDark: false,
      );
      final light = widgetThemeValues(
        familyId: 'paper',
        mode: ThemeMode.system,
        amoled: true,
        systemDark: false,
      );
      expect(dark['widget_dark'], 1);
      expect(light['widget_dark'], 0);
      expect(dark['widget_bg'], isNot(light['widget_bg']));
      expect(
        dark.keys,
        containsAll(['widget_bg', 'widget_fg', 'widget_fg2', 'widget_accent']),
      );
    });
  });
}

class _FakeRefresh extends RefreshController {
  @override
  RefreshProgress build() => RefreshProgress.idle;

  // ignore: use_setters_to_change_properties -- a test helper that drives state, not a property
  void emit(RefreshProgress p) => state = p;
}
