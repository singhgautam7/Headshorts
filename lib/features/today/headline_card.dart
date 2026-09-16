import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/source_repository.dart';

/// One headline in the Today list.
///
/// Anatomy: a 3dp accent rule, then the source label in the accent, the
/// headline in serif, an optional one-line summary, and the timestamp. A
/// thumbnail appears only when the feed provided one.
///
/// Read items drop to half opacity and add a lowercase "read" after the
/// timestamp. There is no count, no dot and no badge.
class HeadlineCard extends StatelessWidget {
  const new(
    this.headline, {
    required this.onTap,
    this.washed = false,
    this.offline = false,
    super.key,
  });

  final Headline headline;
  final VoidCallback onTap;

  /// The optional lead-card wash. Light theme only, and only ever a tint.
  final bool washed;

  /// Prefixes the timestamp with "cached", so an offline briefing says so.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final tone = headline.source.accent;
    final accent = tone.resolve(isDark: palette.isDark);
    final article = headline.article;
    final summary = article.summary;
    final imageUrl = article.imageUrl;

    final author = article.author?.trim();
    final hasAuthor = author != null && author.isNotEmpty;

    final stamp = [
      if (offline) 'cached',
      relativeTime(article.publishedAt),
      if (headline.isRead) 'read',
    ].join(' · ');

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headline.source.title.toUpperCase(),
          style: HsType.sourceLabel.copyWith(color: accent),
        ),
        if (hasAuthor) ...[
          const SizedBox(height: 3),
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HsType.timestamp.copyWith(color: palette.textSecondary),
          ),
        ],
        const SizedBox(height: 7),
        Text(
          article.title,
          style: HsType.cardHeadline.copyWith(color: palette.textPrimary),
        ),
        if (summary != null && summary.isNotEmpty && imageUrl == null) ...[
          const SizedBox(height: 7),
          Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HsType.cardSummary.copyWith(color: palette.textSecondary),
          ),
        ],
        const SizedBox(height: 7),
        Text(stamp, style: HsType.timestamp.copyWith(color: palette.textMuted)),
      ],
    );

    return AccentScope(
      accent: tone,
      child: Pressable(
        onTap: onTap,
        semanticLabel:
            '${headline.source.title}${hasAuthor ? ', by $author' : ''}. ${article.title}',
        child: Opacity(
          opacity: headline.isRead ? 0.5 : 1,
          child: Container(
            padding: washed ? const EdgeInsets.all(HsSpace.x4) : null,
            decoration: washed
                ? BoxDecoration(
                    color: accentWash(accent, palette),
                    borderRadius: HsRadius.cardBorder,
                  )
                : null,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: HsSize.accentBar,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: text),
                  if (imageUrl != null) ...[
                    const SizedBox(width: 14),
                    _Thumbnail(imageUrl),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const new(this.url);

  final String url;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: context.hs.surfaceVariant);
    // The row stretches its children to the card's height; the thumbnail
    // stays square and sits with the top of the text block.
    return Align(
      alignment: Alignment.topCenter,
      child: ClipRRect(
        borderRadius: HsRadius.buttonBorder,
        child: SizedBox(
          width: HsSize.thumbnail,
          height: HsSize.thumbnail,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            // Decoded at the size it is drawn. A publisher's 2000px hero
            // behind a 76dp thumbnail costs ~16MB of bitmap for nothing, and
            // a screen of them is what makes Today scroll badly.
            memCacheWidth:
                (HsSize.thumbnail * MediaQuery.devicePixelRatioOf(context))
                    .round(),
            // Flat fills, never a shimmer sweep.
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          ),
        ),
      ),
    );
  }
}
