import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/widgets/nav_pill.dart';

import 'support/harness.dart';

Widget _pill(int selected, {ValueChanged<int>? onSelected}) => Align(
  alignment: Alignment.bottomCenter,
  child: NavPill(
    destinations: NavPill.destinationsForApp,
    selectedIndex: selected,
    onSelected: onSelected ?? (_) {},
  ),
);

void main() {
  group('NavPill', () {
    testWidgets('only the selected destination carries text', (tester) async {
      await pumpThemed(tester, _pill(0));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Linger'), findsNothing);
      expect(find.text('Sources'), findsNothing);
      expect(find.text('More'), findsNothing);
    });

    testWidgets('hugs its four items rather than spanning the screen', (
      tester,
    ) async {
      await pumpThemed(tester, _pill(0));
      await tester.pumpAndSettle();

      final pill = tester.getSize(find.byType(NavPill));
      expect(pill.height, HsSize.navPillHeight + HsSize.navPillInset);
      expect(pill.width, lessThan(372 * 0.75));
    });

    testWidgets('reports the tapped destination', (tester) async {
      final tapped = <int>[];
      await pumpThemed(tester, _pill(0, onSelected: tapped.add));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Sources'));
      await tester.tap(find.bySemanticsLabel('More'));
      expect(tapped, [2, 3]);
    });

    testWidgets('the label morphs in over motion-nav-morph', (tester) async {
      await pumpThemed(tester, _pill(0));
      await tester.pumpAndSettle();
      final closed = tester.getSize(find.byType(NavPill)).width;

      await pumpThemed(tester, _pill(2));
      await tester.pump();
      final midMorph = tester.getSize(find.byType(NavPill)).width;
      await tester.pumpAndSettle();
      final open = tester.getSize(find.byType(NavPill)).width;

      // "Sources" is a longer label than "Today", so the pill grows, and it
      // arrives there over time rather than jumping.
      expect(open, greaterThan(closed));
      expect(midMorph, lessThan(open));
    });

    testWidgets('carries no badge, count or dot', (tester) async {
      await pumpThemed(tester, _pill(0));
      await tester.pumpAndSettle();

      expect(find.textContaining(RegExp(r'\d')), findsNothing);
    });

    testWidgets('renders on paper as well as on black', (tester) async {
      await pumpThemed(tester, _pill(3), palette: HsPalette.light);
      await tester.pumpAndSettle();

      expect(find.text('More'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
