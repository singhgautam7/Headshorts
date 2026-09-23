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

      expect(find.text('Headlines'), findsOneWidget);
      expect(find.text('Search'), findsNothing);
      expect(find.text('Linger'), findsNothing);
      expect(find.text('Sources'), findsNothing);
      expect(find.text('More'), findsNothing);
    });

    testWidgets('hugs its five items rather than spanning the screen', (
      tester,
    ) async {
      await pumpThemed(tester, _pill(1));
      await tester.pumpAndSettle();

      final pill = tester.getSize(find.byType(NavPill));
      expect(pill.height, HsSize.navPillHeight + HsSize.navPillInset);
      expect(pill.width, lessThan(372 * 0.9));
    });

    testWidgets('the widest label fits rather than overflowing', (
      tester,
    ) async {
      // The board's note: at a large font scale the active label gives way.
      // Only the selected item flexes — making all five flexible splits the
      // free space five ways and clips the one label to a third of itself.
      await pumpThemed(tester, _pill(0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(NavPill)).width,
        lessThanOrEqualTo(372),
      );
    });

    testWidgets('reports the tapped destination', (tester) async {
      final tapped = <int>[];
      await pumpThemed(tester, _pill(0, onSelected: tapped.add));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Sources'));
      await tester.tap(find.bySemanticsLabel('Search'));
      expect(tapped, [2, 3]);
    });

    testWidgets('the label morphs in over motion-nav-morph', (tester) async {
      await pumpThemed(tester, _pill(4));
      await tester.pumpAndSettle();
      final closed = tester.getSize(find.byType(NavPill)).width;

      await pumpThemed(tester, _pill(1));
      await tester.pump();
      final midMorph = tester.getSize(find.byType(NavPill)).width;
      await tester.pumpAndSettle();
      final open = tester.getSize(find.byType(NavPill)).width;

      // "Linger" is a longer label than "More", so the pill grows, and it
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
      await pumpThemed(tester, _pill(4), palette: HsPalette.light);
      await tester.pumpAndSettle();

      expect(find.text('More'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
