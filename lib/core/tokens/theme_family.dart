import 'package:flutter/widgets.dart';
import 'package:headshorts/core/tokens/oklch.dart';
import 'package:headshorts/core/tokens/palette.dart';

/// How dark a variant is. AMOLED is not a mode — it is a true-black toggle
/// that only applies while dark is in effect.
enum Tone { light, dark, amoled }

/// One accent family, resolving to an [HsPalette] per [Tone].
///
/// [paper] is the design board's own token panel, verbatim, and the default.
/// The other four are Perch's families, derived in OKLCh exactly as Perch
/// derives them, then mapped onto the board's roles — so a family swap is a
/// palette swap and nothing downstream knows.
@immutable
class ThemeFamily {
  const new({
    required this.id,
    required this.name,
    required this.blurb,
    required this.neutralHue,
    required this.neutralChroma,
    required this.primaryHue,
    required this.primaryLightness,
    required this.primaryChroma,
    required this.primaryContainerChroma,
  });

  final String id;
  final String name;
  final String blurb;

  /// Hue for the near-grey surfaces and text.
  final double neutralHue;

  /// Multiplier on the reference neutral chromas — Slate damps them, Ember
  /// warms them slightly.
  final double neutralChroma;
  final double primaryHue;
  final double primaryLightness;
  final double primaryChroma;
  final double primaryContainerChroma;

  /// The design board's palette. The hue fields are unused: its tones are
  /// the three hand-set constants on [HsPalette].
  static const paper = ThemeFamily(
    id: 'paper',
    name: 'Paper',
    blurb: 'the board',
    neutralHue: 0,
    neutralChroma: 0,
    primaryHue: 0,
    primaryLightness: 0,
    primaryChroma: 0,
    primaryContainerChroma: 0,
  );

  static const perch = ThemeFamily(
    id: 'perch',
    name: 'Perch',
    blurb: 'indigo',
    neutralHue: 265,
    neutralChroma: 1,
    primaryHue: 265,
    primaryLightness: 0.55,
    primaryChroma: 0.16,
    primaryContainerChroma: 0.045,
  );

  static const ember = ThemeFamily(
    id: 'ember',
    name: 'Ember',
    blurb: 'warm',
    neutralHue: 55,
    neutralChroma: 1.35,
    primaryHue: 45,
    primaryLightness: 0.60,
    primaryChroma: 0.14,
    primaryContainerChroma: 0.045,
  );

  static const fern = ThemeFamily(
    id: 'fern',
    name: 'Fern',
    blurb: 'cool',
    neutralHue: 160,
    neutralChroma: 1.15,
    primaryHue: 162,
    primaryLightness: 0.56,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
  );

  static const slate = ThemeFamily(
    id: 'slate',
    name: 'Slate',
    blurb: 'mono',
    neutralHue: 265,
    neutralChroma: 0.4,
    primaryHue: 265,
    primaryLightness: 0.42,
    primaryChroma: 0.012,
    primaryContainerChroma: 0.006,
  );

  static const all = [paper, perch, ember, fern, slate];

  static ThemeFamily byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => paper);

  HsPalette colors(Tone tone) {
    if (this == paper) {
      return switch (tone) {
        Tone.light => HsPalette.light,
        Tone.dark => HsPalette.dark,
        Tone.amoled => HsPalette.amoled,
      };
    }
    return tone == Tone.light ? _light() : _dark(amoled: tone == Tone.amoled);
  }

  Color _n(double l, double c) =>
      Oklch(l, c * neutralChroma, neutralHue).toColor();
  Color _p(double l, double c) => Oklch(l, c, primaryHue).toColor();

  HsPalette _light() {
    final pc = primaryChroma;
    return HsPalette(
      background: _n(0.99, 0.004),
      lingerBackground: const Color(0xFFFFFFFF),
      surface: _n(0.965, 0.008),
      surfaceVariant: _n(0.935, 0.011),
      textPrimary: _n(0.20, 0.02),
      textSecondary: _n(0.52, 0.02),
      textMuted: _n(0.62, 0.02),
      divider: _n(0.92, 0.008),
      stroke: _n(0.885, 0.012),
      nav: _n(0.99, 0.004),
      navActive: _p(0.92, primaryContainerChroma),
      navShadow: BoxShadow(
        color: const Oklch(0.35, 0.06, 265, 0.09).toColor(),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
      scrim: _n(0.20, 0.02).withValues(alpha: 0.32),
      skeleton: _n(0.935, 0.011),
      primary: _p(primaryLightness, pc),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: _p(0.92, primaryContainerChroma),
      onPrimaryContainer: _p(0.38, pc),
      isDark: false,
    );
  }

  HsPalette _dark({required bool amoled}) {
    // AMOLED drops the page to true black and sinks the containers under it;
    // everything else keeps its dark value.
    final pcd = primaryChroma * 0.81;
    final container = _n(amoled ? 0.13 : 0.255, amoled ? 0.012 : 0.014);
    final containerHigh = _n(amoled ? 0.15 : 0.30, amoled ? 0.012 : 0.016);
    return HsPalette(
      background: amoled ? const Color(0xFF000000) : _n(0.205, 0.012),
      lingerBackground: const Color(0xFF000000),
      surface: container,
      surfaceVariant: containerHigh,
      textPrimary: _n(0.96, 0.005),
      textSecondary: _n(0.72, 0.012),
      textMuted: _n(0.60, 0.012),
      divider: _n(amoled ? 0.24 : 0.30, 0.014),
      stroke: _n(amoled ? 0.30 : 0.36, amoled ? 0.014 : 0.016),
      nav: container,
      navActive: _p(0.28, pcd * 0.46),
      navShadow: const BoxShadow(
        color: Color(0x80000000),
        blurRadius: 18,
        offset: Offset(0, 6),
      ),
      scrim: const Color(0xB8000000),
      skeleton: containerHigh,
      primary: _p(0.74, pcd),
      onPrimary: _n(0.14, 0.01),
      primaryContainer: _p(0.28, pcd * 0.46),
      onPrimaryContainer: _p(0.90, pcd * 0.46),
      isDark: true,
    );
  }
}
