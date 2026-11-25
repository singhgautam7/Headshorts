import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/spring_curve.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/app_icon_button.dart';
import 'package:headshorts/data/prefs/settings.dart';

export 'package:headshorts/core/widgets/header_preview.dart';

/// Geometry of the floating header (Kuber's `_Fh`, same values). The
/// thresholds and timings live on [HsMotion] (`pillAt`, `headerAt`, ...).
abstract final class HeaderSpec {
  /// Rest: 14 above the 48 dp row, 12 below it.
  static const double padTop = 14;
  static const double padBottom = HsSpace.x3;
  static const double row = 48;

  /// The pill: 12 in from each side, 8 under the status bar, 56 tall, radius
  /// 28.
  static const double margin = 12;
  static const double top = 8;
  static const double pillHeight = 56;
  static const double radius = 28;

  /// Leaving: the pill travels this far up while it fades.
  static const double hideDistance = 72;

  /// Narrower than this the pill drops its title (its semantics stay).
  static const double minTitle = 96;

  /// A side without a button gives the title this much more room.
  static const double noButtonShift = 8;

  /// Where in the morph the dropped title is gone.
  static const double titleDropEnd = 0.6;
}

/// A fixed floating-header setting for a preview (the settings page's mini
/// pages): ignores the real settings.
class HeaderPreviewSpec {
  const new({required this.floating, required this.pill});

  final bool floating;
  final PillMode pill;
}

/// The one header. Every tab root and pushed page uses this and nothing else,
/// inside a [HeaderPage].
///
/// Left: an optional circular back (or close) button, then the title. Right:
/// the page's actions. Inside a [HeaderPage] it turns into a floating pill on
/// scroll and holds exactly the same widgets, in the same order.
///
/// A tab [root] sets its title in the serif screen title and scales it down
/// into the pill; a pushed page sets it in the sans bar title at both sizes.
class AppHeader extends StatelessWidget {
  const new({
    required this.title,
    this.onBack,
    this.actions = const <Widget>[],
    this.backLabel = 'Back',
    this.backIcon = Icons.arrow_back_rounded,
    this.root = false,
    this.titleStyle,
    super.key,
  });

  /// Counts builds. A scroll must not grow it: the header rebuilds only on a
  /// state change (`header_test` reads it).
  static int debugBuildCount = 0;

  final String title;

  /// Null on a tab root, which has nowhere to go back to.
  final VoidCallback? onBack;
  final List<Widget> actions;
  final String backLabel;

  /// A form closes (`close_rounded`) rather than goes back.
  final IconData backIcon;

  /// A tab root: the serif title at rest.
  final bool root;

  /// Overrides the title's style at rest (the Reader's source label).
  final TextStyle? titleStyle;

  TextStyle get _style =>
      titleStyle ?? (root ? HsType.screenTitle : HsType.appBarTitle);

  /// The pill's title is never larger than the bar title.
  double get _pillScale {
    final rest = _style.fontSize ?? 16;
    return math.min(1, (HsType.appBarTitle.fontSize ?? 16) / rest);
  }

  double _lineHeight(BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(text: 'Ag', style: _style),
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final h = tp.height;
    tp.dispose();
    return h;
  }

  /// Exact height of the header at rest below the status bar (measured, so it
  /// holds at every text size).
  double restHeight(BuildContext context) =>
      HeaderSpec.padTop +
      math.max(HeaderSpec.row, _lineHeight(context)) +
      HeaderSpec.padBottom;

  @override
  Widget build(BuildContext context) {
    debugBuildCount++;
    final scope = _HeaderScope.maybeOf(context);
    final palette = context.hs;
    final hasBack = onBack != null;
    final line = _lineHeight(context);
    final content = SizedBox(
      height: scope?.restHeight ?? restHeight(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hasBack ? HsSpace.x5 - 4 : HsSpace.x5,
          HeaderSpec.padTop,
          actions.isEmpty ? HsSpace.x5 : HsSpace.x5 - 4,
          HeaderSpec.padBottom,
        ),
        child: Row(
          children: [
            if (hasBack) ...[
              HsIconButton(
                icon: backIcon,
                onPressed: onBack,
                semanticLabel: backLabel,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: _TitleSlot(
                title: title,
                style:
                    titleStyle ?? _style.copyWith(color: palette.textPrimary),
                lineHeight: line,
                pillScale: _pillScale,
                progress: (scope?.floating ?? false)
                    ? scope!.progress
                    : kAlwaysDismissedAnimation,
                leadShift: hasBack ? 0 : HeaderSpec.noButtonShift,
                trailShift: actions.isEmpty ? HeaderSpec.noButtonShift : 0,
                // Largest font: the title leaves the pill, its semantics stay.
                dropBelow: MediaQuery.textScalerOf(context).scale(1) >= 1.5
                    ? double.infinity
                    : HeaderSpec.minTitle,
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );

    if (scope == null) return content;
    if (scope.floating) return _FloatingSurface(scope: scope, child: content);
    // Fixed (Floating header off): an overlay, so it carries its own fill.
    return ColoredBox(
      color: palette.background,
      child: Padding(
        padding: EdgeInsets.only(top: scope.statusBar),
        child: content,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The page: header + body, one scroll listener.
// ---------------------------------------------------------------------------

/// What a descendant [AppHeader] reads. Changes only when the level, the
/// floating flag or the metrics change; per-frame values are animations.
class _HeaderScope extends InheritedWidget {
  const new({
    required this.hide,
    required this.hidden,
    required this.pins,
    required this.progress,
    required this.restAlpha,
    required this.pillAlpha,
    required this.contentAlpha,
    required this.pilled,
    required this.level,
    required this.floating,
    required this.statusBar,
    required this.restHeight,
    required super.child,
  });

  /// The pill leaving and back, for a [HeaderSearchBar].
  final Animation<double> hide;
  final ValueListenable<bool> hidden;

  /// The Floating header setting: whether a [HeaderSearchBar] sticks.
  final bool pins;

  /// 0 at rest, 1 in the pill. Unbounded: the spring may overshoot.
  final Animation<double> progress;

  /// Subtle: the two layers' alphas.
  final Animation<double> restAlpha;
  final Animation<double> pillAlpha;
  final Animation<double> contentAlpha;

  /// Whether the header is the pill (for semantics), not per frame.
  final ValueListenable<bool> pilled;
  final MotionLevel level;

  /// True when the header can become the pill.
  final bool floating;
  final double statusBar;
  final double restHeight;

  static _HeaderScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HeaderScope>();

  @override
  bool updateShouldNotify(_HeaderScope old) =>
      level != old.level ||
      floating != old.floating ||
      pins != old.pins ||
      statusBar != old.statusBar ||
      restHeight != old.restHeight;
}

/// Header + scrollable body, as one unit: the header floats over the body,
/// turns into the pill on scroll and (setting) hides with direction.
///
/// The body fills the screen and starts with [gap] (or [sliverGap]) so the
/// first row sits under the header at rest; it scrolls beneath the pill.
/// Only the header is sticky, or, with [scrollAway], a [HeaderSearchBar].
class HeaderPage extends ConsumerStatefulWidget {
  const new({
    required this.header,
    required this.body,
    this.floating = true,
    this.scrollAway = false,
    this.preview,
    super.key,
  });

  final AppHeader header;
  final Widget body;

  /// False: the header stays fixed at rest (no pill, never hides, never
  /// scrolls away).
  final bool floating;

  /// True: the header scrolls away with the content and a [HeaderSearchBar]
  /// below it becomes the pill instead (the Search tab).
  final bool scrollAway;

  /// Settings page previews only.
  final HeaderPreviewSpec? preview;

  /// The space the header takes: status bar plus the rest header. Read from a
  /// context below the page (use [gap] or a Builder); above it, it is 0.
  static double insetOf(BuildContext context) {
    final s = context.getInheritedWidgetOfExactType<_HeaderScope>();
    return s == null ? 0 : s.statusBar + s.restHeight;
  }

  /// Whether the header is currently the pill (read once, not listened to).
  static bool isPilled(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_HeaderScope>()?.pilled.value ??
      false;

  /// The first child of the body's list.
  ///
  /// [less] takes back the empty part of a tap region that comes first, so the
  /// thing seen starts where it does on every other page.
  static Widget gap({double less = 0}) =>
      Builder(builder: (c) => SizedBox(height: insetOf(c) - less));

  /// The first sliver of a `CustomScrollView`.
  static Widget sliverGap() => Builder(
    builder: (c) => SliverToBoxAdapter(child: SizedBox(height: insetOf(c))),
  );

  @override
  ConsumerState<HeaderPage> createState() => _HeaderPageState();
}

class _HeaderPageState extends ConsumerState<HeaderPage>
    with TickerProviderStateMixin {
  /// 0 header, 1 pill (unbounded: springs overshoot).
  late final AnimationController _p = AnimationController.unbounded(
    vsync: this,
  );

  /// Subtle: rest and pill layer alphas.
  late final AnimationController _a0 = AnimationController(
    vsync: this,
    value: 1,
  );
  late final AnimationController _a1 = AnimationController(vsync: this);

  /// Subtle: the 4 dp settle into the pill.
  late final AnimationController _shift = AnimationController.unbounded(
    vsync: this,
  );

  /// 0 shown, 1 hidden (unbounded: springs overshoot).
  late final AnimationController _h = AnimationController.unbounded(
    vsync: this,
  );

  /// The status-bar scrim.
  late final AnimationController _scrim = AnimationController(vsync: this);
  final ProxyAnimation _contentAlpha = ProxyAnimation(kAlwaysCompleteAnimation);

  /// Floating header off: how far the content has carried the header up.
  final ValueNotifier<double> _away = ValueNotifier<double>(0);
  final ValueNotifier<bool> _hiddenN = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _pillN = ValueNotifier<bool>(false);

  bool _pill = false;
  bool _scrolled = false;
  double _pixels = 0;
  double _down = 0;
  double _up = 0;
  double _moved = 0;
  Timer? _showTimer;
  MotionLevel _level = MotionLevel.expressive;
  bool _on = true;

  /// The Floating header setting itself ([_on] also needs `scrollAway` off).
  bool _setting = true;
  PillMode _mode = PillMode.always;
  double _headerExtent = 0;

  bool get _floats => _on && widget.floating;

  @override
  void didUpdateWidget(HeaderPage old) {
    super.didUpdateWidget(old);
    if (old.floating != widget.floating) {
      _setHidden(hidden: false);
      _setPill(pill: _floats && _pixels >= HsMotion.pillAt);
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    for (final c in [_p, _a0, _a1, _shift, _h, _scrim]) {
      c.dispose();
    }
    _away.dispose();
    _hiddenN.dispose();
    _pillN.dispose();
    super.dispose();
  }

  // ---- State changes (only on thresholds or direction) ----

  void _setPill({required bool pill}) {
    if (pill == _pill) return;
    _pill = pill;
    _pillN.value = pill;
    final t = pill ? 1.0 : 0.0;
    switch (_level) {
      case MotionLevel.expressive:
        unawaited(
          _p.springTo(
            t,
            pill ? HsMotion.springDefault : HsMotion.springStandard,
          ),
        );
      case MotionLevel.subtle:
        // Two layers at their exact bounds: the outgoing one fades out
        // quickly, the incoming one fades in (settling 4 dp down into the
        // pill). No bounds morph.
        _p.value = t;
        _a0.animateTo(
          1 - t,
          duration: pill ? HsMotion.fxInstant : HsMotion.fxFast,
          curve: HsMotion.curveEffects,
        );
        _a1.animateTo(
          t,
          duration: pill ? HsMotion.fxFast : HsMotion.fxInstant,
          curve: HsMotion.curveEffects,
        );
        _contentAlpha.parent = pill ? _a1 : _a0;
        if (pill) {
          _shift.value = 4;
          unawaited(_shift.springTo(0, HsMotion.springSubtle));
        } else {
          _shift.value = 0;
        }
        _scrim.animateTo(
          t,
          duration: pill ? HsMotion.fxDefault : HsMotion.fxFast,
          curve: HsMotion.curveEffects,
        );
      case MotionLevel.off:
        _p.value = t;
        _scrim.value = t;
    }
  }

  void _setHidden({required bool hidden}) {
    if (hidden == _hiddenN.value) return;
    _hiddenN.value = hidden;
    final t = hidden ? 1.0 : 0.0;
    switch (_level) {
      case MotionLevel.expressive:
        unawaited(
          _h.springTo(
            t,
            hidden ? HsMotion.springStandard : HsMotion.springDefault,
          ),
        );
      case MotionLevel.subtle:
        _h.animateTo(
          t,
          duration: HsMotion.fxFast,
          curve: HsMotion.curveEffects,
        );
      case MotionLevel.off:
        _h.animateTo(t, duration: HsMotion.fxInstant);
    }
  }

  void _setScrolled({required bool scrolled}) {
    if (scrolled == _scrolled) return;
    _scrolled = scrolled;
    if (_level == MotionLevel.off) {
      _scrim.value = scrolled ? 1 : 0;
    } else {
      _scrim.animateTo(
        scrolled ? 1 : 0,
        duration: HsMotion.fxDefault,
        curve: HsMotion.curveEffects,
      );
    }
  }

  /// Jump every value to the exact state for the current offset (first build,
  /// a setting or level change).
  void _snap() {
    _showTimer?.cancel();
    _down = _up = _moved = 0;
    _pill = _floats && _pixels >= HsMotion.pillAt;
    _pillN.value = _pill;
    final t = _pill ? 1.0 : 0.0;
    _p.value = t;
    _a0.value = 1 - t;
    _a1.value = t;
    _shift.value = 0;
    _contentAlpha.parent = _level == MotionLevel.subtle
        ? (_pill ? _a1 : _a0)
        : kAlwaysCompleteAnimation;
    _hiddenN.value = false;
    _h.value = 0;
    _scrolled = _pixels > 0;
    final carried = !_on && widget.floating;
    _scrim.value = !_on ? (_scrolled ? 1 : 0) : t;
    _away.value = carried ? _pixels.clamp(0, _headerExtent) : 0;
  }

  bool _keyboardOpen() => View.of(context).viewInsets.bottom > 0;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final px = n.metrics.pixels - n.metrics.minScrollExtent;
    _pixels = px;
    if (!_on && widget.floating) {
      final a = px.clamp(0.0, _headerExtent);
      if (a != _away.value) _away.value = a;
      _setScrolled(scrolled: px > 0);
      // A search pill takes over once the header has gone, and follows the
      // same "Show the pill" setting.
      if (widget.scrollAway && _setting) {
        if (px > _headerExtent + HsMotion.headerAt) {
          _hideByMode(n);
        } else {
          _setHidden(hidden: false);
          _showTimer?.cancel();
          _down = _up = _moved = 0;
        }
      }
      return false;
    }
    if (!_floats) return false;
    if (!_pill && px >= HsMotion.pillAt) {
      _setPill(pill: true);
    } else if (_pill && px <= HsMotion.headerAt) {
      _setPill(pill: false);
      _setHidden(hidden: false);
      _showTimer?.cancel();
      _down = _up = _moved = 0;
    }
    if (_pill) _hideByMode(n);
    return false;
  }

  /// "Show the pill": hides and shows whatever is the pill as the list moves.
  void _hideByMode(ScrollNotification n) {
    final delta = n is ScrollUpdateNotification ? (n.scrollDelta ?? 0) : 0.0;
    switch (_mode) {
      case PillMode.scrollUp:
        if (delta > 0) {
          _down += delta;
          _up = 0;
          if (_down > HsMotion.pillHideAfter && !_keyboardOpen()) {
            _setHidden(hidden: true);
          }
        } else if (delta < 0) {
          _up -= delta;
          _down = 0;
          if (_up > HsMotion.pillShowAfter) _setHidden(hidden: false);
        }
      case PillMode.scrollStop:
        if (delta != 0) {
          _showTimer?.cancel();
          _moved += delta.abs();
          if (_moved > HsMotion.pillHideAfter && !_keyboardOpen()) {
            _setHidden(hidden: true);
          }
        } else if (n is ScrollEndNotification) {
          _moved = 0;
          _showTimer?.cancel();
          _showTimer = Timer(HsMotion.pillStopDelay, () {
            if (mounted) _setHidden(hidden: false);
          });
        }
      case PillMode.always:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final setting =
        preview?.floating ??
        ref.watch<bool>(settingsProvider.select((s) => s.floatingHeader));
    _setting = setting;
    final on = !widget.scrollAway && setting;
    final mode =
        preview?.pill ??
        ref.watch<PillMode>(settingsProvider.select((s) => s.pillMode));
    final level = HsMotion.levelOf(context);
    final sb = MediaQuery.paddingOf(context).top;
    final restH = widget.header.restHeight(context);
    final first = _headerExtent == 0;
    _headerExtent = sb + restH;
    if (first || on != _on || mode != _mode || level != _level) {
      _on = on;
      _mode = mode;
      _level = level;
      _snap();
    }
    final scrollsAway = !on && widget.floating;

    final scrim = Positioned(
      key: const ValueKey<String>('header-scrim'),
      top: 0,
      left: 0,
      right: 0,
      height: sb + 16,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: on && level == MotionLevel.expressive
              ? _ClampedAnimation(_p)
              : _scrim,
          child: HeaderScrim(statusBar: sb),
        ),
      ),
    );

    Widget header = SizedBox(height: sb + restH, child: widget.header);
    header = ValueListenableBuilder<bool>(
      valueListenable: _hiddenN,
      child: header,
      // A hidden pill is not focusable and takes no taps.
      builder: (_, hidden, child) => IgnorePointer(
        ignoring: hidden,
        child: ExcludeSemantics(excluding: hidden, child: child),
      ),
    );
    header = _HideTransform(
      hide: _h,
      shift: _shift,
      away: scrollsAway ? _away : null,
      awayMax: sb + restH,
      level: level,
      child: header,
    );

    return _HeaderScope(
      hide: _h,
      hidden: _hiddenN,
      pins: setting,
      progress: _p,
      restAlpha: _a0,
      pillAlpha: _a1,
      contentAlpha: _contentAlpha,
      pilled: _pillN,
      level: level,
      floating: _floats,
      statusBar: sb,
      restHeight: restH,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            key: const ValueKey<String>('header-body'),
            onNotification: _onScroll,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: widget.body,
            ),
          ),
          if (_floats) scrim,
          Positioned(
            key: const ValueKey<String>('header-top'),
            top: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: header,
              ),
            ),
          ),
          if (!_floats && scrollsAway) scrim,
        ],
      ),
    );
  }
}

/// The pill leaving (up and fading) and the header being carried off by the
/// content (Floating header off).
class _HideTransform extends StatelessWidget {
  const new({
    required this.hide,
    required this.shift,
    required this.away,
    required this.awayMax,
    required this.level,
    required this.child,
  });

  final Animation<double> hide;
  final Animation<double> shift;
  final ValueListenable<double>? away;
  final double awayMax;
  final MotionLevel level;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final a = away;
    if (a != null) {
      return ValueListenableBuilder<double>(
        valueListenable: a,
        child: child,
        builder: (_, v, c) => Transform.translate(
          offset: Offset(0, -math.min(v, awayMax)),
          child: c,
        ),
      );
    }
    final dist = switch (level) {
      MotionLevel.expressive => HeaderSpec.hideDistance,
      MotionLevel.subtle => 4.0,
      MotionLevel.off => 0.0,
    };
    final fade = level == MotionLevel.expressive ? 1.25 : 1.0;
    return AnimatedBuilder(
      animation: Listenable.merge([hide, shift]),
      child: child,
      builder: (_, c) {
        final h = hide.value;
        final o = (1 - h * fade).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, shift.value - h * dist),
          // Hidden is excluded above; this keeps the node while it fades.
          child: Opacity(opacity: o, alwaysIncludeSemantics: true, child: c),
        );
      },
    );
  }
}

/// Fill and hairline of the header: the full-width rest surface and the pill
/// are one rounded rect morphing between two sets of bounds. Repaints from
/// the animations only.
class _SurfacePainter extends CustomPainter {
  new({
    required this.progress,
    required this.restAlpha,
    required this.pillAlpha,
    required this.subtle,
    required this.restBottom,
    required this.pillTop,
    required this.pillBottom,
    required this.rest,
    required this.pill,
    required this.border,
  }) : super(repaint: Listenable.merge([progress, restAlpha, pillAlpha]));

  final Animation<double> progress;
  final Animation<double> restAlpha;
  final Animation<double> pillAlpha;
  final bool subtle;
  final double restBottom;
  final double pillTop;
  final double pillBottom;
  final Color rest;
  final Color pill;
  final Color border;

  RRect rrectAt(Size size, double p) {
    final pp = math.max(0, p);
    final cq = p.clamp(0.0, 1.0);
    final m = HeaderSpec.margin * pp;
    final top = pillTop * pp;
    final bottom = restBottom + (pillBottom - restBottom) * p;
    return RRect.fromLTRBR(
      m,
      top,
      size.width - m,
      math.max(top, bottom),
      Radius.circular(HeaderSpec.radius * cq),
    );
  }

  void _paintAt(Canvas canvas, Size size, double p, double alpha) {
    if (alpha <= 0) return;
    final cq = p.clamp(0.0, 1.0);
    final r = rrectAt(size, p);
    final a = cq * alpha;
    final fill = Color.lerp(rest, pill, cq)!;
    canvas.drawRRect(
      r,
      Paint()..color = fill.withValues(alpha: fill.a * alpha),
    );
    if (a > 0) {
      canvas.drawRRect(
        r.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = border.withValues(alpha: border.a * a),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _lastSize = size;
    if (subtle) {
      _paintAt(canvas, size, 0, restAlpha.value);
      _paintAt(canvas, size, 1, pillAlpha.value);
    } else {
      _paintAt(canvas, size, progress.value, 1);
    }
  }

  Size _lastSize = Size.zero;

  /// Only the drawn shape takes touches: beside the pill the body is reached.
  @override
  bool? hitTest(Offset position) =>
      rrectAt(_lastSize, subtle ? 0 : progress.value).contains(position);

  @override
  bool shouldRepaint(_SurfacePainter old) =>
      old.rest != rest ||
      old.pill != pill ||
      old.border != border ||
      old.subtle != subtle ||
      old.restBottom != restBottom ||
      old.pillTop != pillTop ||
      old.pillBottom != pillBottom ||
      old.progress != progress;
}

class _FloatingSurface extends StatelessWidget {
  const new({required this.scope, required this.child});

  final _HeaderScope scope;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final sb = scope.statusBar;
    return CustomPaint(
      painter: _SurfacePainter(
        progress: scope.progress,
        restAlpha: scope.restAlpha,
        pillAlpha: scope.pillAlpha,
        subtle: scope.level == MotionLevel.subtle,
        restBottom: sb + scope.restHeight,
        pillTop: sb + HeaderSpec.top,
        pillBottom: sb + HeaderSpec.top + HeaderSpec.pillHeight,
        rest: palette.background,
        pill: palette.nav,
        border: palette.stroke,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: sb),
        child: FadeTransition(
          opacity: scope.contentAlpha,
          child: AnimatedBuilder(
            animation: scope.progress,
            child: child,
            // Buttons keep x; they move 2 dp up (y 14 to 12) into the pill.
            builder: (_, ch) => Transform.translate(
              offset: Offset(0, -2 * scope.progress.value.clamp(0.0, 1.0)),
              child: ch,
            ),
          ),
        ),
      ),
    );
  }
}

/// The title: its rest size, scaled to the pill's size as it morphs.
class _TitleSlot extends StatelessWidget {
  const new({
    required this.title,
    required this.style,
    required this.lineHeight,
    required this.pillScale,
    required this.progress,
    required this.leadShift,
    required this.trailShift,
    required this.dropBelow,
  });

  final String title;
  final TextStyle style;
  final double lineHeight;
  final double pillScale;
  final Animation<double> progress;
  final double leadShift;
  final double trailShift;
  final double dropBelow;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) => AnimatedBuilder(
      animation: progress,
      builder: (_, _) {
        final cq = progress.value.clamp(0.0, 1.0);
        final s = 1 - (1 - pillScale) * cq;
        final lead = leadShift * cq;
        final visual = math.max(0, box.maxWidth - lead - trailShift * cq);
        final drop = visual < dropBelow;

        // Laid out wider by 1/s, then scaled down to fit [visual].
        Widget layer = SizedBox(
          height: lineHeight,
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            minWidth: 0,
            maxWidth: visual / s,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        );
        layer = Transform(
          alignment: AlignmentDirectional.centerStart,
          transform: Matrix4.translationValues(lead, 0, 0)
            ..scaleByDouble(s, s, 1, 1),
          child: layer,
        );
        // Always present (opacity 1 costs nothing) so the element never
        // remounts mid-morph.
        layer = Opacity(
          opacity: drop
              ? (1 - cq / HeaderSpec.titleDropEnd).clamp(0.0, 1.0)
              : 1,
          alwaysIncludeSemantics: true,
          child: layer,
        );
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(header: true, child: layer),
        );
      },
    ),
  );
}

/// A search field that is a screen's sticky header (the Search tab): a bar
/// under the title at rest, and the same floating pill as every other header
/// once it reaches the top (margins, height, radius, fill, hairline, scrim and
/// "Show the pill" included). Floating header off: it scrolls away.
///
/// A sliver, inside a [HeaderPage] with `scrollAway: true`. [child] is the
/// bare field; it keeps its element (and focus) through the morph, and fills
/// the pill so all of it takes the tap.
class HeaderSearchBar extends StatelessWidget {
  const new({required this.child, this.focusNode, super.key});

  final Widget child;

  /// Lets the hairline mark focus, as the field's own ring used to.
  final FocusNode? focusNode;

  /// The field's height at rest.
  static const double restHeight = HsSize.tapTarget;

  /// The gap the page leaves above this sliver so the field rests exactly
  /// where the title header ends.
  static Widget sliverGap() => Builder(
    builder: (c) {
      final s = c.getInheritedWidgetOfExactType<_HeaderScope>();
      final inset = s == null ? 0.0 : s.statusBar + s.restHeight;
      final sb = s?.statusBar ?? 0;
      return SliverToBoxAdapter(
        child: SizedBox(height: math.max(0, inset - sb - HsSpace.x2)),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final scope = _HeaderScope.maybeOf(context)!;
    return SliverPersistentHeader(
      pinned: scope.pins,
      delegate: _SearchBarDelegate(
        extent: scope.statusBar + HeaderSpec.top + restHeight + HsSpace.x3,
        pins: scope.pins,
        focusNode: focusNode,
        child: child,
      ),
    );
  }
}

class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  const new({
    required this.extent,
    required this.pins,
    required this.focusNode,
    required this.child,
  });

  final double extent;
  final bool pins;
  final FocusNode? focusNode;
  final Widget child;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => _SearchPill(
    under: pins ? shrinkOffset : 0,
    focusNode: focusNode,
    child: child,
  );
  @override
  bool shouldRebuild(_SearchBarDelegate old) =>
      extent != old.extent ||
      pins != old.pins ||
      child != old.child ||
      focusNode != old.focusNode;
}

class _SearchPill extends StatefulWidget {
  const new({
    required this.under,
    required this.focusNode,
    required this.child,
  });

  /// How far the content has gone under the bar.
  final double under;
  final FocusNode? focusNode;
  final Widget child;

  @override
  State<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<_SearchPill>
    with SingleTickerProviderStateMixin {
  late bool _pill = widget.under >= HsMotion.headerAt;
  late final AnimationController _p = AnimationController.unbounded(
    vsync: this,
    value: _pill ? 1 : 0,
  );

  @override
  void didUpdateWidget(_SearchPill old) {
    super.didUpdateWidget(old);
    // A gap between on and off, so it never flickers.
    final pill = _pill ? widget.under > 1 : widget.under >= HsMotion.headerAt;
    if (pill == _pill) return;
    _pill = pill;
    final to = pill ? 1.0 : 0.0;
    switch (HsMotion.levelOf(context)) {
      case MotionLevel.expressive:
        unawaited(
          _p.springTo(
            to,
            pill ? HsMotion.springDefault : HsMotion.springStandard,
          ),
        );
      case MotionLevel.subtle:
        _p.animateTo(
          to,
          duration: HsMotion.fxFast,
          curve: HsMotion.curveEffects,
        );
      case MotionLevel.off:
        _p.value = to;
    }
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final scope = _HeaderScope.maybeOf(context)!;
    final sb = scope.statusBar;
    final focus = widget.focusNode;
    final bar = AnimatedBuilder(
      animation: Listenable.merge([_p, ?focus]),
      child: widget.child,
      builder: (_, child) {
        final p = _p.value;
        final q = p.clamp(0.0, 1.0);
        final side = HsSpace.x5 + (HeaderSpec.margin - HsSpace.x5) * p;
        final height =
            HeaderSearchBar.restHeight +
            (HeaderSpec.pillHeight - HeaderSearchBar.restHeight) * q;
        final focused = focus?.hasFocus ?? false;
        return Padding(
          padding: EdgeInsets.fromLTRB(side, sb + HeaderSpec.top, side, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.lerp(palette.background, palette.nav, q),
                borderRadius: BorderRadius.circular(height / 2),
              ),
              // In front, so the hairline takes no room from the field.
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(
                  color: focused ? palette.textPrimary : palette.stroke,
                  width: focused ? 1.5 : 1,
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: sb + 16,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _ClampedAnimation(_p),
              child: HeaderScrim(statusBar: sb),
            ),
          ),
        ),
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: scope.hidden,
            builder: (_, hidden, child) => IgnorePointer(
              ignoring: hidden,
              child: ExcludeSemantics(excluding: hidden, child: child),
            ),
            child: _HideTransform(
              hide: scope.hide,
              shift: kAlwaysDismissedAnimation,
              away: null,
              awayMax: 0,
              level: scope.level,
              child: bar,
            ),
          ),
        ),
      ],
    );
  }
}

/// The status bar's fade, behind a pill.
class HeaderScrim extends StatelessWidget {
  const new({required this.statusBar, super.key});

  final double statusBar;

  @override
  Widget build(BuildContext context) {
    final ground = context.hs.background;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, statusBar * 0.5 / (statusBar + 16), 1],
          colors: [
            ground.withValues(alpha: 0.94),
            ground.withValues(alpha: 0.94),
            ground.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _ClampedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  new(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);
}
