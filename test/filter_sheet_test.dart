import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/today/source_filter_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The filter sheet's chips wear the shared dress: stadium when off, a 12 dp
/// squircle when on, and the gap between rows equals the gap across a row
/// even though each chip carries a 48 dp hit region around a 32 dp visual.
void main() {
  late HsDatabase db;
  late SettingsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    db = HsDatabase.forTesting(NativeDatabase.memory());
    final sources = SourceRepository(db);
    for (var i = 0; i < 10; i++) {
      await sources.add(
        title: 'Pub $i',
        feedUrl: 'https://example.com/$i',
        category: i.isEven ? 'World' : 'Technology',
      );
    }
  });

  tearDown(() => db.close());

  Future<void> openSheet(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: buildHsTheme(HsPalette.amoled),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSourceFilterSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  ShapeBorder? shapeOf(WidgetTester tester, String label) {
    final material = find.descendant(
      of: find.widgetWithText(HsChip, label),
      matching: find.byType(Material),
    );
    return tester.widget<Material>(material.first).shape;
  }

  testWidgets('selected is a squircle, unselected a stadium', (tester) async {
    await openSheet(tester);
    expect(shapeOf(tester, 'Technology'), isA<StadiumBorder>());

    await tester.tap(find.widgetWithText(HsChip, 'Technology'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final shape = shapeOf(tester, 'Technology');
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.all(Radius.circular(HsRadius.squircle)),
    );
    expect(shapeOf(tester, 'World'), isA<StadiumBorder>());
    await close(tester);
  });

  testWidgets('the gap down equals the gap across', (tester) async {
    await openSheet(tester);
    final rects = [
      for (final e in find.byType(HsChip).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    // The source tags are the chips wide enough to wrap.
    final tags = rects.where((r) => r.top > rects.first.bottom).toList();
    expect(tags.length, greaterThan(3));

    final across = <double>[];
    final down = <double>[];
    for (var i = 1; i < tags.length; i++) {
      final a = tags[i - 1];
      final b = tags[i];
      if ((a.top - b.top).abs() < 1) {
        across.add(b.left - a.right);
      } else if (b.top - a.bottom < HsSize.tapTarget) {
        // The hit region carries (48 - 32) / 2 above and below the visual.
        down.add(b.top - a.bottom + (HsSize.tapTarget - HsSize.chipVisual));
      }
    }
    expect(across, isNotEmpty);
    expect(down, isNotEmpty, reason: 'the tags should wrap at 360 wide');
    for (final gap in down) {
      expect(gap, closeTo(across.first, 0.01));
    }
    for (final gap in across) {
      expect(gap, closeTo(across.first, 0.01));
    }
    await close(tester);
  });
}
