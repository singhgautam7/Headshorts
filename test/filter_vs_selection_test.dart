import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/today/today_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home's "All sources" control is a **filter**: it hides items from the list
/// in front of the reader and touches nothing else. Subscription lives in
/// Sources. These tests hold that line, because the two look alike on screen
/// and conflating them would quietly unsubscribe people.
void main() {
  late HsDatabase db;
  late SourceRepository sources;
  late ArticleRepository articles;
  late ProviderContainer container;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    db = HsDatabase.forTesting(NativeDatabase.memory());
    sources = SourceRepository(db);
    articles = ArticleRepository(db);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        settingsStoreProvider.overrideWithValue(
          SettingsStore(await SharedPreferences.getInstance()),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() => db.close());

  /// Reads the briefing through the providers, holding a listener so the
  /// stream stays alive long enough to emit.
  Future<List<Headline>> briefing() async {
    final subscription = container.listen(briefingProvider, (_, _) {});
    try {
      return await container.read(briefingProvider.future);
    } finally {
      subscription.close();
    }
  }

  Future<int> seed(String title, String category, String word) async {
    final id = await sources.add(
      title: title,
      feedUrl: 'https://example.com/${title.toLowerCase()}',
      category: category,
    );
    await articles.upsert(id, [
      ParsedArticle(
        guid: '$title-1',
        title: '$word dispatch concerning $category matters today',
        link: 'https://example.com/${title.toLowerCase()}/1',
        publishedAt: DateTime(2026, 9, 8, 12),
      ),
    ]);
    return id;
  }

  test('hiding a source in Home does not unsubscribe it', () async {
    final bbc = await seed('BBC', 'World', 'monsoon');
    await seed('Hindu', 'India', 'glacier');

    container.read(mutedSourcesProvider.notifier).toggle(bbc, visible: false);

    // Gone from the list…
    expect((await briefing()).map((h) => h.source.title), ['Hindu']);

    // …but still subscribed, still enabled, still fetched.
    final row = (await sources.all()).firstWhere((s) => s.id == bbc);
    expect(row.enabled, isTrue);
    expect((await sources.enabled()).map((s) => s.id), contains(bbc));
  });

  test('hiding a source in Home does not remove its category', () async {
    final bbc = await seed('BBC', 'World', 'monsoon');
    await seed('Hindu', 'India', 'glacier');

    container.read(mutedSourcesProvider.notifier).toggle(bbc, visible: false);

    // Categories follow subscriptions, not the view filter.
    expect(
      await sources.watchCategories().first,
      unorderedEquals(['World', 'India']),
    );
  });

  test('the filter is per-view and resets, unlike a subscription', () async {
    final bbc = await seed('BBC', 'World', 'monsoon');
    final muted = container.read(mutedSourcesProvider.notifier)
      ..toggle(bbc, visible: false);
    expect(container.read(mutedSourcesProvider), contains(bbc));

    muted.showAll();

    expect(container.read(mutedSourcesProvider), isEmpty);
    expect(await briefing(), hasLength(1));
  });

  test('muting in Latest is a subscription setting, and persists', () async {
    // Distinct from the Home filter: this one lives on the source row.
    final firehose = await seed('Firehose', 'World', 'monsoon');
    await sources.setMutedInLatest(firehose, muted: true);

    expect(await articles.watchBriefing().first, isEmpty);
    expect(
      await articles.watchBriefing(category: 'World').first,
      hasLength(1),
      reason: 'muting applies to Latest only',
    );
    expect((await sources.all()).single.enabled, isTrue);
  });

  test('subscribing makes a new category appear', () async {
    await seed('Hindu', 'India', 'glacier');
    expect(await sources.watchCategories().first, ['India']);

    await seed('Verge', 'Technology', 'satellite');

    expect(
      await sources.watchCategories().first,
      unorderedEquals(['India', 'Technology']),
    );
  });

  test('recategorising moves a source between categories, live', () async {
    final id = await seed('Hindu', 'India', 'glacier');
    await sources.setCategory(id, 'Asia');

    expect(await sources.watchCategories().first, ['Asia']);
    expect(await articles.watchBriefing(category: 'Asia').first, hasLength(1));
    expect(await articles.watchBriefing(category: 'India').first, isEmpty);
  });
}
