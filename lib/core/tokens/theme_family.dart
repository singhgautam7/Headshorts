import 'package:flutter/widgets.dart';
import 'package:headshorts/core/tokens/oklab.dart';
import 'package:headshorts/core/tokens/oklch.dart';
import 'package:headshorts/core/tokens/palette.dart';

/// How dark a variant is. Pure black is not a mode: it is a toggle that only
/// applies while dark is in effect (the enum value keeps its old name,
/// `amoled`, because it is what settings and tests already say).
enum Tone { light, dark, amoled }

/// One accent family, resolving to an [HsPalette] per [Tone].
///
/// This is Kuber's family set with Kuber's numbers: [signature] is
/// HeadShorts' own (drawn from the app icon), [paper] is the design board's
/// token panel verbatim, and the rest are the OKLCh families Kuber carries
/// from Mull. Kuber maps them onto an M3 `ColorScheme`; here the same recipe
/// is mapped onto [HsPalette], so a family swap is a palette swap and nothing
/// downstream knows which family it got.
///
/// Role mapping (Kuber scheme role -> [HsPalette] role):
/// surface -> background, surfaceContainer -> surface, surfaceContainerHigh
/// -> surfaceVariant (and skeleton), onSurface -> textPrimary,
/// onSurfaceVariant -> textSecondary, outline -> textMuted (stepped until it
/// reads at 4.5:1), outlineVariant -> stroke, secondaryContainer ->
/// primaryContainer (and navActive), onSecondaryContainer ->
/// onPrimaryContainer.
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
    double? darkNeutralChroma,
    this.isSignature = false,
  }) : darkNeutralChroma = darkNeutralChroma ?? neutralChroma;

  /// Android hands over one wallpaper seed; the rest is derived exactly as a
  /// bundled family's is (Kuber `MullFamily.fromSeed`).
  factory fromSeed(Color seed) {
    final hue = Oklch.hueOf(seed);
    return ThemeFamily(
      id: 'dynamic',
      name: 'Dynamic',
      blurb: 'wallpaper',
      neutralHue: hue,
      neutralChroma: 1,
      primaryHue: hue,
      primaryLightness: 0.52,
      primaryChroma: 0.11,
      primaryContainerChroma: 0.04,
    );
  }

  final String id;
  final String name;
  final String blurb;

  /// Hue for the near-grey surfaces and text.
  final double neutralHue;

  /// Multiplier on the reference neutral chromas (light, and dark unless
  /// [darkNeutralChroma] says otherwise).
  final double neutralChroma;
  final double primaryHue;
  final double primaryLightness;
  final double primaryChroma;
  final double primaryContainerChroma;
  final double darkNeutralChroma;

  /// HeadShorts' own family: surfaces and accent from the app icon.
  final bool isSignature;

  /// The icon's red: `#D3453D`, OKLCh hue 27 (the dark mark is `#791A18`,
  /// the tint `#FFDDD9`, the dark splash `#291412`).
  static const _sigHue = 27.0;

  /// The icon, as a family. Kuber's `_signature` recipe with the hue swapped
  /// from blue to red; the numbers beside the hue are unused.
  static const signature = ThemeFamily(
    id: 'signature',
    name: 'Signature',
    blurb: 'classic red',
    neutralHue: _sigHue,
    neutralChroma: 1,
    primaryHue: _sigHue,
    primaryLightness: 0.5,
    primaryChroma: 0.15,
    primaryContainerChroma: 0.07,
    isSignature: true,
  );

  /// The design board's palette. Its tones are the three hand-set constants
  /// on [HsPalette], which are already neutral, so neither Expressive colours
  /// nor the wallpaper touches them: they come back byte for byte.
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

  static const mull = ThemeFamily(
    id: 'mull',
    name: 'Mull',
    blurb: 'teal blue',
    neutralHue: 215,
    neutralChroma: 1,
    primaryHue: 215,
    primaryLightness: 0.52,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
  );

  static const vellum = ThemeFamily(
    id: 'vellum',
    name: 'Vellum',
    blurb: 'warm',
    neutralHue: 80,
    neutralChroma: 1.3,
    primaryHue: 70,
    primaryLightness: 0.58,
    primaryChroma: 0.10,
    primaryContainerChroma: 0.04,
  );

  static const foxglove = ThemeFamily(
    id: 'foxglove',
    name: 'Foxglove',
    blurb: 'soft',
    neutralHue: 330,
    neutralChroma: 1.05,
    primaryHue: 325,
    primaryLightness: 0.55,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
  );

  static const slate = ThemeFamily(
    id: 'slate',
    name: 'Slate',
    blurb: 'mono',
    neutralHue: 215,
    neutralChroma: 0.4,
    primaryHue: 215,
    primaryLightness: 0.42,
    primaryChroma: 0.012,
    primaryContainerChroma: 0.006,
  );

  static const clay = ThemeFamily(
    id: 'clay',
    name: 'Clay',
    blurb: 'greige',
    neutralHue: 75,
    neutralChroma: 2.2,
    primaryHue: 45,
    primaryLightness: 0.50,
    primaryChroma: 0.055,
    primaryContainerChroma: 0.02,
    darkNeutralChroma: 1.2,
  );

  static const perch = ThemeFamily(
    id: 'perch',
    name: 'Perch',
    blurb: 'violet',
    neutralHue: 265,
    neutralChroma: 1,
    primaryHue: 265,
    primaryLightness: 0.52,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
  );

  static const ember = ThemeFamily(
    id: 'ember',
    name: 'Ember',
    blurb: 'amber',
    neutralHue: 55,
    neutralChroma: 1.35,
    primaryHue: 45,
    primaryLightness: 0.58,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
  );

  static const fern = ThemeFamily(
    id: 'fern',
    name: 'Fern',
    blurb: 'cool green',
    neutralHue: 160,
    neutralChroma: 1.15,
    primaryHue: 162,
    primaryLightness: 0.54,
    primaryChroma: 0.10,
    primaryContainerChroma: 0.04,
  );

  static const tide = ThemeFamily(
    id: 'tide',
    name: 'Tide',
    blurb: 'teal',
    neutralHue: 189,
    neutralChroma: 1,
    primaryHue: 189,
    primaryLightness: 0.50,
    primaryChroma: 0.09,
    primaryContainerChroma: 0.04,
  );

  static const blush = ThemeFamily(
    id: 'blush',
    name: 'Blush',
    blurb: 'rose',
    neutralHue: 359,
    neutralChroma: 1.05,
    primaryHue: 359,
    primaryLightness: 0.55,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
  );

  static const iris = ThemeFamily(
    id: 'iris',
    name: 'Iris',
    blurb: 'purple',
    neutralHue: 290,
    neutralChroma: 1,
    primaryHue: 290,
    primaryLightness: 0.55,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.04,
  );

  static const citron = ThemeFamily(
    id: 'citron',
    name: 'Citron',
    blurb: 'yellow green',
    neutralHue: 113,
    neutralChroma: 1.2,
    primaryHue: 113,
    primaryLightness: 0.55,
    primaryChroma: 0.10,
    primaryContainerChroma: 0.04,
  );

  static const neon = ThemeFamily(
    id: 'neon',
    name: 'Neon',
    blurb: 'vivid green',
    neutralHue: 147,
    neutralChroma: 0.8,
    primaryHue: 147,
    primaryLightness: 0.60,
    primaryChroma: 0.14,
    primaryContainerChroma: 0.05,
  );

  static const saffron = ThemeFamily(
    id: 'saffron',
    name: 'Saffron',
    blurb: 'gold',
    neutralHue: 90,
    neutralChroma: 1.25,
    primaryHue: 90,
    primaryLightness: 0.60,
    primaryChroma: 0.12,
    primaryContainerChroma: 0.05,
  );

  static const sky = ThemeFamily(
    id: 'sky',
    name: 'Sky',
    blurb: 'light blue',
    neutralHue: 238,
    neutralChroma: 1,
    primaryHue: 238,
    primaryLightness: 0.56,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
  );

  static const ruby = ThemeFamily(
    id: 'ruby',
    name: 'Ruby',
    blurb: 'red',
    neutralHue: 18,
    neutralChroma: 1.15,
    primaryHue: 18,
    primaryLightness: 0.50,
    primaryChroma: 0.16,
    primaryContainerChroma: 0.05,
  );

  /// Display order on the Theme screen.
  static const all = [
    signature,
    paper,
    mull,
    vellum,
    foxglove,
    slate,
    clay,
    perch,
    ember,
    fern,
    tide,
    blush,
    iris,
    citron,
    neon,
    saffron,
    sky,
    ruby,
  ];

  /// Unknown ids (a family since retired, a corrupt value) fall back to
  /// [signature].
  static ThemeFamily byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => signature);

  static final _palettes = <String, HsPalette>{};

  /// The palette for [tone]. [expressive] off swaps every surface, text and
  /// outline role for Kuber's neutral grey ramp while the accents stay put.
  HsPalette colors(Tone tone, {bool expressive = true}) {
    if (this == paper) {
      return switch (tone) {
        Tone.light => HsPalette.light,
        Tone.dark => HsPalette.dark,
        Tone.amoled => HsPalette.amoled,
      };
    }
    // The theme screen asks for eighteen families on every change; a family
    // is a pure function of these four things.
    return _palettes.putIfAbsent(
      '$id:$primaryHue:${tone.name}:$expressive',
      () => _build(tone, expressive),
    );
  }

  HsPalette _build(Tone tone, bool expressive) {
    final dark = tone != Tone.light;
    var r = isSignature ? _signatureRoles(dark) : _familyRoles(dark);
    if (!expressive) r = r.neutral(dark: dark);
    if (tone == Tone.amoled) r = _pureBlack(r, expressive);
    return _palette(r, dark);
  }

  // ---- Roles ---------------------------------------------------------------

  /// 8-bit colour, the values the design tables list.
  static Color _q(Oklch o) => Color(o.toColor().toARGB32());

  Color _n(double l, double c) => _q(Oklch(l, c * neutralChroma, neutralHue));
  Color _nd(double l, double c) =>
      _q(Oklch(l, c * darkNeutralChroma, neutralHue));
  Oklch _p(double l, double c) => Oklch(l, c, primaryHue);
  static Color _sq(double l, double c) => _q(Oklch(l, c, _sigHue));

  /// Contrast guard: the light primary steps down in 0.005 lightness until it
  /// reads at 4.5:1 as text on the deepest card fill (expressive and neutral)
  /// and under white labels.
  double get guardedLightness {
    final worst = [_n(.955, .014), _q(const Oklch(.965, 0, 0))];
    var l = primaryLightness;
    bool fails(double l) {
      final p = _q(_p(l, primaryChroma));
      return Oklab.contrast(const Color(0xFFFFFFFF), p) < 4.5 ||
          worst.any((w) => Oklab.contrast(p, w) < 4.5);
    }

    while (l > .3 && fails(l)) {
      l = ((l - .005) * 1000).round() / 1000;
    }
    return l;
  }

  _Roles _familyRoles(bool dark) {
    final pc = primaryChroma;
    if (!dark) {
      return _Roles(
        bg: _n(.985, .008),
        container: _n(.955, .014),
        high: _n(.93, .017),
        stroke: _n(.875, .02),
        outline: _n(.62, .02),
        onSurfaceVariant: _n(.50, .02),
        onSurface: _n(.20, .02),
        primary: _q(_p(guardedLightness, pc)),
        onPrimary: const Color(0xFFFFFFFF),
        soft: _p(.92, primaryContainerChroma).toColor(),
        onSoft: _p(.38, pc).toColor(),
      );
    }
    final pcd = pc * 0.81;
    return _Roles(
      bg: _nd(.205, .012),
      container: _nd(.255, .014),
      high: _nd(.30, .016),
      stroke: _nd(.36, .016),
      outline: _nd(.60, .012),
      onSurfaceVariant: _nd(.72, .012),
      onSurface: _nd(.96, .005),
      primary: _p(.74, pcd).toColor(),
      onPrimary: _nd(.14, .01),
      soft: _p(.28, pcd * .46).toColor(),
      onSoft: _p(.90, pcd * .46).toColor(),
    );
  }

  /// Kuber's `_signature` ladder at the icon's hue. The accent starts from
  /// `ColorScheme.fromSeed(#D3453D, fidelity)`, computed once and written
  /// down: dark primary `#FFB4AB` as the scheme has it; light primary is the
  /// scheme's `#AD2A25` taken one step deeper to `#A32621`, because `#AD2A25`
  /// reads only 4.27:1 on the soft container and the floor is 4.5 (this is
  /// 4.68 there, 7.35 on white). The soft container is Kuber's
  /// secondaryContainer: the icon's tint in light, a deep red in dark.
  _Roles _signatureRoles(bool dark) {
    if (!dark) {
      return _Roles(
        bg: _sq(.975, .016),
        container: _sq(.945, .03),
        high: _sq(.925, .036),
        stroke: _sq(.865, .045),
        outline: _sq(.58, .05),
        onSurfaceVariant: _sq(.45, .05),
        onSurface: _sq(.22, .04),
        primary: const Color(0xFFA32621),
        onPrimary: const Color(0xFFFFFFFF),
        soft: _sq(.86, .07),
        onSoft: const Color(0xFF791A18),
      );
    }
    return _Roles(
      bg: _sq(.19, .042),
      container: _sq(.245, .048),
      high: _sq(.29, .05),
      stroke: _sq(.37, .05),
      outline: _sq(.64, .04),
      onSurfaceVariant: _sq(.80, .03),
      onSurface: _sq(.95, .012),
      primary: const Color(0xFFFFB4AB),
      onPrimary: const Color(0xFF690006),
      soft: _sq(.36, .08),
      onSoft: const Color(0xFFFFDDD9),
    );
  }

  /// Kuber's pure-black ramp: the page is `#000000` and the containers sit
  /// just above it at the neutral hue (chroma 0 when not expressive). Text
  /// and accent keep their dark values.
  _Roles _pureBlack(_Roles r, bool expressive) {
    Color n(double l, double c) => _q(Oklch(l, expressive ? c : 0, neutralHue));
    return r.copyWith(
      bg: const Color(0xFF000000),
      container: n(.18, .008),
      high: n(.215, .010),
      stroke: n(.33, .014),
      soft: _q(_p(.30, isSignature ? .07 : .045)),
    );
  }

  // ---- Palette -------------------------------------------------------------

  HsPalette _palette(_Roles r, bool dark) {
    // textMuted is the outline role, which Kuber draws as a hairline and so
    // never held to a text contrast. Here it carries words, so it steps
    // toward the ink until it reads at 4.5:1 on the page.
    var muted = r.outline;
    for (var t = 0.0; Oklab.contrast(muted, r.bg) < 4.5 && t < 1;) {
      t += .05;
      muted = Oklab.mix(r.onSurface, r.outline, t);
    }
    return HsPalette(
      background: r.bg,
      lingerBackground: dark
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF),
      surface: r.container,
      surfaceVariant: r.high,
      textPrimary: r.onSurface,
      textSecondary: r.onSurfaceVariant,
      textMuted: muted,
      // A step toward the page from the stroke, as the board's own divider
      // sits against its stroke.
      divider: Oklab.mix(r.stroke, r.bg, .6),
      stroke: r.stroke,
      nav: r.container,
      navActive: r.soft,
      navShadow: dark
          ? const BoxShadow(
              color: Color(0x80000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            )
          : BoxShadow(
              color: Oklch(.35, .06, neutralHue, .09).toColor(),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
      scrim: dark
          ? const Color(0xB8000000)
          : r.onSurface.withValues(alpha: .32),
      skeleton: r.high,
      primary: r.primary,
      onPrimary: r.onPrimary,
      primaryContainer: r.soft,
      onPrimaryContainer: r.onSoft,
      isDark: dark,
    );
  }
}

/// The Kuber scheme roles a family fills in, before they are named for
/// [HsPalette].
@immutable
class _Roles {
  const new({
    required this.bg,
    required this.container,
    required this.high,
    required this.stroke,
    required this.outline,
    required this.onSurfaceVariant,
    required this.onSurface,
    required this.primary,
    required this.onPrimary,
    required this.soft,
    required this.onSoft,
  });

  final Color bg;
  final Color container;
  final Color high;
  final Color stroke;
  final Color outline;
  final Color onSurfaceVariant;
  final Color onSurface;
  final Color primary;
  final Color onPrimary;
  final Color soft;
  final Color onSoft;

  /// Kuber's neutral ramp (Expressive colours off): OKLCh chroma 0 for every
  /// surface, text and outline role; the accent and its soft container stay.
  _Roles neutral({required bool dark}) {
    Color g(double l) => ThemeFamily._q(Oklch(l, 0, 0));
    return copyWith(
      bg: g(dark ? .205 : 1),
      container: g(dark ? .255 : .965),
      high: g(dark ? .30 : .935),
      stroke: g(dark ? .36 : .885),
      outline: g(.60),
      onSurfaceVariant: g(dark ? .74 : .48),
      onSurface: g(dark ? .96 : .20),
    );
  }

  _Roles copyWith({
    Color? bg,
    Color? container,
    Color? high,
    Color? stroke,
    Color? soft,
    Color? outline,
    Color? onSurfaceVariant,
    Color? onSurface,
  }) => _Roles(
    bg: bg ?? this.bg,
    container: container ?? this.container,
    high: high ?? this.high,
    stroke: stroke ?? this.stroke,
    outline: outline ?? this.outline,
    onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
    onSurface: onSurface ?? this.onSurface,
    primary: primary,
    onPrimary: onPrimary,
    soft: soft ?? this.soft,
    onSoft: onSoft,
  );
}
