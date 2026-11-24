import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/widgets/menu.dart';

import 'support/harness.dart';

void main() {
  String? picked;
  var done = false;

  Future<void> open(
    WidgetTester tester,
    List<HsMenuEntry<String>> entries,
  ) async {
    picked = null;
    done = false;
    await pumpThemed(
      tester,
      Align(
        alignment: Alignment.topRight,
        child: Builder(
          builder: (anchor) => GestureDetector(
            onTap: () async {
              picked = await showHsMenu<String>(
                context: anchor,
                anchorContext: anchor,
                entries: entries,
              );
              done = true;
            },
            child: const SizedBox(width: 48, height: 48, child: Text('go')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
  }

  testWidgets('one panel fades in, then a pick closes it', (tester) async {
    await open(tester, const [
      HsMenuEntry(value: 'a', label: 'Alpha', icon: Icons.add),
      HsMenuEntry(value: 'b', label: 'Beta', icon: Icons.add, selected: true),
    ]);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    Opacity panelFade() => tester.widget<Opacity>(
      find
          .ancestor(of: find.text('Alpha'), matching: find.byType(Opacity))
          .first,
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(panelFade().opacity, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(panelFade().opacity, 1);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(picked, 'a');
    expect(done, isTrue);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('a tall menu scrolls and stays on screen', (tester) async {
    await open(tester, [
      for (var i = 0; i < 40; i++)
        HsMenuEntry(value: '$i', label: 'Row $i', icon: Icons.add),
    ]);
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(SingleChildScrollView));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(780));
    expect(rect.right, lessThanOrEqualTo(372));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('a disabled row does nothing', (tester) async {
    await open(tester, const [
      HsMenuEntry(value: 'a', label: 'Alpha', enabled: false),
      HsMenuEntry(value: 'b', label: 'Beta'),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(done, isFalse);
    expect(find.text('Alpha'), findsOneWidget);

    // The barrier dismisses.
    await tester.tapAt(const Offset(10, 700));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(picked, isNull);
  });
}
