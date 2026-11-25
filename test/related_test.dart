import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/related_repository.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/reader/related/other_sources_section.dart';
import 'package:headshorts/features/reader/related/related_matcher.dart';
import 'package:headshorts/features/reader/related/related_provider.dart';

/// "Other sources on this story": the keyword matcher on real headlines, the
/// database lookup around it, and the section that shows the result.
void main() {
  group('matcher on real headlines', () {
    final json = jsonDecode(
      File('test/fixtures/related_titles.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final rows = (json['articles']! as List).cast<Map<String, Object?>>();
    final srcIds = <String, int>{};
    final byKey = <String, RelatedCandidate>{};
    for (final (i, r) in rows.indexed) {
      byKey[r['key']! as String] = RelatedCandidate(
        id: i + 1,
        title: r['title']! as String,
        summary: r['summary']! as String,
        sourceId: srcIds.putIfAbsent(
          r['source']! as String,
          () => srcIds.length,
        ),
        publishedAtMs: DateTime.parse(r['publishedAt']! as String)
            .millisecondsSinceEpoch,
      );
    }
    final pool = byKey.values.toList();
    Set<int> idsFor(String key) => {
      for (final c in relatedMatches(
        RelatedInput(article: byKey[key]!, candidates: pool),
      ))
        c.id,
    };

    test('finds the same story from another publisher, both ways', () {
      for (final pair in (json['matches']! as List).cast<List<Object?>>()) {
        final a = pair[0]! as String;
        final b = pair[1]! as String;
        expect(idsFor(a), contains(byKey[b]!.id), reason: '$a -> $b');
        expect(idsFor(b), contains(byKey[a]!.id), reason: '$b -> $a');
      }
    });

    test('does not match a different story', () {
      for (final pair in (json['nonMatches']! as List).cast<List<Object?>>()) {
        final a = pair[0]! as String;
        final b = pair[1]! as String;
        expect(idsFor(a), isNot(contains(byKey[b]!.id)), reason: '$a -> $b');
      }
    });

    test('matches Hindi headlines', () {
      expect(idsFor('hi_saurav0'), contains(byKey['hi_saurav1']!.id));
    });

    test('never returns the article itself or its own source', () {
      for (final key in byKey.keys) {
        final a = byKey[key]!;
        for (final c in relatedMatches(
          RelatedInput(article: a, candidates: pool),
        )) {
          expect(c.id, isNot(a.id));
          expect(c.sourceId, isNot(a.sourceId));
        }
      }
    });
  });

  group('lookup', () {
    late HsDatabase db;
    late SourceRepository sources;
    late ArticleRepository articles;
    late RelatedRepository related;
    final now = DateTime.now();
    const story = 'Parliament passes sweeping Digital Personal Data Bill';

    setUp(() {
      db = HsDatabase.forTesting(NativeDatabase.memory());
      sources = SourceRepository(db);
      articles = ArticleRepository(db);
      related = RelatedRepository(db);
    });
    tearDown(() => db.close());

    Future<int> source(String name, {String language = 'en'}) => sources.add(
      title: name,
      feedUrl: 'https://$name.example/rss',
      category: 'India',
      language: language,
    );

    Future<int> article(
      int src,
      String title, {
      Duration ago = Duration.zero,
      String? guid,
    }) async {
      final g = guid ?? '${src}_${title.hashCode}';
      await articles.upsert(src, [
        ParsedArticle(
          guid: g,
          title: title,
          link: 'https://example.com/$g',
          publishedAt: now.subtract(ago),
        ),
      ]);
      final row = await (db.select(
        db.articles,
      )..where((a) => a.guid.equals(g))).getSingle();
      return row.id;
    }

    test('matches another source, ignores the same source', () async {
      final a = await source('alpha');
      final b = await source('beta');
      final id = await article(a, story);
      await article(
        b,
        'Digital Personal Data Bill passes Parliament after long debate',
      );
      await article(
        a,
        'Parliament clears Digital Personal Data Bill, sweeping',
      );
      final got = await related.related(id);
      expect(got, hasLength(1));
      expect(got.single.sourceTitle, 'beta');
    });

    test('a different language returns nothing', () async {
      final a = await source('alpha');
      final h = await source('hindi', language: 'hi');
      final id = await article(a, story);
      await article(h, story);
      expect(await related.related(id), isEmpty);
    });

    test('outside 48 hours is excluded, inside is not', () async {
      final a = await source('alpha');
      final b = await source('beta');
      final c = await source('gamma');
      final id = await article(a, story, ago: const Duration(hours: 1));
      await article(b, story, ago: const Duration(hours: 60));
      await article(c, story, ago: const Duration(hours: 30));
      final got = await related.related(id);
      expect(got.map((s) => s.sourceTitle), ['gamma']);
    });

    test('a paused source is not offered', () async {
      final a = await source('alpha');
      final b = await source('beta');
      final id = await article(a, story);
      await article(b, story);
      await sources.setEnabled(b, enabled: false);
      expect(await related.related(id), isEmpty);
    });

    test('at most four, one per source, newest first', () async {
      final a = await source('alpha');
      final id = await article(a, story);
      for (var i = 0; i < 6; i++) {
        final s = await source('pub$i');
        await article(
          s,
          story,
          ago: Duration(hours: i + 1),
          guid: 'p$i',
        );
        if (i == 0) {
          await article(s, '$story, again', ago: const Duration(hours: 9));
        }
      }
      final got = await related.related(id);
      expect(got, hasLength(4));
      expect(got.map((s) => s.sourceTitle).toSet(), hasLength(4));
      final times = got.map((s) => s.publishedAt).toList();
      expect(times, [...times]..sort((x, y) => y.compareTo(x)));
    });

    test('matches Hindi in the same language', () async {
      final a = await source('हिंदी एक', language: 'hi');
      final b = await source('हिंदी दो', language: 'hi');
      final id = await article(
        a,
        'सौरव दास को एयरपोर्ट पर रोका गया, दिपके ने केंद्र को घेरा',
      );
      await article(b, 'एयरपोर्ट पर रोके गए सौरव दास, दिपके ने सरकार को घेरा');
      expect(await related.related(id), hasLength(1));
    });
  });

  group('OtherSourcesSection', () {
    final story = RelatedStory(
      articleId: 42,
      title: 'Parliament passes the Data Bill after a long night',
      sourceTitle: 'The Hindu',
      accentDark: 0xFFE07A5F,
      accentLight: 0xFF8A2F1D,
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

    Future<void> pump(WidgetTester tester, List<RelatedStory> stories) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(
                child: Column(children: [OtherSourcesSection(1)]),
              ),
            ),
          ),
          GoRoute(
            path: '/reader/:id',
            builder: (_, s) => Text('reader ${s.pathParameters['id']}'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [relatedProvider.overrideWith((ref, id) async => stories)],
          child: MaterialApp.router(
            theme: buildHsTheme(HsPalette.amoled),
            routerConfig: router,
          ),
        ),
      );
    }

    testWidgets('takes no height and shows nothing when there are none', (
      tester,
    ) async {
      await pump(tester, const []);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Other sources on this story'), findsNothing);
      expect(tester.getSize(find.byType(OtherSourcesSection)).height, 0);
    });

    testWidgets('waits, then shows heading, rows and the note', (tester) async {
      await pump(tester, [story]);
      expect(
        find.text('Other sources on this story'.toUpperCase()),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('OTHER SOURCES ON THIS STORY'), findsOneWidget);
      expect(find.text(story.title), findsOneWidget);
      expect(find.text('THE HINDU'), findsOneWidget);
      expect(find.textContaining('found by keywords'), findsOneWidget);
    });

    testWidgets('tapping a row opens that article in the Reader', (
      tester,
    ) async {
      await pump(tester, [story]);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text(story.title));
      await tester.pumpAndSettle();
      expect(find.text('reader 42'), findsOneWidget);
    });
  });
}
