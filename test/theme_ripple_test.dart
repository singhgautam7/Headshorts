import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/app/wallpaper_seed.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/theme_ripple.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/theme_family.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/more/appearance_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Spy implements ThemeRippleHandle {
  final taps = <Offset>[];
  @override
  Future<void> run(Offset p, FutureOr<void> Function() apply) async {
    taps.add(p);
    await apply();
  }
}

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    _Spy spy, {
    Color? seed,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(
          SettingsStore(await SharedPreferences.getInstance()),
        ),
        wallpaperSeedProvider.overrideWith((ref) async => seed),
      ],
    );
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: buildHsTheme(HsPalette.amoled),
          home: MotionScope(
            level: MotionLevel.off,
            systemOff: false,
            // The real ThemeRipple needs a snapshot; a spy records the call.
            child: ThemeRippleScope(
              handle: spy,
              child: const Scaffold(body: AppearanceScreen()),
            ),
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

  Future<void> tapText(WidgetTester tester, String text) async {
    await show(tester, text);
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// The toggle of the option card titled [title]; the list is lazy, so the
  /// card is scrolled into being first.
  Future<Finder> toggleOf(WidgetTester tester, String title) async {
    await show(tester, title);
    return find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Row)).at(1),
      matching: find.byType(HsToggle),
    );
  }

  Future<void> tapToggle(WidgetTester tester, String title) async {
    final f = await toggleOf(tester, title);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('every control on the screen goes through the ripple', (
    tester,
  ) async {
    final spy = _Spy();
    final c = await pump(tester, spy, seed: const Color(0xFF2E7D32));
    var taps = 0;
    void expectRipple() => expect(spy.taps, hasLength(++taps));

    await tapToggle(tester, 'Expressive colours');
    expectRipple();
    expect(c.read(settingsProvider).expressiveColors, isFalse);

    await tapToggle(tester, 'Pure black');
    expectRipple();
    expect(c.read(settingsProvider).amoled, isFalse);

    await tapToggle(tester, 'From your wallpaper');
    expectRipple();
    expect(c.read(settingsProvider).wallpaperColor, isTrue);

    await tapText(tester, 'Light');
    expectRipple();
    expect(c.read(settingsProvider).themeMode, ThemeMode.light);
    await tapText(tester, 'Dark');
    expectRipple();
    await tapText(tester, 'System');
    expectRipple();

    // A family card, which also turns the wallpaper colour back off.
    await tapText(tester, ThemeFamily.all.last.name);
    expectRipple();
    expect(c.read(settingsProvider).familyId, ThemeFamily.all.last.id);
    expect(c.read(settingsProvider).wallpaperColor, isFalse);
  });

  testWidgets('the ripple starts where the finger went down', (tester) async {
    final spy = _Spy();
    await pump(tester, spy);
    final at = tester.getCenter(find.text('Light'));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(spy.taps.single, at);
  });

  testWidgets('motion and haptics rows live in More, not on this screen', (
    tester,
  ) async {
    await pump(tester, _Spy());
    expect(find.text('Haptics'), findsNothing);
    expect(find.text('Motion'), findsNothing);
    expect(find.text('Blur behind the nav'), findsNothing);
  });
}
