import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/source_adapter.dart';
import 'package:headshorts/features/more/more_screen.dart';
import 'package:headshorts/features/more/settings_screen.dart';
import 'package:headshorts/features/more/stats_card.dart';
import 'package:headshorts/features/reader/text_size_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HsDatabase db;
  late SettingsStore store;
  late GoRouter router;
  var statsOpened = 0;
  final opened = <String>[];

  setUp(() async {
    statsOpened = 0;
    opened.clear();
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    db = HsDatabase.forTesting(NativeDatabase.memory());
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MoreScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        for (final path in ['/more/settings'])
          GoRoute(
            path: path,
            builder: (_, _) {
              opened.add(path);
              return const Scaffold(body: Text('pushed page'));
            },
          ),
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
    bool disableAnimations = false,
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
            disableAnimations: disableAnimations,
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

  /// Row labels by group, in the order the screen draws them.
  const groups = {
    'SAVED': ['Bookmarks'],
    'MANAGE': ['Data', 'Permissions'],
    'ABOUT HEADSHORTS': ['Settings', 'Contact us', 'Privacy', 'About'],
  };

  testWidgets('three groups in order, each with its rows in order', (
    tester,
  ) async {
    await pump(tester, size: const Size(390, 3200));
    var lastGroup = -1.0;
    for (final MapEntry(key: group, value: labels) in groups.entries) {
      final y = tester.getTopLeft(find.text(group)).dy;
      expect(y, greaterThan(lastGroup), reason: group);
      lastGroup = y;
      var lastRow = y;
      for (final label in labels) {
        final row = find.widgetWithText(SettingsRow, label);
        expect(row, findsOneWidget, reason: label);
        final rowY = tester.getTopLeft(row).dy;
        expect(rowY, greaterThan(lastRow), reason: '$group: $label');
        lastRow = rowY;
      }
      lastGroup = lastRow;
    }
    // There is no General group any more.
    expect(find.text('GENERAL'), findsNothing);
    await unmount(tester);
  });

  testWidgets('no two neighbouring rows share an icon', (tester) async {
    await pump(tester, size: const Size(390, 3200));
    for (final labels in groups.values) {
      IconData? last;
      for (final label in labels) {
        final icon = tester
            .widget<SettingsRow>(find.widgetWithText(SettingsRow, label))
            .icon;
        expect(icon, isNotNull, reason: label);
        expect(icon, isNot(last), reason: label);
        last = icon;
      }
    }
    await unmount(tester);
  });

  testWidgets('settings are behind their own row, not on More', (tester) async {
    await pump(tester, size: const Size(390, 3200));
    for (final label in ['Theme', 'Text size', 'Open links', 'Haptics']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    await tester.tap(find.widgetWithText(SettingsRow, 'Settings'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opened, ['/more/settings']);
    await unmount(tester);
  });

  group('Settings', () {
    const settings = {
      'LOOK': ['Theme', 'Header', 'Text size', 'List size'],
      'READING': [
        'Open links',
        'Read aloud',
        'Reading fairness',
        'Search the web',
      ],
      'PHONE': ['Haptics', 'Home screen widget'],
    };

    Future<void> open(WidgetTester tester, {double textScale = 1}) async {
      router.go('/settings');
      await pump(
        tester,
        size: textScale == 1 ? const Size(390, 2400) : const Size(360, 640),
        textScale: textScale,
      );
    }

    testWidgets('every row is there once, and the removed ones are not', (
      tester,
    ) async {
      await open(tester);
      for (final labels in settings.values) {
        IconData? last;
        for (final label in labels) {
          final row = find.widgetWithText(SettingsRow, label);
          expect(row, findsOneWidget, reason: label);
          final icon = tester.widget<SettingsRow>(row).icon;
          expect(icon, isNot(last), reason: label);
          last = icon;
        }
      }
      for (final gone in ['Motion', 'Blur behind the nav', 'Check for new']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      await unmount(tester);
    });

    testWidgets('Haptics is a switch: the whole row taps once', (tester) async {
      await open(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      final before = container.read(settingsProvider).haptics;
      await tester.tap(find.text('Haptics'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(settingsProvider).haptics, !before);
      await tester.tap(find.byType(HsToggle).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(settingsProvider).haptics, before);
      await unmount(tester);
    });

    testWidgets('Text size opens the same slider the Reader has', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Text size'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(TextSizeSlider), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      await tester.tapAt(
        tester.getCenter(find.byType(TextSizeSlider)) + const Offset(70, 0),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        container.read(settingsProvider).textSize.index,
        greaterThan(TextSizeStep.small.index),
      );
      await unmount(tester);
    });

    testWidgets('renders at 2.0 on 360x640', (tester) async {
      await open(tester, textScale: 2);
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
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
