import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/app/wallpaper_seed.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/theme_family.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/more/appearance_screen.dart';
import 'package:headshorts/features/more/family_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    double scale = 1,
    Size size = const Size(360, 640),
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(
          SettingsStore(await SharedPreferences.getInstance()),
        ),
        wallpaperSeedProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: buildHsTheme(HsPalette.amoled),
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.only(top: 32, bottom: 24),
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: const MotionScope(
            level: MotionLevel.off,
            systemOff: false,
            child: Scaffold(body: AppearanceScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  /// The list is lazy: back to the top, then down to [text].
  Future<void> show(WidgetTester tester, String text) async {
    await tester.drag(find.byType(ListView), const Offset(0, 5000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(text), 300);
  }

  /// The toggle of the option card titled [title], scrolled into being (the
  /// list is lazy).
  Future<HsToggle> toggle(WidgetTester tester, String title) async {
    await show(tester, title);
    return tester.widget<HsToggle>(
      find.descendant(
        of: find
            .ancestor(of: find.text(title), matching: find.byType(Row))
            .at(1),
        matching: find.byType(HsToggle),
      ),
    );
  }

  testWidgets('titled Theme; Signature is selected by default', (tester) async {
    await pump(tester);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Expressive colours'), findsOneWidget);
    expect(find.text('Pure black'), findsOneWidget);
    final selected = tester
        .widgetList<FamilyCard>(find.byType(FamilyCard, skipOffstage: false))
        .where((f) => f.selected)
        .toList();
    expect(selected.single.family, ThemeFamily.signature);
    expect(ThemeFamily.all.length, 18);
  });

  testWidgets('a stored unknown family shows Signature selected', (
    tester,
  ) async {
    await pump(tester, prefs: {'familyId': 'retired'});
    final selected = tester
        .widgetList<FamilyCard>(find.byType(FamilyCard, skipOffstage: false))
        .where((f) => f.selected);
    expect(selected.single.family, ThemeFamily.signature);
  });

  testWidgets('pure black is dimmed and refuses taps in light mode', (
    tester,
  ) async {
    final c = await pump(tester, prefs: {'themeMode': 'light'});
    expect((await toggle(tester, 'Pure black')).onChanged, isNull);
    final before = c.read(settingsProvider).amoled;
    await tester.tap(find.text('Pure black'), warnIfMissed: false);
    await tester.tap(find.byType(HsToggle).at(1), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).amoled, before);
    final dim = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.text('Pure black'),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(dim.opacity, 0.38);
    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('Pure black, not available in light mode'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('pure black is live in dark, and System explains it', (
    tester,
  ) async {
    await pump(tester, prefs: {'themeMode': 'system'});
    expect(
      find.text('Pure black applies when your phone is in dark mode'),
      findsOneWidget,
    );
    expect((await toggle(tester, 'Pure black')).onChanged, isNotNull);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      find.text('Pure black applies when your phone is in dark mode'),
      findsNothing,
    );
  });

  testWidgets('the wallpaper row is off without a seed', (tester) async {
    await pump(tester);
    expect((await toggle(tester, 'From your wallpaper')).onChanged, isNull);
  });

  testWidgets('the preview shows the sample card', (tester) async {
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Outlined'), 300);
    expect(find.text('The news, and then it ends.'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
  });

  testWidgets('survives text scale 2.0 on 360x640 in every mode', (
    tester,
  ) async {
    for (final mode in ['light', 'dark', 'system']) {
      await pump(tester, prefs: {'themeMode': mode}, scale: 2);
      await tester.scrollUntilVisible(
        find.text('Outlined'),
        400,
        maxScrolls: 200,
      );
      expect(tester.takeException(), isNull, reason: mode);
    }
  });
}
