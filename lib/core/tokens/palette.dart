import 'package:flutter/widgets.dart';
import 'package:headshorts/core/tokens/oklab.dart';

/// Colour roles, exactly as specified in the design board's token panel.
///
/// Nothing outside this file and `theme_family.dart` may name a raw colour.
/// Screens read roles from [HsPalette] via `context.hs`, so the same widget
/// tree renders correctly in every theme without a single conditional.
@immutable
class HsPalette {
  const new({
    required this.background,
    required this.lingerBackground,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.stroke,
    required this.nav,
    required this.navActive,
    required this.navShadow,
    required this.scrim,
    required this.skeleton,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.isDark,
  });

  /// AMOLED — true black ground, soft off-white ink. The default.
  static const amoled = HsPalette(
    background: Color(0xFF000000),
    lingerBackground: Color(0xFF000000),
    surface: Color(0xFF0C0C0E),
    surfaceVariant: Color(0xFF17171A),
    textPrimary: Color(0xFFEFECE6),
    textSecondary: Color(0xFFA6A39C),
    textMuted: Color(0xFF6C6A66),
    divider: Color(0xFF232327),
    stroke: Color(0xFF2B2B30),
    nav: Color(0xFF18181C),
    navActive: Color(0xFF2C2C32),
    navShadow: BoxShadow(
      color: Color(0xE6000000),
      blurRadius: 28,
      offset: Offset(0, 8),
    ),
    scrim: Color(0xB8000000),
    skeleton: Color(0xFF1A1A1D),
    primary: Color(0xFFEFECE6),
    onPrimary: Color(0xFF000000),
    primaryContainer: Color(0xFF2C2C32),
    onPrimaryContainer: Color(0xFFEFECE6),
    isDark: true,
  );

  /// Dark — the board's AMOLED roles lifted off true black, for the reader
  /// who wants the ink without the pure-black ground. The board draws only
  /// the two extremes; this is the step between them.
  static const dark = HsPalette(
    background: Color(0xFF121214),
    lingerBackground: Color(0xFF000000),
    surface: Color(0xFF1A1A1D),
    surfaceVariant: Color(0xFF242428),
    textPrimary: Color(0xFFEFECE6),
    textSecondary: Color(0xFFA6A39C),
    textMuted: Color(0xFF75736E),
    divider: Color(0xFF2A2A2F),
    stroke: Color(0xFF34343A),
    nav: Color(0xFF1E1E22),
    navActive: Color(0xFF323238),
    navShadow: BoxShadow(
      color: Color(0xB3000000),
      blurRadius: 28,
      offset: Offset(0, 8),
    ),
    scrim: Color(0xB8000000),
    skeleton: Color(0xFF222226),
    primary: Color(0xFFEFECE6),
    onPrimary: Color(0xFF121214),
    primaryContainer: Color(0xFF323238),
    onPrimaryContainer: Color(0xFFEFECE6),
    isDark: true,
  );

  /// Light — warm paper ground, near-black ink. Same roles, inverted.
  static const light = HsPalette(
    background: Color(0xFFF4F1EA),
    lingerBackground: Color(0xFFFFFFFF),
    surface: Color(0xFFFBF9F5),
    surfaceVariant: Color(0xFFEAE5DA),
    textPrimary: Color(0xFF171614),
    textSecondary: Color(0xFF54524C),
    textMuted: Color(0xFF8B887F),
    divider: Color(0xFFDFD9CC),
    stroke: Color(0xFFD6CFC0),
    nav: Color(0xFFFFFFFF),
    navActive: Color(0xFFEAE5DA),
    navShadow: BoxShadow(
      color: Color(0x24322814),
      blurRadius: 22,
      offset: Offset(0, 6),
    ),
    scrim: Color(0x801E1A12),
    skeleton: Color(0xFFE7E1D5),
    primary: Color(0xFF171614),
    onPrimary: Color(0xFFFBF9F5),
    primaryContainer: Color(0xFFEAE5DA),
    onPrimaryContainer: Color(0xFF171614),
    isDark: false,
  );

  final Color background;

  /// Linger's ground: pure black or pure white, whatever the page ground is,
  /// for maximum contrast under the one card the reader is lingering on.
  final Color lingerBackground;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;
  final Color stroke;
  final Color nav;
  final Color navActive;

  /// elev-1 — the one soft shadow in the app, reserved for the nav pill.
  final BoxShadow navShadow;
  final Color scrim;
  final Color skeleton;

  /// The primary button, a toggle that is on, a selected chip. Ink in the
  /// board's own themes; the family's accent in Perch's.
  final Color primary;
  final Color onPrimary;

  /// The active nav item and the selected row of a picker.
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final bool isDark;

  /// A frame of the theme cross-fade. `ThemeData` lerps its colour scheme
  /// over the switch; without this every `context.hs` colour would snap at
  /// the midpoint while the Material-backed surfaces faded.
  HsPalette lerp(HsPalette other, double t) {
    // `Oklab.mix` weights its first argument, so `other` goes first.
    Color m(Color a, Color b) => Oklab.mix(b, a, t);
    return HsPalette(
      background: m(background, other.background),
      lingerBackground: m(lingerBackground, other.lingerBackground),
      surface: m(surface, other.surface),
      surfaceVariant: m(surfaceVariant, other.surfaceVariant),
      textPrimary: m(textPrimary, other.textPrimary),
      textSecondary: m(textSecondary, other.textSecondary),
      textMuted: m(textMuted, other.textMuted),
      divider: m(divider, other.divider),
      stroke: m(stroke, other.stroke),
      nav: m(nav, other.nav),
      navActive: m(navActive, other.navActive),
      navShadow: BoxShadow.lerp(navShadow, other.navShadow, t)!,
      scrim: m(scrim, other.scrim),
      skeleton: m(skeleton, other.skeleton),
      primary: m(primary, other.primary),
      onPrimary: m(onPrimary, other.onPrimary),
      primaryContainer: m(primaryContainer, other.primaryContainer),
      onPrimaryContainer: m(onPrimaryContainer, other.onPrimaryContainer),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}
