import 'dart:math' as math;
import 'dart:ui' show Color;

/// CSS `color-mix(in oklab, …)`, which is what the design board's colour
/// arithmetic is written in.
///
/// This matters more than it looks. Mixing 15% of a light accent into black in
/// sRGB gives roughly three times the brightness that the same mix gives in
/// oklab, because sRGB interpolates encoded values rather than perceived
/// lightness. Blending the Linger wash in sRGB is what made the accent read as
/// vibrant on true black instead of as a whisper of hue.
abstract final class Oklab {
  /// Mixes [a] into [b] at [t], the way `color-mix(in oklab, a t%, b)` does.
  ///
  /// [t] is the weight of [a], from 0 to 1.
  static Color mix(Color a, Color b, double t) {
    final w = t.clamp(0.0, 1.0);
    // Short-circuit the ends: a round trip through oklab and back into 8-bit
    // sRGB can shift a channel by one, and the ends should be exact.
    if (w == 1) return a;
    if (w == 0) return b;
    final left = _toOklab(a);
    final right = _toOklab(b);
    return _toColor([
      for (var i = 0; i < 3; i++) left[i] * w + right[i] * (1 - w),
    ], alpha: a.a * w + b.a * (1 - w));
  }

  /// The perceived lightness of a colour, 0 (black) to 1 (white).
  ///
  /// Used to keep a derived accent inside the range the design board's own
  /// accents occupy.
  static double lightness(Color color) => _toOklab(color)[0];

  /// Returns [color] with its perceived lightness moved to [target], keeping
  /// its hue and chroma.
  static Color withLightness(Color color, double target) {
    final lab = _toOklab(color)..[0] = target.clamp(0.0, 1.0);
    return _toColor(lab, alpha: color.a);
  }

  /// The chroma (colourfulness) of a colour in oklab units. The design board's
  /// accents all sit below about 0.09.
  static double chroma(Color color) {
    final lab = _toOklab(color);
    return math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
  }

  /// Returns [color] with its chroma scaled to at most [maximum], keeping its
  /// hue and lightness.
  static Color clampChroma(Color color, double maximum) {
    final lab = _toOklab(color);
    final current = math.sqrt(lab[1] * lab[1] + lab[2] * lab[2]);
    if (current <= maximum || current == 0) return color;
    final scale = maximum / current;
    return _toColor([lab[0], lab[1] * scale, lab[2] * scale], alpha: color.a);
  }

  // ---- Conversions ---------------------------------------------------------

  static double _toLinear(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

  static double _toGamma(double channel) => channel <= 0.0031308
      ? channel * 12.92
      : 1.055 * math.pow(channel, 1 / 2.4).toDouble() - 0.055;

  static List<double> _toOklab(Color color) {
    final r = _toLinear(color.r);
    final g = _toLinear(color.g);
    final b = _toLinear(color.b);

    final l = math
        .pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3)
        .toDouble();
    final m = math
        .pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3)
        .toDouble();
    final s = math
        .pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3)
        .toDouble();

    return [
      0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.782771766 * m - 0.808675766 * s,
    ];
  }

  static Color _toColor(List<double> lab, {required double alpha}) {
    final l = math
        .pow(lab[0] + 0.3963377774 * lab[1] + 0.2158037573 * lab[2], 3)
        .toDouble();
    final m = math
        .pow(lab[0] - 0.1055613458 * lab[1] - 0.0638541728 * lab[2], 3)
        .toDouble();
    final s = math
        .pow(lab[0] - 0.0894841775 * lab[1] - 1.2914855480 * lab[2], 3)
        .toDouble();

    return Color.from(
      alpha: alpha,
      red: _channel(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
      green: _channel(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
      blue: _channel(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s),
    );
  }

  static double _channel(double linear) => _toGamma(linear).clamp(0.0, 1.0);
}
