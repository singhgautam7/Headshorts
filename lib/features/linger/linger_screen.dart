import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';

final lingerQueueProvider = StreamProvider<List<Headline>>(
  (ref) => ref.watch(articleRepositoryProvider).watchLinger(),
);

/// Linger — one item per screen, moved by a deliberate vertical swipe.
///
/// Nothing advances on its own. There is no autoplay, no timer and no
/// carousel. The set is finite: past the last card there is a hard stop, and
/// swiping up from there settles back rather than loading more.
class LingerScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LingerScreen> createState() => _LingerScreenState();
}

class _LingerScreenState extends ConsumerState<LingerScreen> {
  late final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _backToToday() => context.go('/today');

  void _onPage(int index, List<Headline> queue) {
    unawaited(HapticFeedback.selectionClick());
    if (index < queue.length) {
      // Seeing a card marks it read in Linger, silently.
      unawaited(
        ref
            .read(articleRepositoryProvider)
            .markRead(queue[index].article.id, mode: ReadMode.linger),
      );
    } else {
      // The one haptic that is not a direct echo of a tap.
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(lingerQueueProvider).value ?? const [];

    return ColoredBox(
      color: context.hs.background,
      child: SafeArea(
        bottom: false,
        child: queue.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(
                  HsSpace.x4,
                  HsSpace.x2,
                  HsSpace.x4,
                  96,
                ),
                child: _HardStop(total: 0, onBackToToday: _backToToday),
              )
            : PageView.builder(
                controller: _controller,
                scrollDirection: Axis.vertical,
                // A deliberate swipe: one card at a time, and it settles.
                physics: const PageScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                itemCount: queue.length + 1,
                onPageChanged: (i) => _onPage(i, queue),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HsSpace.x4,
                    HsSpace.x2,
                    HsSpace.x4,
                    96,
                  ),
                  child: i == queue.length
                      ? _HardStop(
                          total: queue.length,
                          onBackToToday: _backToToday,
                        )
                      : LingerCard(
                          headline: queue[i],
                          position: i,
                          total: queue.length,
                          onReadFull: () =>
                              context.push('/reader/${queue[i].article.id}'),
                        ),
                ),
              ),
      ),
    );
  }
}

/// One Linger card.
///
/// On AMOLED the card takes a ground derived from its source accent — a 15%
/// wash over black, edged with a hairline of the accent at full strength — so
/// each swipe lands on a visibly different quiet hue and the gesture keeps its
/// sense of place. On paper the ground stays neutral and the accent narrows to
/// an edge bar and a label chip.
class LingerCard extends StatelessWidget {
  const new({
    required this.headline,
    required this.position,
    required this.total,
    required this.onReadFull,
    super.key,
  });

  final Headline headline;
  final int position;
  final int total;
  final VoidCallback onReadFull;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final tone = headline.source.accent;
    final accent = tone.resolve(isDark: palette.isDark);
    final dark = palette.isDark;
    final remaining = total - position - 1;

    final extract =
        headline.article.contentSnippet ?? headline.article.summary ?? '';

    return AccentScope(
      accent: tone,
      child: Container(
        decoration: BoxDecoration(
          color: dark ? accentWash(accent, palette) : palette.surface,
          borderRadius: const BorderRadius.all(HsRadius.sheet),
          border: Border.all(
            color: dark ? accent.withValues(alpha: 0.34) : palette.divider,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (!dark)
              Positioned(
                left: 0,
                top: 30,
                bottom: 30,
                child: Container(
                  width: HsSize.accentBar,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(2),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(dark ? 26 : 22, 30, 26, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    source: headline.source.title,
                    accent: accent,
                    dark: dark,
                    when: headline.article.publishedAt,
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headline.article.title,
                            style: HsType.lingerHeadline.copyWith(
                              // On black the headline takes a little of the
                              // accent; on paper it stays near-black.
                              color: dark
                                  ? Color.lerp(palette.textPrimary, accent, 0.4)
                                  : palette.textPrimary,
                            ),
                          ),
                          if (extract.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            Text(
                              extract,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              style: HsType.lingerBody.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  HsButton(
                    'Read full',
                    onPressed: onReadFull,
                    kind: dark ? HsButtonKind.accent : HsButtonKind.primary,
                  ),
                  const SizedBox(height: HsSpace.x4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HsGlyph.swipeUp(palette.textMuted),
                      const SizedBox(width: HsSpace.x2),
                      Flexible(
                        child: Text(
                          remaining == 0
                              ? 'Swipe up for the end of the briefing'
                              : 'Swipe up for the next of $remaining remaining',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HsType.timestamp.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: HsSpace.x3,
              top: 34,
              child: PositionRuler(
                total: total + 1,
                index: position,
                accent: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const new({
    required this.source,
    required this.accent,
    required this.dark,
    required this.when,
  });

  final String source;
  final Color accent;
  final bool dark;
  final DateTime when;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Row(
      children: [
        if (dark) ...[
          Container(
            width: HsSize.accentBar,
            height: 22,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: HsSpace.x3),
          Flexible(
            child: Text(
              source.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HsType.lingerLabel.copyWith(color: accent),
            ),
          ),
        ] else
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentWash(accent, palette),
                borderRadius: HsRadius.chipBorder,
              ),
              child: Text(
                source.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HsType.sourceLabel.copyWith(color: accent),
              ),
            ),
          ),
        const Spacer(),
        // Leave room for the ruler.
        Padding(
          padding: const EdgeInsets.only(right: HsSpace.x4),
          child: Text(
            relativeTime(when),
            style: HsType.timestamp.copyWith(color: palette.textMuted),
          ),
        ),
      ],
    );
  }
}

/// A thin ruler marking position in a finite set — the reader can see the
/// bottom coming.
class PositionRuler extends StatelessWidget {
  const new({
    required this.total,
    required this.index,
    required this.accent,
    super.key,
  });

  final int total;
  final int index;
  final Color accent;

  /// More than this many marks stops reading as a ruler and starts reading as
  /// texture, so longer sets are sampled down.
  static const maxMarks = 12;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final marks = total.clamp(1, maxMarks);
    final active = total <= maxMarks
        ? index
        : ((index / (total - 1)) * (marks - 1)).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < marks; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          AnimatedContainer(
            duration: HsMotion.lingerSettle,
            curve: HsMotion.lingerSettleCurve,
            width: i == active ? 14 : 6,
            height: 2,
            decoration: BoxDecoration(
              color: i == active
                  ? accent
                  : palette.textMuted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ],
    );
  }
}

class _HardStop extends StatelessWidget {
  const new({required this.total, required this.onBackToToday});

  final int total;
  final VoidCallback onBackToToday;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.all(HsRadius.sheet),
        border: Border.all(color: palette.stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
      child: Stack(
        children: [
          Center(
            child: CaughtUp(
              large: true,
              detail: total == 0
                  ? 'There is nothing waiting. Everything from your sources '
                        'has been seen.'
                  : '$total ${total == 1 ? 'item' : 'items'}, all of them '
                        'seen. There is no card behind this one.',
              actionLabel: 'Back to Today',
              onAction: onBackToToday,
              note:
                  'Swiping up from here does not load more. It settles '
                  'back to this card.',
            ),
          ),
          Positioned(
            right: HsSpace.x3,
            top: 34,
            child: PositionRuler(
              total: total + 1,
              index: total,
              accent: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
