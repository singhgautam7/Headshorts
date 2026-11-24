import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
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
  Future<ProviderContainer> pump(WidgetTester tester, _Spy spy) async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(
          SettingsStore(await SharedPreferences.getInstance()),
        ),
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
    return c;
  }

  testWidgets('mode, true black and family all go through the ripple', (
    tester,
  ) async {
    final spy = _Spy();
    final c = await pump(tester, spy);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(spy.taps, hasLength(1));
    expect(c.read(settingsProvider).themeMode, ThemeMode.light);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(spy.taps, hasLength(2));

    await tester.tap(find.byType(HsToggle).first);
    await tester.pumpAndSettle();
    expect(spy.taps, hasLength(3));
    expect(c.read(settingsProvider).amoled, isFalse);

    await tester.tap(
      find.bySemanticsLabel(RegExp('${ThemeFamily.all.last.name} theme')),
    );
    await tester.pumpAndSettle();
    expect(spy.taps, hasLength(4));
    expect(c.read(settingsProvider).familyId, ThemeFamily.all.last.id);
  });

  testWidgets('the ripple starts where the finger went down', (tester) async {
    final spy = _Spy();
    await pump(tester, spy);
    final at = tester.getCenter(find.text('Light'));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(spy.taps.single, at);
  });

  testWidgets('haptics and motion rows exist and Haptics toggles', (
    tester,
  ) async {
    final spy = _Spy();
    final c = await pump(tester, spy);
    await tester.scrollUntilVisible(find.text('Haptics'), 200);
    expect(find.text('Automatic'), findsOneWidget);
    // The row is not itself tappable; the toggle is. (True black is the
    // first toggle while dark is in effect.)
    await tester.tap(find.byType(HsToggle).at(1));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).haptics, isFalse);
    expect(spy.taps, isEmpty, reason: 'haptics is not a theme control');
  });
}
