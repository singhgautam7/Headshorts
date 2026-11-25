import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/core/motion/pressable.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/features/stats/stats_screen.dart';

/// The card that leads More: minutes read this week and seven small bars,
/// in the shape of Unfurl's insights card. Tapping it opens Stats.
///
/// A measure and nothing more. The bars share one fixed ceiling rather than
/// scaling to the week's best day, so no day is ever "the best" and none
/// reads as behind. It watches its own provider, so a read event rebuilds
/// this card and nothing around it.
class StatsCard extends ConsumerWidget {
  const new({super.key});

  /// A day's bar is full at this many minutes; more is clamped.
  static const ceilingMinutes = 60.0;

  static const _barsHeight = 52.0;
  static const _barWidth = 8.0;
  static const _nbsp = ' ';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final week = ref.watch(weekReadingProvider).value;
    final total = week?.totalMinutes ?? 0;
    final loaded = week != null;
    final empty = loaded && total == 0;

    // Stable height while loading: the same two lines, holding a blank.
    final value = !loaded
        ? _nbsp
        : (empty ? 'Nothing read yet' : _format(total));
    final sub = !loaded
        ? _nbsp
        : (empty ? 'Fills as you read' : 'Read this week');
    final onCard = palette.onPrimaryContainer;
    final today = DateTime.now().weekday - 1;
    final showBars = MediaQuery.textScalerOf(context).scale(1) < 1.5;

    return Pressable(
      onTap: () => context.push('/stats'),
      semanticLabel: 'Stats. ${value.trim()}. ${sub.trim()}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.primaryContainer,
            borderRadius: HsRadius.menuBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.insights_rounded, size: 18, color: onCard),
                          const SizedBox(width: 6),
                          Text(
                            'Stats',
                            style: HsType.label.copyWith(
                              fontSize: 13,
                              letterSpacing: 0,
                              color: onCard,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value,
                        style: HsType.title.copyWith(
                          fontSize: 26,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          color: onCard,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sub,
                        style: HsType.rowValue.copyWith(
                          height: 1.35,
                          color: onCard,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                if (showBars)
                  SizedBox(
                    height: _barsHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < 7; i++) ...[
                          if (i > 0) const SizedBox(width: HsSpace.x1),
                          _Bar(
                            minutes: week?.minutes[i] ?? 0,
                            color: (week?.minutes[i] ?? 0) == 0
                                ? onCard.withValues(alpha: 0.25)
                                : i == today
                                ? onCard
                                : palette.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                Icon(Icons.chevron_right_rounded, size: 24, color: onCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _format(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }
}

class _Bar extends StatelessWidget {
  const new({required this.minutes, required this.color});

  final double minutes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = (minutes / StatsCard.ceilingMinutes).clamp(0.0, 1.0);
    final h = minutes <= 0
        ? 3.0
        : (fraction * StatsCard._barsHeight).clamp(4.0, StatsCard._barsHeight);
    return Container(
      width: StatsCard._barWidth,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
