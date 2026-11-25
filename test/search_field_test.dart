import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/widgets/search_field.dart';

import 'support/harness.dart';

void main() {
  testWidgets('tapping the pill edge focuses the field', (tester) async {
    await pumpThemed(
      tester,
      Padding(
        padding: const EdgeInsets.all(20),
        child: HsSearchField(hint: 'Search', onChanged: (_) {}),
      ),
    );
    final pill = tester.getRect(find.byType(HsSearchField));
    expect(pill.height, greaterThanOrEqualTo(48));

    // The left edge, well outside the text line.
    await tester.tapAt(pill.centerLeft + const Offset(4, 0));
    await tester.pump();
    expect(
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .widget
          .focusNode
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('the clear button appears with text and clears it', (
    tester,
  ) async {
    final seen = <String>[];
    await pumpThemed(
      tester,
      HsSearchField(
        hint: 'Search',
        onChanged: seen.add,
        debounce: Duration.zero,
      ),
    );
    await tester.enterText(find.byType(EditableText), 'heat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('\u00d7'));
    await tester.pumpAndSettle();
    expect(seen.last, '');
    expect(find.text('heat'), findsNothing);
  });
}
