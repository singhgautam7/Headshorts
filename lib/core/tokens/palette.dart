import 'package:flutter/widgets.dart';

/// Colour roles, exactly as specified in the design board's token panel.
///
/// Nothing outside this file may name a raw colour. Screens read roles from
/// [HsPalette] via `context.hs`, so the same widget tree renders correctly in
/// both themes without a single conditional.
@immutable
class HsPalette {
  const new({
    required this.background,
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
    required this.isDark,
  });

  /// AMOLED — true black ground, soft off-white ink. The default.
  static const amoled = HsPalette(
    background: Color(0xFF000000),
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
    isDark: true,
  );

  /// Light — warm paper ground, near-black ink. Same roles, inverted.
  static const light = HsPalette(
    background: Color(0xFFF4F1EA),
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
    isDark: false,
  );

  final Color background;
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
  final bool isDark;

  /// The colour that reads as "ink on the primary button" for this theme.
  ///
  /// AMOLED prints on true black; on paper the primary button prints on the
  /// surface tone rather than the warm page ground.
  Color get onPrimaryFill => isDark ? background : surface;
}
