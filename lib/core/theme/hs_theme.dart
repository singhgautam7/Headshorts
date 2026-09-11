import 'package:flutter/material.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/typography.dart';

/// Carries the [HsPalette] through the widget tree.
///
/// Screens never branch on brightness; they read roles off `context.hs`.
@immutable
class HsThemeExtension extends ThemeExtension<HsThemeExtension> {
  const new(this.palette);

  final HsPalette palette;

  @override
  HsThemeExtension copyWith({HsPalette? palette}) =>
      HsThemeExtension(palette ?? this.palette);

  @override
  HsThemeExtension lerp(HsThemeExtension? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension HsThemeContext on BuildContext {
  /// The colour roles in force. The only way a widget learns a colour.
  HsPalette get hs => Theme.of(this).extension<HsThemeExtension>()!.palette;
}

/// Builds a [ThemeData] whose Material defaults are dragged into line with the
/// token set, so a stray Material widget cannot introduce an off-spec colour.
ThemeData buildHsTheme(HsPalette p) {
  final scheme =
      (p.isDark ? const ColorScheme.dark() : const ColorScheme.light())
          .copyWith(
            surface: p.background,
            onSurface: p.textPrimary,
            primary: p.textPrimary,
            onPrimary: p.onPrimaryFill,
            outline: p.stroke,
            outlineVariant: p.divider,
          );

  return ThemeData(
    useMaterial3: true,
    brightness: p.isDark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: p.divider,
    splashFactory: InkSparkle.splashFactory,
    fontFamily: HsType.sans,
    textTheme: Typography.material2021(colorScheme: scheme).black.apply(
      fontFamily: HsType.sans,
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    ),
    extensions: [HsThemeExtension(p)],
  );
}
