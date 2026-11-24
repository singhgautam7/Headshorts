import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/motion/pressable.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/more/more_screen.dart';
import 'package:headshorts/features/more/stats_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HsDatabase db;
  late SettingsStore store;
  late GoRouter router;
  var statsOpened = 0;

  setUp(() async {
    statsOpened = 0;
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    db = HsDatabase.forTesting(NativeDatabase.memory());
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MoreScreen()),
        GoRoute(
          path: '/stats',
          builder: (_, _) {
            statsOpened++;
            return const Scaffold(body: Text('stats page'));
          },
        ),
      ],
    );
  });

  tearDown(() async {
    router.dispose();
    await db.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 900),
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          databaseProvider.overrideWithValue(db),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: MaterialApp.router(
            theme: buildHsTheme(HsPalette.amoled),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // Drift's stream teardown leaves zero-length timers; unmount and flush
    // before the binding checks for them.
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('stats card leads, there is no Stats row', (tester) async {
    await pump(tester);
    expect(find.byType(StatsCard), findsOneWidget);
    expect(find.text('Nothing read yet'), findsOneWidget);
    // The card is the only "Stats" label; no settings row carries it.
    expect(
      find.descendant(
        of: find.byType(SettingsRow),
        matching: find.text('Stats'),
      ),
      findsNothing,
    );
    final cardTop = tester.getTopLeft(find.byType(StatsCard)).dy;
    final firstRowTop = tester.getTopLeft(find.byType(SettingsRow).first).dy;
    expect(cardTop, lessThan(firstRowTop));
    await unmount(tester);
  });

  testWidgets('every row has an icon and a subtitle under the title', (
    tester,
  ) async {
    await pump(tester);
    final rows = find.byType(SettingsRow);
    expect(rows, findsWidgets);
    for (final e in rows.evaluate()) {
      final row = e.widget as SettingsRow;
      expect(row.icon, isNotNull, reason: row.label);
      expect(row.value ?? row.sub, isNotNull, reason: row.label);
      final title = find.descendant(
        of: find.byWidget(row),
        matching: find.text(row.label),
      );
      final sub = find.descendant(
        of: find.byWidget(row),
        matching: find.text((row.value ?? row.sub)!),
      );
      expect(title, findsOneWidget);
      expect(sub, findsOneWidget);
      expect(
        tester.getTopLeft(sub).dx,
        tester.getTopLeft(title).dx,
        reason: '${row.label}: subtitle aligns with title',
      );
      expect(
        tester.getTopLeft(sub).dy,
        greaterThan(tester.getTopLeft(title).dy),
        reason: '${row.label}: subtitle below title',
      );
      expect(
        find.ancestor(of: find.byWidget(row), matching: find.byType(Pressable)),
        findsNothing,
      );
    }
    // Tappable rows are rows of the kit's Pressable.
    final pressables = tester
        .widgetList<Pressable>(find.byType(Pressable))
        .where((p) => p.kind == PressKind.row);
    expect(pressables, isNotEmpty);
    await unmount(tester);
  });

  testWidgets('tapping the card pushes /stats', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(StatsCard));
    await tester.pump(const Duration(milliseconds: 500));
    expect(statsOpened, 1);
    await unmount(tester);
  });

  testWidgets('renders at 2.0 text scale on 360x640 without overflow', (
    tester,
  ) async {
    await pump(tester, size: const Size(360, 640), textScale: 2);
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a read event rebuilds the card, not the rows', (tester) async {
    final sources = SourceRepository(db);
    final id = await sources.add(
      title: 'Feed',
      feedUrl: 'https://example.com/f',
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
    await pump(tester);

    var rowBuilds = 0;
    var cardBuilds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is SettingsRow) rowBuilds++;
      if (element.widget is StatsCard) cardBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);

    await tester.runAsync(() async {
      final articleId = (await db.select(db.articles).get()).single.id;
      await db
          .into(db.readEvents)
          .insert(
            ReadEventsCompanion.insert(
              articleId: articleId,
              mode: ReadMode.full,
              dwellMs: const Value(5 * 60000),
            ),
          );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('5 min'), findsOneWidget);
    expect(cardBuilds, greaterThan(0));
    expect(rowBuilds, 0);
    debugOnRebuildDirtyWidget = previous;
    await unmount(tester);
  });
}
