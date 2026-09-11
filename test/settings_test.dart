import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsStore', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    Future<SettingsStore> store() async =>
        SettingsStore(await SharedPreferences.getInstance());

    test('defaults are the calm ones', () async {
      final settings = (await store()).read();

      expect(settings.theme, HsThemeChoice.amoled);
      expect(settings.blurBehindNav, isFalse);
      expect(settings.linkOpenMode, LinkOpenMode.inApp);
      expect(settings.refreshCadence, RefreshCadence.hourly);
      expect(
        settings.maxConsecutivePerSource,
        0,
        reason: 'strictly chronological unless asked otherwise',
      );
    });

    test('round-trips every field', () async {
      final written = await store();
      const settings = Settings(
        theme: HsThemeChoice.white,
        blurBehindNav: true,
        textSize: TextSizeStep.large,
        onboarded: true,
        linkOpenMode: LinkOpenMode.browser,
        refreshCadence: RefreshCadence.daily,
        maxConsecutivePerSource: 5,
      );
      await written.write(settings);

      final read = (await store()).read();
      expect(read.theme, HsThemeChoice.white);
      expect(read.blurBehindNav, isTrue);
      expect(read.textSize, TextSizeStep.large);
      expect(read.onboarded, isTrue);
      expect(read.linkOpenMode, LinkOpenMode.browser);
      expect(read.refreshCadence, RefreshCadence.daily);
      expect(read.maxConsecutivePerSource, 5);
    });

    test('survives a value it does not recognise', () async {
      SharedPreferences.setMockInitialValues({
        'refreshCadence': 'fortnightly',
        'linkOpenMode': 'carrier-pigeon',
      });

      final settings = (await store()).read();
      expect(settings.refreshCadence, RefreshCadence.hourly);
      expect(settings.linkOpenMode, LinkOpenMode.inApp);
    });
  });

  group('refresh cadence', () {
    test('manual has no interval, so nothing is ever due', () {
      expect(RefreshCadence.manual.interval, isNull);
    });

    test('the others are ordered shortest first', () {
      final intervals = RefreshCadence.values
          .map((c) => c.interval)
          .whereType<Duration>()
          .toList();
      expect(intervals, [
        const Duration(hours: 1),
        const Duration(hours: 4),
        const Duration(days: 1),
      ]);
    });
  });

  group('clearCache', () {
    late HsDatabase db;

    setUp(() => db = HsDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('empties articles and read events, keeping subscriptions', () async {
      final sources = SourceRepository(db);
      final articles = ArticleRepository(db);
      final id = await sources.add(
        title: 'One',
        feedUrl: 'https://example.com/feed',
        category: 'World',
      );
      await articles.upsert(id, [
        ParsedArticle(
          guid: 'a',
          title: 'A headline that will not survive the cache being cleared',
          link: 'https://example.com/a',
          publishedAt: DateTime(2026, 9, 8),
        ),
      ]);
      final article = (await db.select(db.articles).get()).single;
      await articles.mark(article.id, mode: ReadMode.full);

      await db.clearCache();

      expect(await db.select(db.articles).get(), isEmpty);
      expect(await db.select(db.readEvents).get(), isEmpty);
      expect(
        await sources.all(),
        hasLength(1),
        reason: 'clearing the cache is not unsubscribing',
      );
      expect((await sources.all()).single.category, 'World');
    });
  });
}
