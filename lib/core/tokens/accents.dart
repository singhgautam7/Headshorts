import 'package:flutter/widgets.dart';

/// A source's accent, held as the pair of tones the design board specifies:
/// a light tone that carries on true black, and a deep tone that carries on
/// paper. Same hue, inverted tone.
///
/// Accent is *label, hairline bar, and — Linger only — a wash panel*. It is
/// never a saturated card fill.
@immutable
class SourceAccent {
  const new(this.onDark, this.onLight);

  /// Derives both tones from a single seed hue, for sources the user adds.
  ///
  /// The targets are read off the curated set in the design board: the dark
  /// tone sits high and desaturated, the paper tone deep and a shade richer.
  factory fromSeed(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    final saturation = hsl.saturation.clamp(0.24, 0.62);
    return SourceAccent(
      hsl.withSaturation(saturation).withLightness(0.69).toColor(),
      hsl
          .withSaturation((saturation + 0.06).clamp(0.0, 1.0))
          .withLightness(0.33)
          .toColor(),
    );
  }

  /// Deterministic accent for a source we know nothing about beyond its feed
  /// address — a stable hue per host, so a source keeps its colour forever.
  factory fromKey(String key) {
    final hue = (key.hashCode.abs() % 360).toDouble();
    return SourceAccent.fromSeed(
      HSLColor.fromAHSL(1, hue, 0.45, 0.6).toColor(),
    );
  }

  /// The neutral "source", used where the accent should read as plain ink:
  /// the caught-up rule, the welcome mark, the Linger hard stop.
  static const neutral = SourceAccent(Color(0xFFEFECE6), Color(0xFF171614));

  final Color onDark;
  final Color onLight;

  Color resolve({required bool isDark}) => isDark ? onDark : onLight;

  /// Packed for storage: the two tones as a single 64-bit value would be
  /// awkward in SQL, so callers store [onDark] and [onLight] separately.
  int get darkValue => onDark.toARGB32();
  int get lightValue => onLight.toARGB32();
}

/// The accent in force for a subtree — the Flutter equivalent of the design
/// board's `data-src` attribute.
///
/// Widgets read `AccentScope.of(context)` instead of taking an accent
/// parameter, so a card, its label bar and its Linger wash all agree without
/// threading colour through every constructor.
class AccentScope extends InheritedWidget {
  const new({required this.accent, required super.child, super.key});

  final SourceAccent accent;

  static SourceAccent of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccentScope>()?.accent ??
      SourceAccent.neutral;

  @override
  bool updateShouldNotify(AccentScope oldWidget) => accent != oldWidget.accent;
}
