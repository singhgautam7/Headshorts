import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/widgets/header_preview.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/more/header_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HsDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HsDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        settingsStoreProvider.overrideWithValue(
          SettingsStore(await SharedPreferences.getInstance()),
        ),
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
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
            home: const MotionScope(
              level: MotionLevel.off,
              systemOff: false,
              child: Scaffold(body: HeaderScreen()),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the switch and three pill choices, each with a preview', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Floating header'), findsOneWidget);
    for (final m in PillMode.values) {
      expect(find.text(m.label), findsOneWidget);
    }
    expect(find.byType(HeaderPreview), findsNWidgets(3));
    final previews = tester.widgetList<HeaderPreview>(
      find.byType(HeaderPreview),
    );
    expect(previews.map((p) => p.pill), PillMode.values);
    expect(previews.every((p) => p.floating), isTrue);
    await unmount(tester);
  });

  testWidgets('a choice is saved at once', (tester) async {
    await pump(tester);
    expect(container.read(settingsProvider).pillMode, PillMode.always);
    await tap(tester, 'When scrolling up');
    expect(container.read(settingsProvider).pillMode, PillMode.scrollUp);
    await tap(tester, 'When scrolling stops');
    expect(container.read(settingsProvider).pillMode, PillMode.scrollStop);
    await unmount(tester);
  });

  testWidgets('switching the header off disables the choices', (tester) async {
    await pump(tester);
    await tap(tester, 'Floating header');
    expect(container.read(settingsProvider).floatingHeader, isFalse);
    expect(find.text('Scrolls away with the page'), findsOneWidget);
    // Previews show the header as it now behaves, and the choices do nothing.
    expect(
      tester
          .widgetList<HeaderPreview>(find.byType(HeaderPreview))
          .every((p) => !p.floating),
      isTrue,
    );
    await tap(tester, 'When scrolling up');
    expect(container.read(settingsProvider).pillMode, PillMode.always);

    await tap(tester, 'Floating header');
    expect(container.read(settingsProvider).floatingHeader, isTrue);
    await unmount(tester);
  });

  testWidgets('renders at 2.0 text scale on 360x640 without overflow', (
    tester,
  ) async {
    await pump(tester, scale: 2);
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
