import 'package:flutter/widgets.dart';
import 'package:headshorts/core/tokens/oklab.dart';

/// Turns a raw colour — a publisher's brand red, a hue pulled from a favicon,
/// anything not drawn from the design board — into the accent tone for a
/// theme.
///
/// **A raw colour must never reach the UI.** Every accent in the app is either
/// one of the design board's own values or the output of this function.
///
/// The transform is calibrated from the board's nine accents, measured in
/// oklab: on black they all sit at lightness 0.74–0.79 with chroma at most
/// 0.108; on paper at 0.44–0.50 with chroma at most 0.131. A raw brand colour
/// is far outside that (#FF0000 is chroma 0.258), which is what makes it
/// shout. So the raw colour is desaturated to the board's ceiling and its
/// lightness moved into the board's band — the hue survives, the vibrancy does
/// not. A colour already inside the band comes back untouched.
Color accentFor(Brightness brightness, Color raw) {
  // Squeezing a colour back into 8-bit sRGB can move it, so one pass is not
  // always enough to land inside the band. Repeating until it stops changing
  // makes the result a fixed point, which is what keeps the function
  // idempotent — the catalog bakes derived accents into a file and the app
  // resolves them again at read time, and those two must agree.
  var accent = raw;
  for (var pass = 0; pass < _maxPasses; pass++) {
    final next = _towardsBand(brightness, accent);
    if (next.toARGB32() == accent.toARGB32()) return accent;
    accent = next;
  }
  return accent;
}

/// One step of the transform, or the colour unchanged if it is already in the
/// design board's register.
Color _towardsBand(Brightness brightness, Color raw) {
  final dark = brightness == Brightness.dark;
  final maxChroma = dark ? _darkChroma : _lightChroma;
  final (minLightness, maxLightness) = dark ? _darkLightness : _lightLightness;

  final chroma = Oklab.chroma(raw);
  final lightness = Oklab.lightness(raw);
  if (chroma <= maxChroma + _tolerance &&
      lightness >= minLightness - _tolerance &&
      lightness <= maxLightness + _tolerance) {
    return raw;
  }

  return Oklab.withLightness(
    Oklab.clampChroma(raw, maxChroma),
    lightness.clamp(minLightness, maxLightness),
  );
}

/// Enough passes to converge for any sRGB input, and a hard stop besides.
const _maxPasses = 8;

/// Slack for 8-bit quantisation, so [accentFor] is idempotent.
const _tolerance = 0.01;

const _darkChroma = 0.108;
const _lightChroma = 0.132;
const _darkLightness = (0.73, 0.80);
const _lightLightness = (0.43, 0.51);

/// A source's accent, held as the pair of tones the design board specifies:
/// a light tone that carries on true black, and a deep tone that carries on
/// paper. Same hue, inverted tone.
///
/// Accent is *label, hairline bar, and — Linger only — a wash panel*. It is
/// never a saturated card fill.
@immutable
class SourceAccent {
  const new(this.onDark, this.onLight);

  /// Derives both tones from a raw colour, for sources the user adds.
  ///
  /// Both go through [accentFor], so a publisher's brand colour arrives in the
  /// app already in the design board's register.
  factory fromSeed(Color seed) => SourceAccent(
    accentFor(Brightness.dark, seed),
    accentFor(Brightness.light, seed),
  );

  /// Deterministic accent for a source we know nothing about beyond its feed
  /// address — a stable hue per host, so a source keeps its colour forever.
  factory fromKey(String key) {
    final hue = (key.hashCode.abs() % 360).toDouble();
    return SourceAccent.fromSeed(
      HSLColor.fromAHSL(1, hue, 0.45, 0.6).toColor(),
    );
  }

  /// The stored pair, read back. The database keeps the two tones as two
  /// integers; this is the one place they become an accent again.
  factory fromValues(int dark, int light) =>
      SourceAccent(Color(dark), Color(light));

  /// The neutral "source", used where the accent should read as plain ink:
  /// the caught-up rule, the welcome mark, the Linger hard stop.
  ///
  /// Deliberately outside [accentFor]'s band — this is the text colour doing
  /// an accent's job, not an accent.
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
