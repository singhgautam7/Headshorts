import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/widgets/sheet.dart';

import 'support/harness.dart';

void main() {
  testWidgets('the slide is held for the first frame, then moves', (
    tester,
  ) async {
    String? picked;
    await pumpThemed(
      tester,
      Builder(
        builder: (context) => GestureDetector(
          onTap: () async => picked = await showOptionSheet<String>(
            context,
            title: 'Pick',
            selected: 'a',
            options: const [
              SheetOption(value: 'a', label: 'Alpha'),
              SheetOption(value: 'b', label: 'Beta'),
            ],
          ),
          child: const SizedBox.expand(child: Text('go')),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    final held = tester.getTopLeft(find.byType(HsSheet)).dy;
    expect(held, greaterThanOrEqualTo(780), reason: 'built, not yet moving');

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    final moving = tester.getTopLeft(find.byType(HsSheet)).dy;
    expect(moving, lessThan(held));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(HsSheet)).dy, lessThan(moving));

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(picked, 'b');
  });
}
