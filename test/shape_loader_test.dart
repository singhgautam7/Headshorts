import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/shape_loader.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    MotionLevel level = MotionLevel.expressive,
    bool tickers = true,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildHsTheme(HsPalette.amoled),
      home: MotionScope(
        level: level,
        systemOff: false,
        child: TickerMode(
          enabled: tickers,
          child: const Center(child: ShapeLoader()),
        ),
      ),
    ),
  );

  RenderObject paint(WidgetTester tester) => tester.renderObject(
    find.descendant(
      of: find.byType(ShapeLoader),
      matching: find.byType(CustomPaint),
    ),
  );

  testWidgets('draws nothing for the first 250 ms, then the shape', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(paint(tester), paintsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(paint(tester), paints..path());
  });

  testWidgets('Expressive keeps ticking, and stops when the tree unmounts', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('Subtle shows a still shape without a morph', (tester) async {
    await pump(tester, level: MotionLevel.subtle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(paint(tester), paints..path());
  });

  testWidgets('Off shows a still shape and the clock stops', (tester) async {
    await pump(tester, level: MotionLevel.off);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(paint(tester), paintsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(paint(tester), paints..path());
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('does not tick while TickerMode is off', (tester) async {
    await pump(tester, tickers: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    // The clock never ran, so the delay never ended.
    expect(paint(tester), paintsNothing);
  });
}
