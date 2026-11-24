import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/widgets/app_icon_button.dart';

void main() {
  Widget frame(Widget child, {HsPalette palette = HsPalette.amoled}) =>
      MaterialApp(
        theme: buildHsTheme(palette),
        home: Scaffold(body: Center(child: child)),
      );

  Finder iconMaterial() => find.descendant(
    of: find.byType(HsIconButton),
    matching: find.byType(Material),
  );

  testWidgets('HsIconButton uses primaryContainer for filled background', (
    tester,
  ) async {
    await tester.pumpWidget(
      frame(
        HsIconButton(
          icon: Icons.arrow_back_rounded,
          onPressed: () {},
          semanticLabel: 'Back',
        ),
      ),
    );

    final material = tester.widget<Material>(iconMaterial());
    expect(material.color, HsPalette.amoled.primaryContainer);
    expect(material.color, isNot(HsPalette.amoled.surfaceVariant));
    expect(material.color, isNot(HsPalette.amoled.background));
  });

  testWidgets('HsIconButton uses primary when active', (tester) async {
    await tester.pumpWidget(
      frame(
        HsIconButton(
          icon: Icons.arrow_back_rounded,
          onPressed: () {},
          semanticLabel: 'Back',
          active: true,
        ),
      ),
    );

    final material = tester.widget<Material>(iconMaterial());
    expect(material.color, HsPalette.amoled.primary);
  });

  testWidgets('HsIconButton uses transparent when filled is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      frame(
        HsIconButton(
          icon: Icons.arrow_back_rounded,
          onPressed: () {},
          semanticLabel: 'Back',
          filled: false,
        ),
      ),
    );

    final material = tester.widget<Material>(iconMaterial());
    expect(material.color, Colors.transparent);
  });

  testWidgets('HsIconButton relaxes to a 12 dp squircle while held', (
    tester,
  ) async {
    await tester.pumpWidget(
      frame(
        HsIconButton(
          icon: Icons.arrow_back_rounded,
          onPressed: () {},
          semanticLabel: 'Back',
        ),
      ),
    );
    double radius() {
      final m = tester.widget<Material>(iconMaterial());
      return ((m.shape! as RoundedRectangleBorder).borderRadius as BorderRadius)
          .topLeft
          .x;
    }

    expect(radius(), 20);
    final g = await tester.startGesture(
      tester.getCenter(find.byType(HsIconButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(radius(), closeTo(12, 0.5));
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(radius(), closeTo(20, 0.5));
  });

  testWidgets('HsIconButton does not morph at Subtle or Off', (tester) async {
    for (final level in [MotionLevel.subtle, MotionLevel.off]) {
      await tester.pumpWidget(
        frame(
          MotionScope(
            level: level,
            systemOff: false,
            child: HsIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: () {},
              semanticLabel: 'Back',
            ),
          ),
        ),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byType(HsIconButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final m = tester.widget<Material>(iconMaterial());
      expect(
        ((m.shape! as RoundedRectangleBorder).borderRadius as BorderRadius)
            .topLeft
            .x,
        20,
        reason: '$level',
      );
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    }
  });

  testWidgets('HsIconButton is announced as disabled without a handler', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      frame(
        const HsIconButton(
          icon: Icons.arrow_back_rounded,
          onPressed: null,
          semanticLabel: 'Back',
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(HsIconButton)),
      matchesSemantics(label: 'Back', isButton: true, hasEnabledState: true),
    );
    handle.dispose();
  });
}
