import 'package:flutter/widgets.dart';
import 'package:headshorts/core/tokens/dimensions.dart';

/// The icon set is drawn, not imported.
///
/// Every glyph in the design board is built from rules, arcs and dots at
/// specific sizes; reproducing them as primitives keeps them exactly on-spec
/// and costs nothing at runtime.
abstract final class HsGlyph {
  static const double _stroke = HsSize.glyphStroke;

  /// Today — three rules, the middle one short.
  static Widget today(Color color) => SizedBox(
    width: 16,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rule(color, 16),
        const SizedBox(height: 3),
        _rule(color, 16 * 0.68),
        const SizedBox(height: 3),
        _rule(color, 16),
      ],
    ),
  );

  /// Search — a 12dp ring with a 6dp handle off its lower right, drawn in a
  /// 16 square so it sits on the same baseline as the other four.
  static Widget search(Color color) => SizedBox(
    width: 16,
    height: 16,
    child: Stack(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: _stroke),
          ),
        ),
        Positioned(
          left: 10,
          top: 11,
          child: Transform.rotate(
            angle: 0.7853981633974483,
            alignment: Alignment.centerLeft,
            child: Container(
              width: 6,
              height: _stroke,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// A filled or outlined bookmark — the save-for-later toggle's two states.
  static Widget bookmark(Color color, {bool filled = false, Key? key}) =>
      CustomPaint(
        key: key,
        size: const Size(19, 19),
        painter: _BookmarkPainter(color: color, filled: filled),
      );

  /// Linger — a single card, upright.
  static Widget linger(Color color) => Container(
    width: 13,
    height: 17,
    decoration: BoxDecoration(
      border: Border.all(color: color, width: _stroke),
      borderRadius: BorderRadius.circular(4),
    ),
  );

  /// Sources — the broadcast mark: a dot and two arcs.
  static Widget sources(Color color) => SizedBox(
    width: 16,
    height: 16,
    child: CustomPaint(painter: _SourcesPainter(color)),
  );

  /// More — two tuner sliders, so it reads as a place with settings in it
  /// rather than an overflow menu.
  static Widget more(Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _tunerRow(color, 3, 7),
      const SizedBox(height: 5),
      _tunerRow(color, 9, 1),
    ],
  );

  static Widget _tunerRow(Color color, double lead, double tail) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _rule(color, lead, height: _stroke),
      const SizedBox(width: 2),
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: _stroke),
        ),
      ),
      const SizedBox(width: 2),
      _rule(color, tail, height: _stroke),
    ],
  );

  static Widget _rule(Color color, double width, {double height = 2}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );

  /// A chevron, drawn the way the design board draws it: a square with two
  /// adjacent borders, turned 45°. Which two borders decides which way the
  /// corner — and so the caret — points.
  static Widget chevron(
    Color color, {
    required AxisDirection direction,
    double size = 8,
  }) {
    final side = BorderSide(color: color, width: _stroke);
    final border = switch (direction) {
      AxisDirection.right => Border(right: side, top: side),
      AxisDirection.down => Border(right: side, bottom: side),
      AxisDirection.left => Border(left: side, bottom: side),
      AxisDirection.up => Border(left: side, top: side),
    };

    return Transform.rotate(
      angle: 0.7853981633974483,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(border: border),
      ),
    );
  }

  /// The back arrow in a pushed screen's bar.
  static Widget back(Color color) => Transform.rotate(
    angle: 0.7853981633974483,
    child: Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: _stroke),
          bottom: BorderSide(color: color, width: _stroke),
        ),
      ),
    ),
  );

  /// The refresh mark in Today's header — an open ring with a return tick.
  static Widget refresh(Color color) => SizedBox(
    width: 17,
    height: 17,
    child: CustomPaint(painter: _RefreshPainter(color)),
  );

  /// The tick inside a filled checkbox or a chosen feed.
  static Widget tick(Color color) => Transform.rotate(
    angle: -0.7853981633974483,
    child: Container(
      width: 8,
      height: 4,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color, width: _stroke),
          bottom: BorderSide(color: color, width: _stroke),
        ),
      ),
    ),
  );

  /// The share mark: an open tray with an arrow pointing up.
  static Widget share(Color color) => SizedBox(
    width: 14,
    height: 14,
    child: CustomPaint(painter: _SharePainter(color)),
  );

  /// The more options mark: three horizontal dots.
  static Widget moreOptions(Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 3.5,
        height: 3.5,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 3),
      Container(
        width: 3.5,
        height: 3.5,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 3),
      Container(
        width: 3.5,
        height: 3.5,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ],
  );

  /// The two-rule mark above "Swipe up for the next".
  static Widget swipeUp(Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _rule(color, 9, height: 1),
      const SizedBox(height: 2),
      _rule(color, 5, height: 1),
    ],
  );
}

class _SourcesPainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(2, size.height - 2);
    canvas.drawCircle(Offset(2, size.height - 2), 2, Paint()..color = color);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = HsSize.glyphStroke
      ..strokeCap = StrokeCap.round;
    for (final radius in const [7.0, 12.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        -1.5707963267948966,
        1.5707963267948966,
        false,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_SourcesPainter old) => old.color != color;
}

class _RefreshPainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = HsSize.glyphStroke;
    final rect = Rect.fromLTWH(
      HsSize.glyphStroke / 2,
      HsSize.glyphStroke / 2,
      size.width - HsSize.glyphStroke,
      size.height - HsSize.glyphStroke,
    );
    // Open at the top — the gap is where the return tick sits.
    canvas.drawArc(rect, -1.0471975511965976, 5.235987755982989, false, stroke);
    final tip = Offset(size.width - 1, 1);
    canvas
      ..drawLine(tip, tip.translate(-4.5, 0.5), stroke)
      ..drawLine(tip, tip.translate(-0.5, 4.5), stroke);
  }

  @override
  bool shouldRepaint(_RefreshPainter old) => old.color != color;
}

class _SharePainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = HsSize.glyphStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(2, 6)
      ..lineTo(2, size.height - 1)
      ..lineTo(size.width - 2, size.height - 1)
      ..lineTo(size.width - 2, 6);
    canvas.drawPath(path, stroke);

    final midX = size.width / 2;
    canvas
      ..drawLine(Offset(midX, size.height - 5), Offset(midX, 1), stroke)
      ..drawLine(Offset(midX - 3.5, 4.5), Offset(midX, 1), stroke)
      ..drawLine(Offset(midX + 3.5, 4.5), Offset(midX, 1), stroke);
  }

  @override
  bool shouldRepaint(_SharePainter old) => old.color != color;
}

/// The bookmark pennant: `M6.5 3.8h11v16.4L12 16.3l-5.5 3.9z` from the board,
/// scaled from its 24 viewBox to whatever size it is drawn at.
class _BookmarkPainter extends CustomPainter {
  const new({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final path = Path()
      ..moveTo(6.5 * k, 3.8 * k)
      ..lineTo(17.5 * k, 3.8 * k)
      ..lineTo(17.5 * k, 20.2 * k)
      ..lineTo(12 * k, 16.3 * k)
      ..lineTo(6.5 * k, 20.2 * k)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.8 * k
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BookmarkPainter old) =>
      old.color != color || old.filled != filled;
}
