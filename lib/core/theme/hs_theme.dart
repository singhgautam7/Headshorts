import 'package:flutter/material.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/theme_family.dart';
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
      other == null ? this : HsThemeExtension(palette.lerp(other.palette, t));
}

extension HsThemeContext on BuildContext {
  /// The colour roles in force. The only way a widget learns a colour.
  HsPalette get hs => Theme.of(this).extension<HsThemeExtension>()!.palette;
}

final _cache = <String, ThemeData>{};

/// Builds — and caches — one [ThemeData] per (family, tone). `ThemeData`
/// construction is not free and a theme is stable for the life of a setting.
ThemeData hsThemeOf(ThemeFamily family, Tone tone) => _cache.putIfAbsent(
  '${family.id}:${tone.name}',
  () => buildHsTheme(family.colors(tone)),
);

/// Builds the [ThemeData] for a palette.
///
/// Every Material role is mapped onto a token so a stray Material widget (a
/// menu, a switch, a dialog) cannot introduce an off-spec colour, and depth
/// lives in hairlines rather than tonal elevation.
ThemeData buildHsTheme(HsPalette p) {
  final brightness = p.isDark ? Brightness.dark : Brightness.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: brightness,
      ).copyWith(
        primary: p.primary,
        onPrimary: p.onPrimary,
        primaryContainer: p.primaryContainer,
        onPrimaryContainer: p.onPrimaryContainer,
        secondary: p.textSecondary,
        onSecondary: p.onPrimary,
        surface: p.background,
        onSurface: p.textPrimary,
        surfaceContainerLowest: p.background,
        surfaceContainerLow: p.surface,
        surfaceContainer: p.surface,
        surfaceContainerHigh: p.surfaceVariant,
        surfaceContainerHighest: p.surfaceVariant,
        onSurfaceVariant: p.textSecondary,
        outline: p.stroke,
        outlineVariant: p.divider,
        inverseSurface: p.textPrimary,
        onInverseSurface: p.background,
        shadow: p.navShadow.color,
        scrim: p.scrim,
        surfaceTint: Colors.transparent,
      );
  final text = Typography.material2021(colorScheme: scheme).black.apply(
    fontFamily: HsType.sans,
    bodyColor: p.textPrimary,
    displayColor: p.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: p.divider,
    splashFactory: InkSparkle.splashFactory,
    fontFamily: HsType.sans,
    textTheme: text,
    extensions: [HsThemeExtension(p)],
    // Depth lives in hairlines — Material's tonal elevation is off.
    cardTheme: CardThemeData(
      elevation: 0,
      color: p.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: HsRadius.cardBorder,
        side: BorderSide(color: p.stroke),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: HsType.appBarTitle.copyWith(color: p.textPrimary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: HsRadius.sheetTop),
      showDragHandle: false,
    ),
    // The anchored overflow menu: a rounded card of rows with a hairline, the
    // one place a shadow is allowed besides the nav pill.
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: p.navShadow.color,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: HsRadius.menuBorder,
        side: BorderSide(color: p.stroke),
      ),
      menuPadding: const EdgeInsets.all(HsSpace.x2),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.primary,
      selectionColor: p.primaryContainer,
      selectionHandleColor: p.primary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? p.onPrimary : p.surfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.surface,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.stroke,
      ),
    ),
  );
}
