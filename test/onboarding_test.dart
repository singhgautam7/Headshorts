import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/theme_ripple.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/feed/refresh_service.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdleRefresh extends RefreshController {
  @override
  RefreshProgress build() => RefreshProgress.idle;

  @override
  Future<void> refreshIfDue() async {}

  @override
  Future<void> refresh() async {}
}

class _Spy implements ThemeRippleHandle {
  final taps = <Offset>[];
  @override
  Future<void> run(Offset p, FutureOr<void> Function() apply) async {
    taps.add(p);
    await apply();
  }
}

void main() {
  late HsDatabase db;
  late SettingsStore store;
  late ProviderContainer container;
  late _Spy spy;

  /// Layout is only meaningful in the real faces: the test default (Ahem) is
  /// a square glyph and wraps everything about twice as much.
  setUpAll(() async {
    for (final (family, asset) in [
      ('SourceSerif4', 'assets/fonts/SourceSerif4.ttf'),
      ('Archivo', 'assets/fonts/Archivo.ttf'),
    ]) {
      final loader = FontLoader(family)..addFont(rootBundle.load(asset));
      await loader.load();
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    db = HsDatabase.forTesting(NativeDatabase.memory());
    spy = _Spy();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWithValue(db),
        refreshProvider.overrideWith(_IdleRefresh.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    MotionLevel level = MotionLevel.off,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 640),
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(top: 32, bottom: 24),
          ),
          child: MaterialApp(
            theme: buildHsTheme(HsPalette.amoled),
            home: MotionScope(
              level: level,
              systemOff: false,
              child: ThemeRippleScope(
                handle: spy,
                child: const Scaffold(body: OnboardingScreen()),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await settle(tester);
  }

  testWidgets('three pages, then setup, then the picker', (tester) async {
    await pump(tester);
    expect(find.text('A briefing that ends.'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Import OPML'), findsOneWidget);

    await tapText(tester, 'Next');
    expect(find.text('Two ways to read'), findsOneWidget);
    expect(find.text('Import OPML').hitTestable(), findsNothing);

    await tapText(tester, 'Next');
    expect(find.text('Yours, on your phone'), findsOneWidget);

    await tapText(tester, 'Next');
    expect(find.text('Make it yours'), findsOneWidget);
    // Setup is the last page: no Skip, and the primary moves on.
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Next'), findsNothing);

    await tapText(tester, 'Back');
    expect(find.text('Yours, on your phone'), findsOneWidget);
    await tapText(tester, 'Next');

    await tapText(tester, 'Choose your sources');
    expect(find.text('Continue'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Skip goes to the setup page', (tester) async {
    await pump(tester);
    await tapText(tester, 'Skip');
    expect(find.text('Make it yours'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await unmount(tester);
  });

  testWidgets('the setup page changes the mode through the ripple', (
    tester,
  ) async {
    await pump(tester);
    await tapText(tester, 'Skip');
    await tester.tap(find.text('Light'));
    await settle(tester);
    expect(spy.taps, hasLength(1));
    expect(container.read(settingsProvider).themeMode, ThemeMode.light);
    // The ripple grows from where the finger went down, not from the origin.
    expect(spy.taps.single, isNot(Offset.zero));
    await unmount(tester);
  });

  testWidgets('Android back steps back a page, and out of the picker', (
    tester,
  ) async {
    await pump(tester);
    await tapText(tester, 'Next');
    await tapText(tester, 'Next');
    expect(find.text('Yours, on your phone'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Two ways to read'), findsOneWidget);

    await tapText(tester, 'Skip');
    await tapText(tester, 'Choose your sources');
    expect(find.text('Continue'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Make it yours'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('every page fits a 360x640 phone without scrolling', (
    tester,
  ) async {
    await pump(tester);
    for (var i = 0; i < 4; i++) {
      final scroll = find.descendant(
        of: find.byType(SingleChildScrollView).at(0),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll.first).position;
      expect(position.maxScrollExtent, 0, reason: 'page ${i + 1}');
      if (i < 3) await tapText(tester, 'Next');
    }
    await unmount(tester);
  });

  testWidgets('the largest font scrolls instead of overflowing', (
    tester,
  ) async {
    await pump(tester, scale: 2);
    for (var i = 0; i < 4; i++) {
      expect(tester.takeException(), isNull, reason: 'page ${i + 1}');
      // Labels are whole: nothing is cut to an ellipsis or clipped away.
      for (final label in ['Back', 'Next', 'Choose your sources']) {
        for (final e in find.text(label).evaluate()) {
          final r = e.renderObject! as RenderParagraph;
          expect(r.didExceedMaxLines, isFalse, reason: label);
        }
      }
      if (i < 3) await tapText(tester, 'Next');
    }
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('at Expressive the pager animates to the next page', (
    tester,
  ) async {
    await pump(tester, level: MotionLevel.expressive);
    await tester.tap(find.text('Next'));
    // The first frame only starts the clock.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Mid-slide: both pages are on stage side by side.
    expect(find.text('A briefing that ends.'), findsOneWidget);
    expect(find.text('Two ways to read'), findsOneWidget);
    await settle(tester);
    expect(find.text('A briefing that ends.'), findsNothing);
    await unmount(tester);
  });
}
