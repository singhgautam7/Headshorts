// Perf harness. Rerun recipe: specs/kuber-parity/performance.md.
//
// Frame numbers are the engine's own FrameTiming, windowed by Timeline.now.
// Run `python3 tool/feed_server.py` on the host first. Pass
// `--dart-define=SCENARIO=away` for the 30-day-absence run.
import 'dart:async';
import 'dart:developer' show Timeline;
import 'dart:io' show ProcessInfo;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/app.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/core/widgets/nav_pill.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/bookmarks/bookmarks_screen.dart';
import 'package:headshorts/features/linger/linger_screen.dart';
import 'package:headshorts/features/more/more_screen.dart';
import 'package:headshorts/features/reader/reader_screen.dart';
import 'package:headshorts/features/search/search_screen.dart';
import 'package:headshorts/features/sources/sources_screen.dart';
import 'package:headshorts/features/today/today_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_seed.dart';

const scenario = String.fromEnvironment('SCENARIO', defaultValue: 'main');

final results = <String, dynamic>{};

double pct(List<double> v, double p) {
  if (v.isEmpty) return -1;
  final s = [...v]..sort();
  return s[((s.length - 1) * p).round()];
}

double r1(num v) => (v * 10).roundToDouble() / 10;

class Frames {
  final all = <FrameTiming>[];
  void start() => SchedulerBinding.instance.addTimingsCallback(all.addAll);

  Map<String, dynamic> stats(int t0, int t1) {
    final f = all.where((t) {
      final b = t.timestampInMicroseconds(FramePhase.buildStart);
      return b >= t0 && b <= t1;
    }).toList();
    final build = [for (final t in f) t.buildDuration.inMicroseconds / 1000];
    final raster = [for (final t in f) t.rasterDuration.inMicroseconds / 1000];
    return {
      'frames': f.length,
      'build_p50': r1(pct(build, .5)),
      'build_p90': r1(pct(build, .9)),
      'build_worst': r1(pct(build, 1)),
      'raster_p50': r1(pct(raster, .5)),
      'raster_p90': r1(pct(raster, .9)),
      'raster_worst': r1(pct(raster, 1)),
      'build_over16': build.where((b) => b > 16).length,
      'raster_over16': raster.where((b) => b > 16).length,
    };
  }
}

Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

Future<int> until(Finder f, {int timeoutMs = 20000}) async {
  final sw = Stopwatch()..start();
  while (f.evaluate().isEmpty) {
    if (sw.elapsedMilliseconds > timeoutMs) return -1;
    await wait(4);
  }
  return sw.elapsedMilliseconds;
}

const tabNames = ['today', 'linger', 'sources', 'search', 'more'];
const tabTypes = <Type>[
  TodayScreen,
  LingerScreen,
  SourcesScreen,
  SearchScreen,
  MoreScreen,
];

Finder navItem(int i) => find.descendant(
  of: find.byType(NavPill),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        w.properties.label == NavPill.destinationsForApp[i].label,
  ),
);

Finder listIn(Type screen) => find
    .descendant(
      of: find.byType(screen),
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    )
    .first;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.reportData = {'results': results};

  testWidgets('perf', (tester) async {
    final frames = Frames()..start();
    Future<Map<String, dynamic>> window(Future<void> Function() body) async {
      final t0 = Timeline.now;
      await body();
      final t1 = Timeline.now;
      await wait(1200);
      return frames.stats(t0, t1);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    final db = HsDatabase();
    final now = DateTime.now();
    final away = scenario.startsWith('away');
    final newest = away ? now.subtract(const Duration(days: 30)) : now;
    final seedSw = Stopwatch()..start();
    await seedPerf(
      db,
      newest: newest,
      fetchedAt: newest,
      // A few dead and stalled feeds among the good ones when coming back.
      feedUrl: !away
          ? null
          : (s) => switch (s) {
              7 => '$perfHost/slow/7.xml',
              11 => '$perfHost/error/11.xml',
              15 => '$perfHost/empty/15.xml',
              19 => '$perfHost/bad/19.xml',
              23 => '$perfHost/huge/23.xml',
              _ =>
                scenario == 'away_offline'
                    ? 'http://10.0.2.2:9/feed/$s.xml'
                    : '$perfHost/feed/$s.xml',
            },
    );
    results['scenario'] = scenario;
    results['seed_ms'] = seedSw.elapsedMilliseconds;

    Future<int> countArticles() async => (await db
            .customSelect('SELECT count(*) AS c FROM articles')
            .getSingle())
        .read<int>('c');
    Future<int> dbBytes() async {
      final p = await db.customSelect('PRAGMA page_count').getSingle();
      final s = await db.customSelect('PRAGMA page_size').getSingle();
      return p.read<int>('page_count') * s.read<int>('page_size');
    }

    results['articles_before'] = await countArticles();
    results['db_bytes_before'] = await dbBytes();

    Widget app() => ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore(prefs)),
        databaseProvider.overrideWithValue(db),
      ],
      child: const HeadShortsApp(),
    );

    final card = find.byType(CustomScrollView);

    if (away) {
      // ---- coming back after 30 days, with the list being scrolled
      final sw = Stopwatch()..start();
      final t0 = Timeline.now;
      var peak = 0;
      runApp(UncontrolledHost(child: app()));
      await until(find.byType(TodayScreen));
      await until(card);
      results['ms_to_content'] = sw.elapsedMilliseconds;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TodayScreen)),
      );
      final trace = <String>[];
      var flashes = 0;
      var jumps = 0;
      double? last;
      var ticks = 0;
      while (!container.read(refreshProvider).finished &&
          sw.elapsedMilliseconds < 120000) {
        await wait(100);
        ticks++;
        if (find.byType(HeadlineSkeleton).evaluate().isNotEmpty) flashes++;
        final s = listIn(TodayScreen);
        if (s.evaluate().isNotEmpty) {
          final pos = tester.state<ScrollableState>(s).position;
          if (last != null && (pos.pixels - last).abs() > 2) jumps++;
          if (ticks == 8) pos.jumpTo(600.0.clamp(0, pos.maxScrollExtent));
          last = pos.pixels;
        }
        if (ProcessInfo.currentRss > peak) peak = ProcessInfo.currentRss;
        final p = container.read(refreshProvider);
        trace.add('${sw.elapsedMilliseconds}ms ${p.done}/${p.total}');
      }
      results['refresh_ms'] = sw.elapsedMilliseconds;
      final t1 = Timeline.now;
      await wait(1500);
      results['catch_up_frames'] = frames.stats(t0, t1);
      results['skeleton_ticks'] = flashes;
      results['position_jumps'] = jumps;
      results['peak_rss_mb'] = peak ~/ 1048576;
      results['added'] = container.read(refreshProvider).added;
      results['articles_after'] = await countArticles();
      results['db_bytes_after'] = await dbBytes();
      results['bookmarks_after'] = (await db
              .customSelect(
                'SELECT count(*) AS c FROM articles WHERE link IN (SELECT link FROM bookmarks)',
              )
              .getSingle())
          .read<int>('c');
      results['trace'] = [
        for (var i = 0; i < trace.length; i += 10) trace[i],
      ];
      return;
    }

    // ---- first frame of every tab
    final first = <String, dynamic>{};
    var bootMs = -1;
    first['today'] = await window(() async {
      final sw = Stopwatch()..start();
      runApp(UncontrolledHost(child: app()));
      await until(card);
      bootMs = sw.elapsedMilliseconds;
      await wait(1500);
    });
    (first['today'] as Map)['ms_to_screen'] = bootMs;
    await wait(2500);
    for (var i = 1; i < 5; i++) {
      var ms = -1;
      final s = await window(() async {
        await tester.tap(navItem(i));
        ms = await until(find.byType(tabTypes[i]).hitTestable());
        await wait(700);
      });
      s['ms_to_screen'] = ms;
      first[tabNames[i]] = s;
      await tester.tap(navItem(0));
      await wait(800);
    }
    results['first_open'] = first;

    // ---- every ordered pair of tabs, warm
    final pairs = <String, dynamic>{};
    for (var a = 0; a < 5; a++) {
      for (var b = 0; b < 5; b++) {
        if (a == b) continue;
        await tester.tap(navItem(a));
        await wait(700);
        pairs['${tabNames[a]}>${tabNames[b]}'] = await window(() async {
          await tester.tap(navItem(b));
          await wait(500);
        });
      }
    }
    results['tab_switch'] = pairs;

    // ---- scrolling
    var flashes = 0;
    var resets = 0;
    Future<Map<String, dynamic>> fling(
      Finder f, {
      int n = 6,
      double d = 600,
    }) => window(() async {
      for (final sign in [-1.0, 1.0]) {
        for (var i = 0; i < n; i++) {
          final before = f.evaluate().isEmpty
              ? 0.0
              : tester.state<ScrollableState>(f).position.pixels;
          await tester.fling(f, Offset(0, sign * d), 3000);
          for (var k = 0; k < 40; k++) {
            await wait(16);
            if (find.byType(HeadlineSkeleton).hitTestable().evaluate().isNotEmpty) {
              flashes++;
            }
          }
          if (sign < 0 && f.evaluate().isNotEmpty) {
            final after = tester.state<ScrollableState>(f).position.pixels;
            if (after < before - 50) resets++;
          }
        }
      }
    });

    final scroll = <String, dynamic>{};
    results['rss_mb_before_scroll'] = ProcessInfo.currentRss ~/ 1048576;
    await tester.tap(navItem(0));
    await wait(800);
    scroll['today'] = await fling(listIn(TodayScreen), n: 10);
    results['today_skeleton_flash_ticks'] = flashes;
    results['today_position_resets'] = resets;
    results['rss_mb_after_scroll'] = ProcessInfo.currentRss ~/ 1048576;
    results['image_cache_mb'] =
        PaintingBinding.instance.imageCache.currentSizeBytes ~/ 1048576;
    await tester.tap(navItem(2));
    await wait(800);
    scroll['sources'] = await fling(listIn(SourcesScreen));
    await tester.tap(navItem(3));
    await wait(800);
    await tester.enterText(find.byType(EditableText).first, 'riv');
    await wait(2500);
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(600);
    scroll['search'] = await fling(listIn(SearchScreen));
    final router = GoRouter.of(tester.element(find.byType(NavPill)));
    unawaited(router.push('/bookmarks'));
    await until(find.byType(BookmarksScreen));
    await wait(900);
    scroll['bookmarks'] = await fling(listIn(BookmarksScreen), n: 4);
    router.pop();
    await wait(700);

    // ---- articles: cached long bodies (1, 9, 17), extracted ones (2, 3)
    await tester.tap(navItem(0));
    await wait(800);
    final reader = <String, dynamic>{};
    for (final id in [1, 9, 17, 2, 3]) {
      reader['open_$id'] = await window(() async {
        unawaited(router.push('/reader/$id'));
        await until(find.byType(ReaderScreen));
        await wait(1800);
      });
      reader['scroll_$id'] = await fling(listIn(ReaderScreen), n: 5, d: 800);
      reader['back_$id'] = await window(() async {
        router.pop();
        await wait(700);
      });
    }
    results['reader'] = reader;

    // ---- menus and sheets, five opens each
    final menus = <String, dynamic>{};
    Future<void> sheet(String name, Finder open) async {
      if (open.evaluate().isEmpty) {
        menus[name] = 'not found';
        return;
      }
      menus[name] = await window(() async {
        for (var i = 0; i < 5; i++) {
          await tester.tap(open.first);
          await wait(700);
          await tester.tapAt(const Offset(20, 60));
          await wait(600);
        }
      });
    }

    await sheet('filter_sheet', find.bySemanticsLabel('Filter headlines'));
    await sheet('list_size_menu', find.byTooltip('Change view'));
    await tester.tap(navItem(4));
    await wait(800);
    await sheet('option_sheet', find.text('Text size'));

    // ---- a refresh of every source while the reader scrolls
    await tester.tap(navItem(0));
    await wait(800);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
    );
    flashes = 0;
    Future<void> refreshAndScroll() async {
      final done = container.read(refreshProvider.notifier).refresh();
      var finished = false;
      unawaited(done.then((_) => finished = true));
      final sw = Stopwatch()..start();
      while (!finished && sw.elapsedMilliseconds < 60000) {
        await tester.fling(listIn(TodayScreen), const Offset(0, -300), 1500);
        await wait(250);
        await tester.fling(listIn(TodayScreen), const Offset(0, 200), 1500);
        await wait(250);
      }
      results['refresh_ms'] = sw.elapsedMilliseconds;
    }

    scroll['today_during_refresh'] = await window(refreshAndScroll);
    results['refresh_skeleton_ticks'] = flashes;
    results['scroll'] = scroll;
    results['menus'] = menus;

    // ---- rebuild counts
    widgets.debugProfileBuildsEnabled = true;
    await binding.traceAction(() async {
      for (final i in [2, 3, 4, 1, 0]) {
        await tester.tap(navItem(i));
        await wait(600);
      }
    }, reportKey: 'rebuilds_tab_switch');
    await binding.traceAction(() async {
      for (var i = 0; i < 3; i++) {
        await tester.fling(listIn(TodayScreen), const Offset(0, -600), 3000);
        await wait(600);
      }
    }, reportKey: 'rebuilds_scroll');
    await binding.traceAction(refreshAndScroll, reportKey: 'rebuilds_refresh');
    widgets.debugProfileBuildsEnabled = false;
    await wait(2000);
  }, semanticsEnabled: false, timeout: const Timeout(Duration(minutes: 20)));
}

/// `runApp` outside `pumpWidget`, so the app owns the frames.
class UncontrolledHost extends StatelessWidget {
  const UncontrolledHost({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
