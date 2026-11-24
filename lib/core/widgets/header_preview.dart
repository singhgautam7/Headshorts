import 'package:flutter/material.dart' show Icons, Material;
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/widgets/app_header.dart';
import 'package:headshorts/core/widgets/app_icon_button.dart';
import 'package:headshorts/data/prefs/settings.dart';

/// Kuber's 5550 ms script: wait, scroll down to 300, hold, up to 220, hold,
/// back to 0. `(end ms, offset)`.
const _scriptMs = 5550;
const _script = <(int, double)>[
  (500, 0),
  (1600, 300),
  (2500, 300),
  (2950, 220),
  (3850, 220),
  (4850, 0),
  (5550, 0),
];

double _scriptOffset(double t) {
  final ms = t * _scriptMs;
  var t0 = 0;
  var y0 = 0.0;
  for (final (t1, y1) in _script) {
    if (ms <= t1) {
      if (y1 == y0) return y0;
      return y0 +
          (y1 - y0) * Curves.easeInOutCubic.transform((ms - t0) / (t1 - t0));
    }
    t0 = t1;
    y0 = y1;
  }
  return 0;
}

/// A live mini page of the floating header: a real [HeaderPage] on a phone
/// sized canvas, scaled down, whose list is scrolled by a script — down, hold,
/// a little up, hold, back to the top — so a "Show the pill" choice can be
/// judged by what it does.
///
/// Not interactive and not in the semantics tree. It follows the Motion level
/// (the header inside it does), holds still under the phone's Remove
/// animations, and its ticker is muted by `TickerMode` whenever the page is
/// covered, so nothing runs while it is not visible.
class HeaderPreview extends StatefulWidget {
  const new({required this.floating, required this.pill, super.key});

  final bool floating;
  final PillMode pill;

  @override
  State<HeaderPreview> createState() => _HeaderPreviewState();
}

class _HeaderPreviewState extends State<HeaderPreview>
    with SingleTickerProviderStateMixin {
  static const _canvas = Size(360, 553);
  static const _shown = Size(300, 72);

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _scriptMs),
  )..addListener(_tick);
  final _scroll = ScrollController();
  var _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still =
        MediaQuery.disableAnimationsOf(context) ||
        HsMotion.levelOf(context) == MotionLevel.off;
    if (_still) {
      _loop.stop();
      // The state the first scroll down ends in.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _still && _scroll.hasClients) _scroll.jumpTo(300);
      });
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  void _tick() {
    if (!_still && _scroll.hasClients) {
      _scroll.jumpTo(_scriptOffset(_loop.value));
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    const top = EdgeInsets.only(top: HsSpace.x4);
    final mq = MediaQuery.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Container(
            width: _shown.width,
            height: _shown.height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: HsRadius.buttonBorder,
              border: Border.all(color: palette.stroke),
            ),
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: _canvas.width,
              maxWidth: _canvas.width,
              minHeight: _canvas.height,
              maxHeight: _canvas.height,
              child: Transform.scale(
                scale: _shown.width / _canvas.width,
                alignment: Alignment.topLeft,
                child: MediaQuery(
                  data: mq.copyWith(
                    size: _canvas,
                    padding: top,
                    viewPadding: top,
                    viewInsets: EdgeInsets.zero,
                    textScaler: TextScaler.noScaling,
                  ),
                  child: Material(
                    color: palette.background,
                    child: HeaderPage(
                      preview: HeaderPreviewSpec(
                        floating: widget.floating,
                        pill: widget.pill,
                      ),
                      header: AppHeader(
                        title: 'Headlines',
                        root: true,
                        actions: [
                          HsIconButton(
                            icon: Icons.search_rounded,
                            semanticLabel: '',
                            onPressed: () {},
                          ),
                          HsIconButton(
                            icon: Icons.more_vert_rounded,
                            semanticLabel: '',
                            onPressed: () {},
                          ),
                        ],
                      ),
                      body: ListView(
                        controller: _scroll,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: HsSpace.x5,
                        ),
                        children: [
                          HeaderPage.gap(),
                          for (var i = 0; i < 12; i++) _row(palette, i),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _row(HsPalette palette, int i) => Container(
    height: 64,
    margin: const EdgeInsets.only(bottom: HsSpace.x2),
    padding: const EdgeInsets.symmetric(horizontal: HsSpace.x4),
    decoration: BoxDecoration(
      color: palette.surface,
      borderRadius: HsRadius.cardBorder,
      border: Border.all(color: palette.stroke),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: palette.primaryContainer,
            borderRadius: HsRadius.buttonBorder,
          ),
        ),
        const SizedBox(width: HsSpace.x4),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: (60 + (i * 37) % 40) / 100,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette.textPrimary.withValues(alpha: 0.7),
                    borderRadius: HsRadius.pillBorder,
                  ),
                ),
              ),
              const SizedBox(height: HsSpace.x2),
              FractionallySizedBox(
                widthFactor: 0.4,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: palette.textMuted.withValues(alpha: 0.5),
                    borderRadius: HsRadius.pillBorder,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
