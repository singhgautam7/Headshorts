import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('HsIconButton uses primaryContainer for filled background', (tester) async {
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

  testWidgets('HsIconButton uses transparent when filled is false', (tester) async {
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
}
