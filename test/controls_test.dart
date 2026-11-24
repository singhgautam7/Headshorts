import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/widgets/controls.dart';

import 'support/harness.dart';

Widget _scoped(MotionLevel level, Widget child) =>
    MotionScope(level: level, systemOff: false, child: child);

double _radius(WidgetTester tester, Finder f) {
  final deco =
      tester
              .widget<Container>(
                find.descendant(of: f, matching: find.byType(Container)).first,
              )
              .decoration!
          as ShapeDecoration;
  return ((deco.shape as RoundedRectangleBorder).borderRadius as BorderRadius)
      .topLeft
      .x;
}

void main() {
  group('HsButton', () {
    testWidgets('pill at rest, 12 dp while held, pill again after', (
      tester,
    ) async {
      await pumpThemed(tester, HsButton('Go', onPressed: () {}));
      final f = find.byType(HsButton);
      expect(_radius(tester, f), 26);
      final g = await tester.startGesture(tester.getCenter(f));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_radius(tester, f), closeTo(12, 0.5));
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(_radius(tester, f), closeTo(26, 0.5));
    });

    testWidgets('a short button holds at 8 dp', (tester) async {
      await pumpThemed(tester, HsButton('Go', onPressed: () {}, height: 44));
      final f = find.byType(HsButton);
      final g = await tester.startGesture(tester.getCenter(f));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_radius(tester, f), closeTo(8, 0.5));
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    });

    for (final level in [MotionLevel.subtle, MotionLevel.off]) {
      testWidgets('no morph at $level', (tester) async {
        await pumpThemed(
          tester,
          _scoped(level, HsButton('Go', onPressed: () {})),
        );
        final f = find.byType(HsButton);
        final g = await tester.startGesture(tester.getCenter(f));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(_radius(tester, f), 26);
        await g.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
      });
    }

    testWidgets('Off when the phone disables animations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => Text('${systemMotionOff(context)}'),
            ),
          ),
        ),
      );
      expect(find.text('true'), findsOneWidget);
    });

    testWidgets('a large font grows the button instead of clipping', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3)),
          child: HsButton('A fairly long label', onPressed: () {}),
        ),
      );
      expect(tester.getSize(find.byType(HsButton)).height, greaterThan(52));
    });
  });

  group('HsChip', () {
    double chipRadius(WidgetTester tester) {
      final shape = tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(HsChip),
                  matching: find.byType(Material),
                )
                .first,
          )
          .shape!;
      return shape is RoundedRectangleBorder
          ? (shape.borderRadius as BorderRadius).topLeft.x
          : -1;
    }

    testWidgets('selected is a 12 dp squircle, unselected a stadium', (
      tester,
    ) async {
      await pumpThemed(tester, HsChip('Tech', selected: true, onTap: () {}));
      expect(chipRadius(tester), 12);
      await pumpThemed(tester, HsChip('Tech', onTap: () {}));
      await tester.pumpAndSettle();
      final shape = tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(HsChip),
                  matching: find.byType(Material),
                )
                .first,
          )
          .shape;
      expect(shape, isA<StadiumBorder>());
    });

    testWidgets('visual is 32 dp inside a 48 dp hit region', (tester) async {
      await pumpThemed(tester, HsChip('Tech', onTap: () {}));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(HsChip)).height, 48);
      expect(
        tester
            .getSize(
              find
                  .descendant(
                    of: find.byType(HsChip),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .height,
        32,
      );
      expect(HsChip.runSpacing(8), -8);
    });
  });

  group('HsToggle', () {
    testWidgets('announces its state and enabled flag', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, HsToggle(value: true, onChanged: (_) {}));
      expect(
        tester.getSemantics(find.byType(HsToggle)),
        matchesSemantics(
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      await pumpThemed(tester, const HsToggle(value: false, onChanged: null));
      expect(
        tester.getSemantics(find.byType(HsToggle)),
        matchesSemantics(hasToggledState: true, hasEnabledState: true),
      );
      handle.dispose();
    });

    testWidgets('is a 48 dp target and flips on tap', (tester) async {
      var v = false;
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, set) =>
              HsToggle(value: v, onChanged: (n) => set(() => v = n)),
        ),
      );
      expect(tester.getSize(find.byType(HsToggle)), const Size(48, 48));
      await tester.tap(find.byType(HsToggle));
      await tester.pumpAndSettle();
      expect(v, isTrue);
    });
  });
}
