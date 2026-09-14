import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/feed/refresh_service.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/today/today_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRefreshController extends RefreshController {
  @override
  RefreshProgress build() => RefreshProgress.idle;

  @override
  Future<void> refreshIfDue() async {}

  @override
  Future<void> refresh() async {}
}

void main() {
  late HsDatabase db;
  late SourceRepository sources;
  late ArticleRepository articles;
  late SettingsStore store;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = SettingsStore(prefs);

    db = HsDatabase.forTesting(NativeDatabase.memory());
    sources = SourceRepository(db);
    articles = ArticleRepository(db);

    final techId = await sources.add(
      title: 'Hacker News',
      feedUrl: 'https://example.com/tech',
      category: 'Tech',
    );
    final worldId = await sources.add(
      title: 'BBC World',
      feedUrl: 'https://example.com/world',
      category: 'World',
    );

    await articles.upsert(techId, [
      ParsedArticle(
        guid: 'hn-1',
        title: 'First Tech Story Here',
        link: 'https://example.com/story/1',
        publishedAt: DateTime(2026, 9, 8, 12),
        contentSnippet: 'Brief tech snippet.',
      ),
    ]);
    await articles.upsert(worldId, [
      ParsedArticle(
        guid: 'bbc-1',
        title: 'First World Story Here',
        link: 'https://example.com/story/2',
        publishedAt: DateTime(2026, 9, 8, 11),
        contentSnippet: 'Brief world snippet.',
      ),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'Headlines renders single Latest list with Filter button and no top category tabs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(372, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(store),
            databaseProvider.overrideWithValue(db),
            sourceRepositoryProvider.overrideWithValue(sources),
            articleRepositoryProvider.overrideWithValue(articles),
            refreshProvider.overrideWith(_FakeRefreshController.new),
          ],
          child: MaterialApp(
            theme: buildHsTheme(HsPalette.amoled),
            home: const Scaffold(
              backgroundColor: Color(0xFF000000),
              body: TodayScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Screen title is Headlines
      expect(find.text('Headlines'), findsOneWidget);

      // The filter pill button exists and says "Filter"
      expect(find.text('Filter'), findsOneWidget);

      // Both articles from all categories are in the single Latest list
      expect(find.text('First Tech Story Here'), findsOneWidget);
      expect(find.text('First World Story Here'), findsOneWidget);

      // Open the Filter sheet
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();

      // Sheet displays Category
      expect(find.text('CATEGORY'), findsOneWidget);

      // Select 'Tech' category chip in the sheet
      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();

      // Tap 'Apply'
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Filter button now reflects category scope
      expect(find.text('Filter · Tech'), findsOneWidget);
      // Tech story is visible, World story is excluded by category filter
      expect(find.text('First Tech Story Here'), findsOneWidget);
      expect(find.text('First World Story Here'), findsNothing);

      // Open the Filter sheet again and tap Clear filter
      await tester.tap(find.text('Filter · Tech'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear filter'));
      await tester.pumpAndSettle();

      // Reverts to All (Latest) and button says Filter
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('First Tech Story Here'), findsOneWidget);
      expect(find.text('First World Story Here'), findsOneWidget);

      // Cleanly unmount widget tree and flush any drift query stream timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
