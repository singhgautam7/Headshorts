import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/oklab.dart';
import 'package:headshorts/core/tokens/oklch.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/theme_family.dart';

double _c(Color a, Color b) => Oklab.contrast(a, b);

void main() {
  group('families', () {
    test('Signature leads, then Paper, then the rest in Kuber order', () {
      expect(ThemeFamily.all.map((f) => f.id), [
        'signature',
        'paper',
        'mull',
        'vellum',
        'foxglove',
        'slate',
        'clay',
        'perch',
        'ember',
        'fern',
        'tide',
        'blush',
        'iris',
        'citron',
        'neon',
        'saffron',
        'sky',
        'ruby',
      ]);
      expect(ThemeFamily.signature.name, 'HeadShorts Signature');
      expect(ThemeFamily.signature.blurb, 'classic red');
      expect(ThemeFamily.mull.blurb, 'teal blue');
    });

    test('an unknown id falls back to Signature; a known one is kept', () {
      expect(ThemeFamily.byId('nope'), ThemeFamily.signature);
      expect(ThemeFamily.byId('paper'), ThemeFamily.paper);
      expect(ThemeFamily.byId('ruby'), ThemeFamily.ruby);
    });

    test('Signature takes the icon red as its hue', () {
      expect(
        ThemeFamily.signature.primaryHue,
        closeTo(Oklch.hueOf(const Color(0xFFD3453D)), 0.5),
      );
    });

    test('every family x tone x expressive builds a theme', () {
      for (final f in [...ThemeFamily.all, ThemeFamily.fromSeed(Colors.teal)]) {
        for (final tone in Tone.values) {
          for (final expressive in [true, false]) {
            final t = hsThemeOf(f, tone, expressive: expressive);
            expect(t.extension<HsThemeExtension>(), isNotNull);
            expect(
              t.brightness,
              tone == Tone.light ? Brightness.light : Brightness.dark,
            );
          }
        }
      }
    });

    test('text and accents hold their contrast floors everywhere', () {
      final misses = <String>[];
      void check(String what, double got, double floor) {
        if (got < floor) misses.add('$what ${got.toStringAsFixed(2)} < $floor');
      }

      for (final f in [...ThemeFamily.all, ThemeFamily.fromSeed(Colors.teal)]) {
        for (final tone in Tone.values) {
          for (final expressive in [true, false]) {
            final p = f.colors(tone, expressive: expressive);
            final w = '${f.id}/${tone.name}/${expressive ? 'tint' : 'grey'}';
            check('$w textPrimary', _c(p.textPrimary, p.background), 7);
            check('$w textSecondary', _c(p.textSecondary, p.background), 4.5);
            // The board's own muted ink is its hand-set constant, below 4.5
            // since before families; Paper is deliberately left as drawn.
            if (f != ThemeFamily.paper) {
              check('$w textMuted', _c(p.textMuted, p.background), 4.5);
            }
            check('$w primary/bg', _c(p.primary, p.background), 3);
            check('$w onPrimary/primary', _c(p.onPrimary, p.primary), 4.5);
            check(
              '$w onPrimaryContainer',
              _c(p.onPrimaryContainer, p.primaryContainer),
              4.5,
            );
          }
        }
      }
      expect(misses, isEmpty, reason: misses.join('\n'));
    });

    test('Signature red reads on the icon tint and on white', () {
      final p = ThemeFamily.signature.colors(Tone.light);
      expect(_c(p.primary, const Color(0xFFFFFFFF)), greaterThanOrEqualTo(4.5));
      expect(_c(p.primary, p.primaryContainer), greaterThanOrEqualTo(4.5));
      expect(p.onPrimaryContainer, const Color(0xFF791A18));
      expect(
        ThemeFamily.signature.colors(Tone.dark).onPrimaryContainer,
        const Color(0xFFFFDDD9),
      );
    });
  });

  group('surface rule', () {
    test('expressive off draws surfaces and text without chroma', () {
      for (final f in ThemeFamily.all) {
        if (f == ThemeFamily.paper) continue;
        for (final tone in Tone.values) {
          final p = f.colors(tone, expressive: false);
          for (final c in [
            p.background,
            p.surface,
            p.surfaceVariant,
            p.textPrimary,
            p.textSecondary,
            p.stroke,
          ]) {
            expect(
              Oklab.chroma(c),
              lessThan(0.006),
              reason: '${f.id} ${tone.name}',
            );
          }
        }
      }
    });

    test('expressive on tints a family, and leaves its accent alone', () {
      final on = ThemeFamily.ember.colors(Tone.light);
      final off = ThemeFamily.ember.colors(Tone.light, expressive: false);
      expect(Oklab.chroma(on.surface), greaterThan(0.01));
      expect(on.primary, off.primary);
      expect(on.primaryContainer, off.primaryContainer);
    });

    test('pure black is a true black page in every family, both ways', () {
      for (final f in ThemeFamily.all) {
        for (final expressive in [true, false]) {
          final p = f.colors(Tone.amoled, expressive: expressive);
          expect(p.background, const Color(0xFF000000), reason: f.id);
          expect(p.lingerBackground, const Color(0xFF000000));
          expect(p.isDark, isTrue);
        }
      }
    });

    test('Paper is the board byte for byte, whatever the switches say', () {
      for (final expressive in [true, false]) {
        expect(
          ThemeFamily.paper.colors(Tone.light, expressive: expressive),
          same(HsPalette.light),
        );
        expect(
          ThemeFamily.paper.colors(Tone.dark, expressive: expressive),
          same(HsPalette.dark),
        );
        expect(
          ThemeFamily.paper.colors(Tone.amoled, expressive: expressive),
          same(HsPalette.amoled),
        );
      }
    });

    test('the wallpaper family takes its hue from the seed', () {
      const seed = Color(0xFF2E7D32);
      final f = ThemeFamily.fromSeed(seed);
      expect(f.primaryHue, closeTo(Oklch.hueOf(seed), 0.001));
      expect(
        f.colors(Tone.light).primary,
        isNot(ThemeFamily.mull.colors(Tone.light).primary),
      );
    });

    test('themes are cached per family, tone and expressive', () {
      expect(
        identical(
          hsThemeOf(ThemeFamily.fern, Tone.dark),
          hsThemeOf(ThemeFamily.fern, Tone.dark),
        ),
        isTrue,
      );
      expect(
        identical(
          hsThemeOf(ThemeFamily.fern, Tone.dark),
          hsThemeOf(ThemeFamily.fern, Tone.dark, expressive: false),
        ),
        isFalse,
      );
    });
  });

  test('themeFor resolves mode, pure black and the seed', () {
    ThemeData t({
      ThemeMode mode = ThemeMode.dark,
      bool amoled = true,
      bool systemDark = false,
      Color? seed,
    }) => themeFor(
      familyId: 'signature',
      mode: mode,
      amoled: amoled,
      systemDark: systemDark,
      seed: seed,
    );
    expect(t().scaffoldBackgroundColor, const Color(0xFF000000));
    expect(
      t(amoled: false).scaffoldBackgroundColor,
      isNot(const Color(0xFF000000)),
    );
    expect(t(mode: ThemeMode.light).brightness, Brightness.light);
    expect(
      t(mode: ThemeMode.system, systemDark: true).brightness,
      Brightness.dark,
    );
    expect(
      t(
        mode: ThemeMode.light,
        seed: const Color(0xFF2E7D32),
      ).colorScheme.primary,
      isNot(t(mode: ThemeMode.light).colorScheme.primary),
    );
  });
}
