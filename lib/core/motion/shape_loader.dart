import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/motion.dart';

/// The loading indicator (Kuber's shape loader): seven shapes, one morph
/// every 650 ms on springDefault, turning once per 1.6 s.
///
/// **It draws nothing for the first [delay].** A wait shorter than that is not
/// a wait, and a loader that flashes for a frame reads as a glitch. The delay
/// is the head of the one ticker's timeline rather than a Timer, so nothing
/// is left pending when the widget goes away.
///
/// Expressive: morph and turn. Subtle: one still shape that fades in and out,
/// nothing turns. Off: a still shape. The ticker belongs to the widget's
/// `TickerMode`, so it is muted off-stage, and at Off it stops once the shape
/// has appeared.
///
/// [contained]: the shape (30/48 of [size]) in `primaryContainer` ink on a
/// `primaryContainer` circle. Otherwise [color] (default `primary`), 38/48.
class ShapeLoader extends StatefulWidget {
  const new({super.key, this.size = 48, this.contained = false, this.color});

  final double size;
  final bool contained;
  final Color? color;

  /// Nothing is drawn before this, and the shape fades in over [fadeIn].
  static const delay = Duration(milliseconds: 250);
  static const fadeIn = Duration(milliseconds: 150);

  @override
  State<ShapeLoader> createState() => _ShapeLoaderState();
}

const _n = 72;
const _morphMs = 650;
const _turnMs = 1600;
const _pulseMs = 1200;
const _staticShape = 1; // Cookie 9

final List<Float32List> _radii = () {
  double pent(double th) {
    const s = 2 * math.pi / 5;
    final m = ((th + math.pi / 2) % s + s) % s - s / 2;
    return .72 * math.cos(math.pi / 5) / math.cos(m) + .28;
  }

  double ell(double th, double a, double b, double rot) {
    final q = th + rot;
    return 1 /
        math.sqrt(math.pow(math.cos(q), 2) + math.pow(math.sin(q) / b, 2));
  }

  final fs = <double Function(double)>[
    (th) => 1 + .07 * math.cos(10 * th), // Soft burst
    (th) => 1 + .09 * math.cos(9 * th), // Cookie 9
    pent, // Pentagon
    (th) => ell(th, 1, .6, -math.pi / 4), // Pill
    (th) => 1 + .05 * math.cos(8 * th), // Sunny
    (th) => 1 + .13 * math.cos(4 * th), // Cookie 4
    (th) => ell(th, 1, .78, math.pi / 4), // Oval
  ];
  return [
    for (final f in fs)
      () {
        final r = Float32List(_n);
        var mx = 0.0;
        for (var i = 0; i < _n; i++) {
          r[i] = f(i / _n * 2 * math.pi);
          mx = math.max(mx, r[i]);
        }
        for (var i = 0; i < _n; i++) {
          r[i] /= mx;
        }
        return r;
      }(),
  ];
}();

final Float32List _cos = Float32List.fromList([
  for (var i = 0; i < _n; i++) math.cos(i / _n * 2 * math.pi),
]);
final Float32List _sin = Float32List.fromList([
  for (var i = 0; i < _n; i++) math.sin(i / _n * 2 * math.pi),
]);

class _ShapeLoaderState extends State<ShapeLoader>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Duration> _t = ValueNotifier(Duration.zero);
  late final Ticker _ticker = createTicker(_tick);
  MotionLevel _level = MotionLevel.off;

  /// Off needs the clock only until the shape has faded in.
  static final _settled = ShapeLoader.delay + ShapeLoader.fadeIn;

  void _tick(Duration d) {
    _t.value = d;
    if (_level == MotionLevel.off && d >= _settled) _ticker.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _level = HsMotion.levelOf(context);
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final contained = widget.contained;
    final s = widget.size;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: s,
        child: CustomPaint(
          painter: _ShapePainter(
            t: _t,
            level: _level,
            color: contained
                ? palette.onPrimaryContainer
                : (widget.color ?? palette.primary),
            circle: contained ? palette.primaryContainer : null,
            shapeSize: s * (contained ? 30 / 48 : 38 / 48),
          ),
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  new({
    required this.t,
    required this.level,
    required this.color,
    required this.circle,
    required this.shapeSize,
  }) : super(repaint: t);

  final ValueNotifier<Duration> t;
  final MotionLevel level;
  final Color color;
  final Color? circle;
  final double shapeSize;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value.inMicroseconds / 1000;
    final appear =
        ((ms - ShapeLoader.delay.inMilliseconds) /
                ShapeLoader.fadeIn.inMilliseconds)
            .clamp(0.0, 1.0);
    if (appear == 0) return;
    // Subtle breathes between half and full; the rest hold full.
    final breath = level == MotionLevel.subtle
        ? 0.75 + 0.25 * math.cos(2 * math.pi * ms / _pulseMs)
        : 1.0;
    final alpha = appear * breath;

    final c = size.center(Offset.zero);
    if (circle != null) {
      canvas.drawCircle(
        c,
        size.width / 2,
        Paint()..color = circle!.withValues(alpha: circle!.a * alpha),
      );
    }
    final Float32List from;
    final Float32List to;
    var p = 0.0;
    var rot = 0.0;
    if (level == MotionLevel.expressive) {
      final k = ms ~/ _morphMs;
      from = _radii[k % 7];
      to = _radii[(k + 1) % 7];
      final local = (ms - k * _morphMs) / 1000;
      final spring = HsMotion.defaultCurve;
      p = spring.transform(
        (local * 1000 / spring.settle.inMilliseconds).clamp(0.0, 1.0),
      );
      rot = 2 * math.pi * (ms % _turnMs) / _turnMs;
    } else {
      from = to = _radii[_staticShape];
    }
    // The design draws the shape in a viewBox of +-1.05.
    final r = shapeSize / 2.1;
    final path = Path();
    final cr = math.cos(rot);
    final sr = math.sin(rot);
    for (var i = 0; i < _n; i++) {
      final rad = (from[i] + (to[i] - from[i]) * p) * r;
      final x = _cos[i] * rad;
      final y = _sin[i] * rad;
      final px = c.dx + x * cr - y * sr;
      final py = c.dy + x * sr + y * cr;
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: color.a * alpha)
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_ShapePainter o) =>
      o.level != level ||
      o.color != color ||
      o.circle != circle ||
      o.shapeSize != shapeSize;
}
