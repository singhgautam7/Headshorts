import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/core/motion/expand_collapse.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/features/reader/related/related_matcher.dart';
import 'package:headshorts/features/reader/related/related_provider.dart';

/// "Other sources on this story", under the article.
///
/// Waits for the Reader's first frame and a beat more before it asks for
/// anything, takes no height until there is a match, then opens (ExpandCollapse
/// honours the motion level, so Off is a short fade and nothing moves).
class OtherSourcesSection extends ConsumerStatefulWidget {
  const new(this.articleId, {super.key});

  final int articleId;

  @override
  ConsumerState<OtherSourcesSection> createState() =>
      _OtherSourcesSectionState();
}

class _OtherSourcesSectionState extends ConsumerState<OtherSourcesSection> {
  bool _go = false;
  Timer? _timer;
  List<RelatedStory> _last = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _go = true);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_go) return const SizedBox.shrink();
    final found = ref.watch(relatedProvider(widget.articleId)).value;
    if (found != null) _last = found;
    final stories = _last;
    return ExpandCollapse(
      expanded: stories.isNotEmpty,
      child: stories.isEmpty
          ? const SizedBox(width: double.infinity)
          : _Body(stories),
    );
  }
}

class _Body extends StatelessWidget {
  const new(this.stories);

  final List<RelatedStory> stories;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: HsSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Other sources on this story'),
          const SizedBox(height: HsSpace.x2),
          for (final s in stories) _Row(s),
          const SizedBox(height: HsSpace.x2),
          Text(
            'Matches are found by keywords, so only stories in the same '
            'language show up.',
            style: HsType.note.copyWith(color: context.hs.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const new(this.story);

  final RelatedStory story;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final accent = SourceAccent.fromValues(story.accentDark, story.accentLight);
    final tone = Theme.of(context).brightness == Brightness.dark
        ? accent.onDark
        : accent.onLight;
    final when = relativeTime(story.publishedAt);
    return Pressable(
      kind: PressKind.row,
      semanticLabel: '${story.sourceTitle}, ${story.title}, $when',
      onTap: () => context.push('/reader/${story.articleId}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: HsSpace.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                HsType.sourceLabelText(story.sourceTitle),
                style: HsType.sourceLabelFor(story.sourceTitle)
                    .copyWith(color: tone),
              ),
              const SizedBox(height: HsSpace.x1),
              Text(
                story.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: HsType.forText(
                  HsType.cardHeadlineMedium,
                  story.title,
                ).copyWith(color: hs.textPrimary),
              ),
              const SizedBox(height: HsSpace.x1),
              Text(when, style: HsType.timestamp.copyWith(color: hs.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
