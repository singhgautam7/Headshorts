import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/search/search_controller.dart';
import 'package:headshorts/features/search/search_screen.dart';
import 'package:headshorts/features/today/headline_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What Search shows while it is working.
///
/// A search can go to the network — a source with nothing cached is fetched
/// on the spot — so the wait is real and has to be drawn. Every wait in this
/// app is a skeleton; a screen that draws nothing reads as a freeze.
void main() {
  late SettingsStore store;
  late HsDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    // The screen's scope reads the source list, so it needs a database. An
    // in-memory one keeps the test off the disk.
    db = HsDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  SearchHit hit(String title) => SearchHit(
    view: ArticleView(
      sourceTitle: 'BBC News',
      accent: const SourceAccent(Color(0xFFE39191), Color(0xFF9C3A3C)),
      title: title,
      publishedAt: DateTime.now(),
    ),
    link: 'https://example.com/a',
  );

  // Keyed on the query, because that is what the real provider watches: a
  // new query is a *reload*, which is the case `skipLoadingOnReload: false`
  // is there for. A builder rather than a future, so an error future is
  // never created outside the provider and left unhandled.
  late Future<SearchOutcome> Function(String query) outcome;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required Future<SearchOutcome> Function(String query) result,
    String query = 'court',
  }) async {
    outcome = result;
    await tester.binding.setSurfaceSize(const Size(372, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      // Riverpod retries a failed provider on a backoff timer. Useful in the
      // app — a search that failed on a flaky connection tries again — and
      // in a test it is a pending timer the binding rightly objects to.
      retry: (_, _) => null,
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWithValue(db),
        searchResultsProvider.overrideWith(
          (ref) => outcome(ref.watch(searchQueryProvider)),
        ),
      ],
    );
    addTearDown(container.dispose);

    // A query, so the screen is past its empty state and actually searching.
    container.read(searchQueryProvider.notifier).set(query);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildHsTheme(HsPalette.amoled),
          // The field is a Material TextField, as it is in the app.
          home: const Scaffold(body: SearchScreen()),
        ),
      ),
    );
    return container;
  }

  testWidgets('a search in flight draws the skeleton', (tester) async {
    final pending = Completer<SearchOutcome>();
    await pump(tester, result: (_) => pending.future);
    await tester.pump();

    expect(
      find.byType(HeadlineSkeleton),
      findsWidgets,
      reason: 'the wait is drawn, not left blank',
    );
    expect(find.textContaining('results'), findsNothing);

    pending.complete(
      SearchOutcome(hits: [hit('A court ruling')], sourcesSearched: 6),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HeadlineSkeleton), findsNothing);
    expect(find.text('A court ruling'), findsOneWidget);
    expect(find.textContaining('1 result'), findsOneWidget);
  });

  testWidgets('the skeleton returns when the query changes', (tester) async {
    // `skipLoadingOnReload: false`: a second search is a new wait, and
    // leaving the previous results up would read as results for the new
    // query. This is what makes a fetch visible rather than a frozen list.
    final first = Completer<SearchOutcome>();
    final second = Completer<SearchOutcome>();
    final container = await pump(
      tester,
      result: (query) => query == 'court' ? first.future : second.future,
    );
    first.complete(
      SearchOutcome(hits: [hit('A court ruling')], sourcesSearched: 6),
    );
    await tester.pumpAndSettle();
    expect(find.text('A court ruling'), findsOneWidget);

    // A new query: the provider reloads, and the wait starts again.
    container.read(searchQueryProvider.notifier).set('ruling');
    await tester.pump();

    expect(find.byType(HeadlineSkeleton), findsWidgets);
    expect(find.text('A court ruling'), findsNothing);

    second.complete(
      SearchOutcome(hits: [hit('A second ruling')], sourcesSearched: 6),
    );
    await tester.pumpAndSettle();
    expect(find.text('A second ruling'), findsOneWidget);
  });

  testWidgets('the count at the top and the total at the end agree', (
    tester,
  ) async {
    // Two different totals on one screen read as a bug, and did: the footer
    // counted the reader's own hits while the header counted the web group
    // too.
    final done = Completer<SearchOutcome>();
    await pump(tester, result: (_) => done.future);
    done.complete(
      SearchOutcome(
        hits: [hit('A court ruling'), hit('Another ruling')],
        webHits: [hit('A ruling from the web')],
        sourcesSearched: 6,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('3 results'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('That is all'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('That is all 3'), findsOneWidget);
    expect(find.textContaining('and Google News'), findsOneWidget);
  });

  testWidgets("web-only results say the reader's own sources found none", (
    tester,
  ) async {
    // Otherwise the first hint is the heading further down, with a stretch of
    // empty screen above it that reads as a rendering fault.
    final done = Completer<SearchOutcome>();
    await pump(tester, result: (_) => done.future);
    done.complete(
      SearchOutcome(
        hits: const [],
        webHits: [hit('A ruling from the web')],
        sourcesSearched: 6,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing from your 6 sources.'), findsOneWidget);
    expect(find.text('A ruling from the web'), findsOneWidget);
    expect(
      find.textContaining('Nothing for'),
      findsNothing,
      reason: 'the web found something, so this is not an empty search',
    );
  });

  testWidgets('"See why?" explains it rather than leaving them guessing', (
    tester,
  ) async {
    // The same publishers appear in the Google group below, so an empty
    // result from the reader's own copy of them reads as a broken app. The
    // answer is offered where the question gets asked.
    final done = Completer<SearchOutcome>();
    await pump(tester, result: (_) => done.future);
    done.complete(
      SearchOutcome(
        hits: const [],
        webHits: [hit('A ruling from the web')],
        sourcesSearched: 6,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('See why?'));
    await tester.pumpAndSettle();

    expect(find.text('Why your sources found nothing'), findsOneWidget);
  });

  testWidgets('that line stays away when the reader has their own results', (
    tester,
  ) async {
    final done = Completer<SearchOutcome>();
    await pump(tester, result: (_) => done.future);
    done.complete(
      SearchOutcome(
        hits: [hit('A court ruling')],
        webHits: [hit('A ruling from the web')],
        sourcesSearched: 6,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing from your'), findsNothing);
  });

  group('the Google News caveat', () {
    // It used to sit under the "From Google News" heading, over the results.
    // That is both the wrong moment — the term has already been sent — and a
    // wall of small print between the count and the first result.
    testWidgets('is stated before the search, not over the results', (
      tester,
    ) async {
      await pump(
        tester,
        result: (_) => Completer<SearchOutcome>().future,
        query: '',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Google News is searched as well'),
        findsOneWidget,
      );
      expect(
        find.textContaining('search term is sent to Google'),
        findsOneWidget,
        reason: 'the one thing that leaves the device is still said plainly',
      );
    });

    testWidgets('is absent when the setting is off', (tester) async {
      final container = await pump(
        tester,
        result: (_) => Completer<SearchOutcome>().future,
        query: '',
      );
      // Through the controller, which is what the setting row calls.
      await container
          .read(settingsProvider.notifier)
          .setSearchTheWeb(enabled: false);
      await tester.pumpAndSettle();

      expect(find.textContaining('Google News'), findsNothing);
    });

    testWidgets('the heading over the group carries no paragraph', (
      tester,
    ) async {
      final done = Completer<SearchOutcome>();
      await pump(tester, result: (_) => done.future);
      done.complete(
        SearchOutcome(
          hits: [hit('A court ruling')],
          webHits: [hit('A ruling from the web')],
          sourcesSearched: 6,
        ),
      );
      await tester.pumpAndSettle();

      // SectionLabel raises the case; the group is still announced.
      expect(find.text('FROM GOOGLE NEWS'), findsOneWidget);
      expect(find.textContaining('nothing else was'), findsNothing);
    });
  });

  testWidgets('a search that fails says so rather than spinning', (
    tester,
  ) async {
    final failing = Completer<SearchOutcome>();
    await pump(tester, result: (_) => failing.future);
    await tester.pump();
    expect(find.byType(HeadlineSkeleton), findsWidgets);

    failing.completeError(Exception('no network'));
    await tester.pumpAndSettle();

    expect(
      find.byType(HeadlineSkeleton),
      findsNothing,
      reason: 'a failure ends the wait rather than spinning on',
    );
    expect(find.textContaining('Nothing for'), findsOneWidget);
  });
}
