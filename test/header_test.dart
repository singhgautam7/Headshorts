import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/widgets/app_header.dart';
import 'package:headshorts/core/widgets/app_icon_button.dart';
import 'package:headshorts/data/prefs/settings.dart';

import 'support/harness.dart';

const _statusBar = 32.0;
const _restBelowStatus =
    HeaderSpec.padTop + HeaderSpec.row + HeaderSpec.padBottom;

/// The floating header, with a status bar and a gesture inset in play: every
/// bug that shipped in Mull read an inset above its provider and only showed
/// on a device, so these never run with a zero status bar.
void main() {
  late ScrollController scroll;
  late BuildContext inner;
  var bodyBuilds = 0;
  var backTaps = 0;

  Future<void> pump(
    WidgetTester tester, {
    bool floating = true,
    PillMode pill = PillMode.always,
    MotionLevel level = MotionLevel.expressive,
    double textScale = 1,
    Size surface = const Size(400, 780),
    String title = 'Headlines',
  }) async {
    scroll = ScrollController();
    addTearDown(scroll.dispose);
    bodyBuilds = 0;
    backTaps = 0;
    await pumpThemed(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: _statusBar, bottom: 24),
            viewPadding: const EdgeInsets.only(top: _statusBar, bottom: 24),
            textScaler: TextScaler.linear(textScale),
          ),
          child: ProviderScope(
            child: MotionScope(
              level: level,
              systemOff: false,
              child: HeaderPage(
                preview: HeaderPreviewSpec(floating: floating, pill: pill),
                header: AppHeader(
                  title: title,
                  root: true,
                  onBack: () => backTaps++,
                  actions: [
                    HsIconButton(
                      icon: Icons.more_vert_rounded,
                      semanticLabel: 'More',
                      onPressed: () {},
                    ),
                  ],
                ),
                body: Builder(
                  builder: (context) {
                    bodyBuilds++;
                    inner = context;
                    return ListView(
                      controller: scroll,
                      children: [
                        HeaderPage.gap(),
                        for (var i = 0; i < 60; i++)
                          SizedBox(height: 60, child: Text('row $i')),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      surface: surface,
    );
    await tester.pump();
  }

  Future<void> jump(WidgetTester tester, double to) async {
    scroll.jumpTo(to);
    await tester.pump();
  }

  Rect titleRect(WidgetTester tester) => tester.getRect(find.text('Headlines'));
  final moreButton = find.byIcon(Icons.more_vert_rounded);
  double buttonY(WidgetTester tester) => tester.getTopLeft(moreButton).dy;

  /// Into the pill the way a thumb gets there: a short step across the
  /// threshold, not a leap that already counts as a long scroll down.
  Future<void> toPill(WidgetTester tester) async {
    await jump(tester, 30);
    await jump(tester, 34);
    await tester.pumpAndSettle();
  }

  testWidgets('rest: the buttons take taps below the status bar', (
    tester,
  ) async {
    await pump(tester);
    expect(HeaderPage.insetOf(inner), _statusBar + _restBelowStatus);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    expect(backTaps, 1);
    // The first row starts exactly under the header.
    expect(
      tester.getTopLeft(find.text('row 0')).dy,
      closeTo(_statusBar + _restBelowStatus, 0.5),
    );
  });

  testWidgets('pill at 32, back at 8, nothing flickers in between', (
    tester,
  ) async {
    await pump(tester);
    await jump(tester, 31);
    expect(HeaderPage.isPilled(inner), isFalse);
    await jump(tester, 33);
    expect(HeaderPage.isPilled(inner), isTrue);
    // Inside the 8..32 gap it keeps whatever it was.
    await jump(tester, 20);
    expect(HeaderPage.isPilled(inner), isTrue);
    await jump(tester, 9);
    expect(HeaderPage.isPilled(inner), isTrue);
    await jump(tester, 8);
    expect(HeaderPage.isPilled(inner), isFalse);
    await jump(tester, 20);
    expect(HeaderPage.isPilled(inner), isFalse);
    expect(HsMotion.pillAt, 32);
    expect(HsMotion.headerAt, 8);
  });

  testWidgets('round trip leaves the rest rect exactly where it was', (
    tester,
  ) async {
    await pump(tester);
    final title = titleRect(tester);
    final button = buttonY(tester);

    await jump(tester, 200);
    await tester.pumpAndSettle();
    // In the pill the title is smaller and the buttons sit 2 dp higher.
    expect(titleRect(tester).height, lessThan(title.height));
    expect(buttonY(tester), closeTo(button - 2, 0.01));

    await jump(tester, 0);
    await tester.pumpAndSettle();
    expect(titleRect(tester), title);
    expect(buttonY(tester), button);
  });

  testWidgets('Always: the pill never leaves', (tester) async {
    await pump(tester);
    await jump(tester, 100);
    await tester.pumpAndSettle();
    final shown = buttonY(tester);
    await jump(tester, 220);
    await tester.pumpAndSettle();
    expect(buttonY(tester), shown);
  });

  testWidgets('When scrolling up: hides going down, returns going up', (
    tester,
  ) async {
    await pump(tester, pill: PillMode.scrollUp);
    await toPill(tester);
    final shown = buttonY(tester);

    await jump(tester, 70);
    await tester.pumpAndSettle();
    expect(buttonY(tester), lessThan(shown - HeaderSpec.hideDistance / 2));

    await jump(tester, 50);
    await tester.pumpAndSettle();
    expect(buttonY(tester), shown);
  });

  testWidgets('When scrolling stops: hides while moving, back after', (
    tester,
  ) async {
    await pump(tester, pill: PillMode.scrollStop);
    await toPill(tester);
    await tester.pump(const Duration(seconds: 1));
    final shown = buttonY(tester);

    await jump(tester, 80);
    await tester.pump(const Duration(milliseconds: 120));
    expect(buttonY(tester), lessThan(shown));

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(buttonY(tester), shown);
  });

  testWidgets('Floating header off: nothing is sticky, it scrolls away', (
    tester,
  ) async {
    await pump(tester, floating: false);
    final rest = buttonY(tester);
    await jump(tester, 40);
    expect(HeaderPage.isPilled(inner), isFalse);
    expect(buttonY(tester), closeTo(rest - 40, 0.01));
    await jump(tester, 400);
    // Carried off by the content, never stuck at the top.
    expect(tester.getBottomLeft(moreButton).dy, lessThanOrEqualTo(0));
    await jump(tester, 0);
    expect(buttonY(tester), rest);
  });

  testWidgets('a hidden pill is not in semantics, a shown one is', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, pill: PillMode.scrollUp);
    await toPill(tester);
    expect(find.semantics.byLabel('More'), findsOneWidget);
    expect(find.semantics.byLabel('Back'), findsOneWidget);

    await jump(tester, 80);
    await tester.pumpAndSettle();
    expect(find.semantics.byLabel('More'), findsNothing);
    expect(find.semantics.byLabel('Back'), findsNothing);
    handle.dispose();
  });

  testWidgets('scrolling rebuilds neither the page body nor the header', (
    tester,
  ) async {
    await pump(tester, pill: PillMode.scrollUp);
    final body = bodyBuilds;
    final header = AppHeader.debugBuildCount;
    for (final y in [4.0, 20.0, 40.0, 120.0, 90.0, 300.0, 10.0, 0.0]) {
      await jump(tester, y);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(bodyBuilds, body);
    expect(AppHeader.debugBuildCount, header);
  });

  testWidgets('Off: the pill is instant', (tester) async {
    await pump(tester, level: MotionLevel.off);
    await jump(tester, 100);
    // One frame, no spring to wait for.
    expect(HeaderPage.isPilled(inner), isTrue);
    expect(titleRect(tester).height, lessThan(30));
  });

  testWidgets('largest text on a small phone: the header grows, no overflow', (
    tester,
  ) async {
    await pump(
      tester,
      textScale: 2,
      surface: const Size(360, 640),
      title: 'A rather long page title',
    );
    expect(tester.takeException(), isNull);
    await jump(tester, 100);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      HeaderPage.insetOf(inner),
      greaterThan(_statusBar + _restBelowStatus),
    );
  });

  group('HeaderSearchBar', () {
    final focus = FocusNode();
    final text = TextEditingController();
    const field = ValueKey('field');

    Future<void> pumpSearch(WidgetTester tester, {bool floating = true}) async {
      scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: _statusBar, bottom: 24),
              viewPadding: const EdgeInsets.only(top: _statusBar, bottom: 24),
            ),
            child: ProviderScope(
              child: HeaderPage(
                scrollAway: true,
                preview: HeaderPreviewSpec(
                  floating: floating,
                  pill: PillMode.always,
                ),
                header: const AppHeader(title: 'Search', root: true),
                body: Builder(
                  builder: (context) {
                    inner = context;
                    return CustomScrollView(
                      controller: scroll,
                      slivers: [
                        HeaderSearchBar.sliverGap(),
                        HeaderSearchBar(
                          focusNode: focus,
                          child: SizedBox.expand(
                            child: TextField(
                              key: field,
                              controller: text,
                              focusNode: focus,
                            ),
                          ),
                        ),
                        SliverList.builder(
                          itemCount: 60,
                          itemBuilder: (_, i) =>
                              SizedBox(height: 60, child: Text('row $i')),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        surface: const Size(400, 780),
      );
      await tester.pump();
    }

    tearDownAll(() {
      focus.dispose();
      text.dispose();
    });

    testWidgets('at rest it sits under the title and takes a tap', (
      tester,
    ) async {
      await pumpSearch(tester);
      final rect = tester.getRect(find.byKey(field));
      expect(rect.top, closeTo(_statusBar + _restBelowStatus, 0.5));
      expect(rect.height, HeaderSearchBar.restHeight);
      await tester.tap(find.byKey(field));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('scrolled, it is the pill, and keeps focus and text', (
      tester,
    ) async {
      await pumpSearch(tester);
      await tester.tap(find.byKey(field));
      await tester.enterText(find.byKey(field), 'heat');
      await tester.pump();

      await jump(tester, 400);
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.byKey(field));
      expect(rect.left, closeTo(HeaderSpec.margin, 0.01));
      expect(rect.right, closeTo(400 - HeaderSpec.margin, 0.01));
      expect(rect.top, closeTo(_statusBar + HeaderSpec.top, 0.01));
      expect(rect.height, closeTo(HeaderSpec.pillHeight, 0.01));
      expect(text.text, 'heat');
      expect(focus.hasFocus, isTrue);

      // Back to the top: the rest geometry again.
      await jump(tester, 0);
      await tester.pumpAndSettle();
      final back = tester.getRect(find.byKey(field));
      expect(back.top, closeTo(_statusBar + _restBelowStatus, 0.5));
      expect(back.height, HeaderSearchBar.restHeight);
    });

    testWidgets('Floating header off: it scrolls away too', (tester) async {
      await pumpSearch(tester, floating: false);
      await jump(tester, 400);
      await tester.pumpAndSettle();
      // Gone with the content: off the top, or not built at all.
      if (find.byKey(field).evaluate().isNotEmpty) {
        expect(tester.getRect(find.byKey(field)).bottom, lessThanOrEqualTo(0));
      }
    });
  });
}
