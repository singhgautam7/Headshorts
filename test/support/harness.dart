import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';

/// Pumps [child] inside the real app theme, so a widget test exercises the
/// same colour roles the app ships with.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  HsPalette palette = HsPalette.amoled,
  Size surface = const Size(372, 780),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: buildHsTheme(palette),
      home: Scaffold(backgroundColor: palette.background, body: child),
    ),
  );
}
