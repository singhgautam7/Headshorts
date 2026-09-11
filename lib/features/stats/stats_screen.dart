import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/stats_repository.dart';
import 'package:intl/intl.dart';

final statsProvider = FutureProvider<StatsSummary>(
  (ref) => ref.watch(statsRepositoryProvider).summarise(),
);

/// Stats — a mirror, not a scoreboard.
///
/// There is no streak, no goal, no trophy and no comparison. Gaps are shown
/// without comment. The only accent on this screen sits on the per-source
/// bars, where it identifies a source rather than rewarding the reader.
class StatsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final stats = ref.watch(statsProvider).value ?? StatsSummary.empty;

    return PushedScreen(
      title: 'Stats',
      divider: false,
      onBack: () => context.pop(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          HsSpace.x5,
          HsSpace.x3,
          HsSpace.x5,
          HsSpace.x6,
        ),
        children: [
          Text(
            stats.arrived == 0
                ? 'Nothing has come in yet. This screen fills as you read.'
                : 'Over the last ${stats.windowDays} days you opened '
                      '${stats.readInFull} of the ${stats.arrived} headlines '
                      'that came in.',
            style: HsType.statLabel.copyWith(
              height: 1.5,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _SplitBar(stats: stats),
          const SizedBox(height: HsSpace.x4),
          _Legend(
            colour: palette.textPrimary,
            label: 'Read in full',
            value: stats.readInFull,
          ),
          _Legend(
            colour: palette.textSecondary,
            label: 'Seen in Linger, not opened',
            value: stats.seenInLinger,
          ),
          _Legend(
            colour: palette.surfaceVariant,
            label: 'Passed over',
            value: stats.passedOver,
          ),
          const SizedBox(height: 30),
          const HsDivider(),
          const SizedBox(height: 30),
          _ReadThrough(stats: stats),
          const SizedBox(height: 30),
          const HsDivider(),
          const SizedBox(height: 30),
          _ReadingTime(stats: stats),
          const SizedBox(height: 30),
          const HsDivider(),
          const SizedBox(height: 30),
          _CaughtUpHistory(stats: stats),
        ],
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const new({required this.stats});

  final StatsSummary stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final total = stats.arrived == 0 ? 1 : stats.arrived;

    Widget segment(int count, Color colour) => Expanded(
      flex: count == 0 ? 1 : count * 100 ~/ total + 1,
      child: ColoredBox(color: colour),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            segment(stats.readInFull, palette.textPrimary),
            const SizedBox(width: 2),
            segment(stats.seenInLinger, palette.textSecondary),
            const SizedBox(width: 2),
            segment(stats.passedOver, palette.surfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const new({required this.colour, required this.label, required this.value});

  final Color colour;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Padding(
      padding: const EdgeInsets.only(bottom: HsSpace.x4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: HsType.statLabel.copyWith(color: palette.textSecondary),
            ),
          ),
          Text(
            '$value',
            style: HsType.statValue.copyWith(color: palette.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _ReadThrough extends ConsumerWidget {
  const new({required this.stats});

  final StatsSummary stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final unopened = stats.neverOpened;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Read-through by source',
          style: HsType.statTitle.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: HsSpace.x1),
        Text(
          unopened.isEmpty
              ? 'Useful for pruning.'
              : 'Useful for pruning. '
                    '${unopened.length} of these you never open.',
          style: HsType.note.copyWith(color: palette.textMuted),
        ),
        const SizedBox(height: HsSpace.x4),
        for (final entry in stats.perSource)
          AccentScope(
            accent: entry.source.accent,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      entry.source.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HsType.timestamp.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: HsSpace.x3),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 6,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(color: palette.surfaceVariant),
                            ),
                            FractionallySizedBox(
                              widthFactor: entry.fraction.clamp(0.0, 1.0),
                              child: ColoredBox(
                                color: entry.source.accent.resolve(
                                  isDark: palette.isDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: HsSpace.x3),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${(entry.fraction * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: HsType.timestamp.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (unopened.isNotEmpty) ...[
          const SizedBox(height: HsSpace.x3),
          HsButton(
            unopened.length == 1
                ? 'Review the one you never open'
                : 'Review the ${unopened.length} you never open',
            onPressed: () => context.push('/sources'),
            kind: HsButtonKind.secondary,
            height: HsSize.buttonCompact,
          ),
        ],
      ],
    );
  }
}

class _ReadingTime extends StatelessWidget {
  const new({required this.stats});

  static const _chartHeight = 96.0;

  final StatsSummary stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final days = stats.minutesByDay;
    final peak = days.isEmpty
        ? 1.0
        : days
              .map((d) => d.minutes)
              .reduce((a, b) => a > b ? a : b)
              .clamp(1.0, double.maxFinite);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reading time',
          style: HsType.statTitle.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: HsSpace.x1),
        Text(
          '${stats.averageMinutesPerDay.round()} minutes a day on average, '
          'last two weeks',
          style: HsType.note.copyWith(color: palette.textMuted),
        ),
        const SizedBox(height: HsSpace.x4),
        SizedBox(
          height: _chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: Container(
                    // A day with no reading is a flat mark on the baseline,
                    // not a gap — the gaps are the point of this chart.
                    height: (days[i].minutes / peak * _chartHeight).clamp(
                      2.0,
                      _chartHeight,
                    ),
                    decoration: BoxDecoration(
                      color: i == days.length - 1
                          ? palette.textPrimary
                          : palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: HsSpace.x3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              days.isEmpty ? '' : DateFormat('d MMM').format(days.first.day),
              style: HsType.rowSub.copyWith(color: palette.textMuted),
            ),
            Text(
              'Today',
              style: HsType.rowSub.copyWith(color: palette.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _CaughtUpHistory extends StatelessWidget {
  const new({required this.stats});

  final StatsSummary stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final today = DateTime.now();
    final days = [
      for (var i = stats.windowDays - 1; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    final hit = days.where(stats.caughtUpDays.contains).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Caught up on',
          style: HsType.statTitle.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: HsSpace.x1),
        Text(
          '$hit of the last ${stats.windowDays} days you reached the end of '
          'Today',
          style: HsType.note.copyWith(color: palette.textMuted),
        ),
        const SizedBox(height: HsSpace.x4),
        GridView.count(
          crossAxisCount: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: HsSpace.x2,
          crossAxisSpacing: HsSpace.x2,
          children: [
            for (final day in days)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: stats.caughtUpDays.contains(day)
                      ? palette.textPrimary
                      : palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
        const SizedBox(height: HsSpace.x4),
        Text(
          'No streak count, no "keep it going". The gaps are not failures — '
          'they are days you had other things on.',
          style: HsType.noteTight.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}
