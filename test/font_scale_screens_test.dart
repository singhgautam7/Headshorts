import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/bookmark_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/feed/refresh_service.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/bookmarks/bookmarks_screen.dart';
import 'package:headshorts/features/linger/linger_filter_sheet.dart';
import 'package:headshorts/features/onboarding/onboarding_screen.dart';
import 'package:headshorts/features/search/date_range_sheet.dart';
import 'package:headshorts/features/search/search_scope_sheet.dart';
import 'package:headshorts/features/search/search_screen.dart';
import 'package:headshorts/features/sources/add_source_screen.dart';
import 'package:headshorts/features/sources/opml_import_screen.dart';
import 'package:headshorts/features/sources/source_detail_screen.dart';
import 'package:headshorts/features/sources/sources_screen.dart';
import 'package:headshorts/features/today/source_filter_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdleRefresh extends RefreshController {
  @override
  RefreshProgress build() => RefreshProgress.idle;

  @override
  Future<void> refreshIfDue() async {}

  @override
  Future<void> refresh() async {}
}

/// Every screen this file owns, at the largest system font on a small phone
/// with a tall status bar and a gesture inset: nothing may overflow.
void main() {
  late HsDatabase db;
  late SettingsStore store;
  late int sourceId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    // No Google News request from a widget test.
    await store.write(store.read().copyWith(searchTheWeb: false));

    db = HsDatabase.forTesting(NativeDatabase.memory());
    final sources = SourceRepository(db);
    sourceId = await sources.add(
      title: 'A Rather Long Publisher Name Indeed',
      feedUrl: 'https://example.com/tech',
      category: 'Technology and Science',
    );
    final worldId = await sources.add(
      title: 'World Daily',
      feedUrl: 'https://example.com/world',
      category: 'World',
    );
    await ArticleRepository(db).upsert(sourceId, [
      ParsedArticle(
        guid: 'a',
        title: 'A distinct headline about harbours and tides',
        link: 'https://example.com/a',
        publishedAt: DateTime.now(),
      ),
    ]);
    // Every source has something cached, so Search never goes to the network.
    await ArticleRepository(db).upsert(worldId, [
      ParsedArticle(
        guid: 'w',
        title: 'Elsewhere, a quite different story about lighthouses',
        link: 'https://example.com/w',
        publishedAt: DateTime.now(),
      ),
    ]);
    final article = await db.select(db.articles).get().then((r) => r.first);
    final source = await db.select(db.sources).get();
    await BookmarkRepository(db)
        .save(Headline(article, source.firstWhere((s) => s.id == sourceId)));
  });

  tearDown(() => db.close());

  /// Fails with the whole render-error report, not just its first line.
  void noOverflow(WidgetTester t) {
    final e = t.takeException();
    if (e == null) return;
    fail(e is FlutterError ? e.toStringDeep() : '$e');
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      debugPrint(d.toString());
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          databaseProvider.overrideWithValue(db),
          refreshProvider.overrideWith(_IdleRefresh.new),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
            padding: EdgeInsets.only(top: 32, bottom: 24),
          ),
          child: MaterialApp(
            theme: buildHsTheme(HsPalette.amoled),
            home: Scaffold(
              backgroundColor: HsPalette.amoled.background,
              body: screen,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    noOverflow(tester);
  }

  /// A sheet is opened from a button so it sits on the real root navigator.
  Future<void> pumpSheet(
    WidgetTester tester,
    Future<void> Function(BuildContext) open,
  ) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    noOverflow(tester);
  }

  /// Unmounts and lets drift's stream cleanup timers run.
  Future<void> unmount(WidgetTester t) async {
    noOverflow(t);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 100));
  }

  void screen(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (t) async {
        await body(t);
        await unmount(t);
      });

  screen('Headlines filter sheet', (t) => pumpSheet(t, showSourceFilterSheet));
  screen('Linger filter sheet', (t) => pumpSheet(t, showLingerFilterSheet));
  screen('Search scope sheet', (t) => pumpSheet(t, showSearchScopeSheet));
  screen('Date range sheet', (t) => pumpSheet(t, showDateRangeSheet));

  screen('Search, empty', (t) => pump(t, const SearchScreen()));

  screen('Search, with results', (t) async {
    await pump(t, const SearchScreen());
    await t.enterText(find.byType(EditableText), 'harbours');
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    noOverflow(t);
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  screen('Sources', (t) => pump(t, const SourcesScreen()));
  screen('Source detail', (t) => pump(t, SourceDetailScreen(sourceId)));
  screen('Add source', (t) => pump(t, const AddSourceScreen()));
  screen('OPML import', (t) => pump(t, const OpmlImportScreen()));
  screen('Bookmarks', (t) => pump(t, const BookmarksScreen()));

  screen('Onboarding: pages, setup and picker', (t) async {
    await pump(t, const OnboardingScreen());
    // Three feature pages, then the setup page: each at the largest font.
    for (var i = 0; i < 3; i++) {
      noOverflow(t);
      expect(find.text('Next'), findsOneWidget);
      await t.tap(find.text('Next'));
      for (var j = 0; j < 10; j++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }
    noOverflow(t);
    expect(find.text('Make it yours'), findsOneWidget);
    await t.tap(find.text('Choose your sources'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    noOverflow(t);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  screen('Onboarding: first fetch', (t) => pump(t, const InitialFetch()));
}
