import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart' show Brightness, HSVColor;
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/oklab.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/widgets/controls.dart';

import 'package:headshorts/data/sources/source_catalog.dart';

/// The nine accents the design board lists for AMOLED.
const _boardDark = [
  Color(0xFFE4A868), // The Hindu
  Color(0xFFE39191), // BBC News
  Color(0xFF93B4DC), // Reuters
  Color(0xFF9FC3A3), // The Indian Express
  Color(0xFFB6A6DE), // Ars Technica
  Color(0xFF86C0BC), // Al Jazeera
  Color(0xFFC6BE7E), // Scroll.in
  Color(0xFFD8A2C4), // The Verge
];

const _boardLight = [
  Color(0xFF8A5518),
  Color(0xFF9C3A3C),
  Color(0xFF2F567F),
  Color(0xFF37653F),
  Color(0xFF574289),
  Color(0xFF226663),
  Color(0xFF6B6323),
  Color(0xFF8A3C70),
];

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}';

void main() {
  group('Oklab.mix', () {
    test('matches color-mix(in oklab, #E39191 15%, #000)', () {
      // The design board's Linger wash. In sRGB the same 15% comes out
      // #221616 — about three times brighter — which is what made the accent
      // read as vibrant on true black.
      expect(
        _hex(Oklab.mix(const Color(0xFFE39191), const Color(0xFF000000), 0.15)),
        '#090303',
      );
    });

    test('matches color-mix(in oklab, #8A5518 7%, #F4F1EA)', () {
      expect(
        _hex(Oklab.mix(const Color(0xFF8A5518), const Color(0xFFF4F1EA), 0.07)),
        '#EDE6DB',
      );
    });

    test('matches color-mix(in oklab, #E39191 40%, #EFECE6)', () {
      // The Linger headline tint.
      expect(
        _hex(Oklab.mix(const Color(0xFFE39191), const Color(0xFFEFECE6), 0.4)),
        '#EDC8C3',
      );
    });

    test('is the identity at the ends', () {
      const a = Color(0xFF93B4DC);
      const b = Color(0xFF000000);
      expect(Oklab.mix(a, b, 1), a);
      expect(_hex(Oklab.mix(a, b, 0)), _hex(b));
    });
  });

  group('accentFor', () {
    test("leaves the design board's own AMOLED accents untouched", () {
      for (final accent in _boardDark) {
        expect(
          _hex(accentFor(Brightness.dark, accent)),
          _hex(accent),
          reason: '${_hex(accent)} is already a board value',
        );
      }
    });

    test("leaves the design board's own paper accents untouched", () {
      for (final accent in _boardLight) {
        expect(_hex(accentFor(Brightness.light, accent)), _hex(accent));
      }
    });

    test("pulls a raw brand colour into the board's register", () {
      // A publisher's brand red is far outside the band: chroma 0.258 against
      // the board's ceiling of 0.108.
      const brandRed = Color(0xFFFF0000);
      final tamed = accentFor(Brightness.dark, brandRed);

      expect(Oklab.chroma(brandRed), greaterThan(0.25));
      expect(Oklab.chroma(tamed), lessThanOrEqualTo(0.11));
      expect(Oklab.lightness(tamed), inInclusiveRange(0.72, 0.81));
    });

    test('keeps the hue while dropping the vibrancy', () {
      const brandBlue = Color(0xFF1DA1F2);
      final tamed = accentFor(Brightness.dark, brandBlue);
      // Still recognisably blue: the blue channel stays the largest.
      expect(tamed.b, greaterThan(tamed.r));
      expect(tamed.b, greaterThan(tamed.g));
    });

    test('the paper tone is deep and the black tone is light', () {
      const raw = Color(0xFFBB1919);
      expect(
        Oklab.lightness(accentFor(Brightness.light, raw)),
        lessThan(Oklab.lightness(accentFor(Brightness.dark, raw))),
      );
    });

    test('is idempotent — applying it twice changes nothing', () {
      // The catalog bakes derived accents into a file, and the app resolves
      // them again at read time. If those disagreed, every launch would shift
      // a channel.
      for (var hue = 0; hue < 360; hue += 15) {
        final raw = HSVColor.fromAHSV(1, hue.toDouble(), 1, 1).toColor();
        for (final brightness in Brightness.values) {
          final once = accentFor(brightness, raw);
          expect(
            _hex(accentFor(brightness, once)),
            _hex(once),
            reason: 'hue $hue on $brightness',
          );
        }
      }
    });

    test('every derived accent lands in the band, whatever the input', () {
      // Fully saturated input at every hue — the worst case. Tolerances allow
      // for sRGB gamut clipping, which can nudge a very chromatic hue a little
      // past the target once it is squeezed back into 8-bit colour.
      for (var hue = 0; hue < 360; hue += 15) {
        final raw = HSVColor.fromAHSV(1, hue.toDouble(), 1, 1).toColor();
        for (final brightness in Brightness.values) {
          final accent = accentFor(brightness, raw);
          expect(
            Oklab.chroma(accent),
            lessThanOrEqualTo(0.14),
            reason: 'hue $hue on $brightness stayed too chromatic',
          );
          expect(
            Oklab.lightness(accent),
            brightness == Brightness.dark
                ? inInclusiveRange(0.70, 0.83)
                : inInclusiveRange(0.40, 0.54),
            reason: 'hue $hue on $brightness left the band',
          );
          // Whatever the hue, the result is calmer than what went in.
          expect(Oklab.chroma(accent), lessThan(Oklab.chroma(raw)));
        }
      }
    });
  });

  group('accentWash', () {
    test('is a whisper of hue on black, not a coloured ground', () {
      final wash = accentWash(const Color(0xFFE39191), HsPalette.amoled);
      // Barely above the ground it sits on.
      expect(Oklab.lightness(wash), lessThan(0.2));
      expect(_hex(wash), '#090303');
    });

    test('is a pale tint on paper, and paper is unchanged by the fix', () {
      final wash = accentWash(const Color(0xFF8A5518), HsPalette.light);
      expect(_hex(wash), '#EDE6DB');
    });
  });

  group('the bundled catalog', () {
    late final catalog = SourceCatalog.parse(
      File(SourceCatalog.assetPath).readAsStringSync(),
    );

    test("ships the design board's accents, unaltered", () {
      final dark = catalog.sources.map((s) => _hex(s.accent.onDark)).toSet();
      for (final accent in _boardDark) {
        expect(dark, contains(_hex(accent)));
      }
    });

    test('every catalog accent is already inside the band', () {
      // Derived tones go through accentFor when the file is generated, so
      // resolving one again must change nothing.
      for (final source in catalog.sources) {
        expect(
          _hex(accentFor(Brightness.dark, source.accent.onDark)),
          _hex(source.accent.onDark),
          reason: source.title,
        );
        expect(
          _hex(accentFor(Brightness.light, source.accent.onLight)),
          _hex(source.accent.onLight),
          reason: source.title,
        );
      }
    });
  });
}
