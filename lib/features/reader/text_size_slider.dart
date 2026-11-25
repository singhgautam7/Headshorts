import 'package:flutter/widgets.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/data/prefs/settings.dart';

/// The A to A slider. It offsets the system size rather than overriding it.
///
/// Five steps and nothing between them: a tick marks each, the knob only
/// ever rests on one, and a drag snaps to the nearest. The geometry is the
/// board's — a 2px track, a 20px knob, the two A's — with the ticks added so
/// the control reads as the stepped thing it is.
class TextSizeSlider extends StatelessWidget {
  const new({required this.step, required this.onChanged, super.key});

  final TextSizeStep step;
  final ValueChanged<TextSizeStep> onChanged;

  static const _knob = 20.0;
  static const _tick = 6.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    const steps = TextSizeStep.values;
    final last = steps.length - 1;
    final fraction = step.index / last;

    // One tick per step crossed, and nothing when the knob has not moved.
    void change(TextSizeStep next) {
      if (next == step) return;
      HsHaptics.tick();
      onChanged(next);
    }

    void step_(int by) => change(steps[(step.index + by).clamp(0, last)]);
    final slide = HsMotion.levelOf(context) == MotionLevel.off
        ? Duration.zero
        : HsMotion.micro;

    return Semantics(
      slider: true,
      label: 'Text size',
      value: step.label,
      increasedValue: steps[(step.index + 1).clamp(0, last)].label,
      decreasedValue: steps[(step.index - 1).clamp(0, last)].label,
      onIncrease: step.index < last ? () => step_(1) : null,
      onDecrease: step.index > 0 ? () => step_(-1) : null,
      child: Row(
        children: [
          Text(
            'A',
            style: HsType.readerBody(13).copyWith(color: palette.textMuted),
          ),
          const SizedBox(width: HsSpace.x3),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The knob's centre travels from half a knob in to half a
                // knob short of the end, so the ticks sit under it exactly.
                final travel = constraints.maxWidth - _knob;
                int indexAt(double dx) =>
                    ((dx - _knob / 2) / travel * last).round().clamp(0, last);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => change(steps[indexAt(d.localPosition.dx)]),
                  onHorizontalDragUpdate: (d) =>
                      change(steps[indexAt(d.localPosition.dx)]),
                  child: SizedBox(
                    height: 24,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: palette.divider,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        AnimatedFractionallySizedBox(
                          duration: slide,
                          curve: HsMotion.microCurve,
                          widthFactor: fraction,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: palette.textPrimary,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                        for (var i = 0; i <= last; i++)
                          Positioned(
                            left: _knob / 2 + travel * i / last - _tick / 2,
                            child: Container(
                              width: _tick,
                              height: _tick,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i <= step.index
                                    ? palette.textPrimary
                                    : palette.textMuted,
                              ),
                            ),
                          ),
                        AnimatedAlign(
                          duration: slide,
                          curve: HsMotion.microCurve,
                          alignment: Alignment(fraction * 2 - 1, 0),
                          child: Container(
                            width: _knob,
                            height: _knob,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: HsSpace.x3),
          Text(
            'A',
            style: HsType.readerBody(21).copyWith(color: palette.textPrimary),
          ),
        ],
      ),
    );
  }
}
