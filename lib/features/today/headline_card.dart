import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/language.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/prefs/settings.dart';

/// What a list row needs to know about an item, whatever it came from.
///
/// Headlines reads the cache, Search reads the index *and* feeds fetched on
/// the spot, and Bookmarks reads its own snapshots. They are three different
/// row types and one card, so the list-size setting changes all three at once
/// and a fix to the card is a fix everywhere.
@immutable
class ArticleView {
  const new({
    required this.sourceTitle,
    required this.accent,
    required this.title,
    required this.publishedAt,
    this.summary,
    this.imageUrl,
    this.author,
    this.isRead = false,
  });

  factory fromHeadline(Headline headline) => ArticleView(
    sourceTitle: headline.source.title,
    accent: headline.source.accent,
    title: headline.article.title,
    publishedAt: headline.article.publishedAt,
    summary: headline.article.summary,
    imageUrl: headline.article.imageUrl,
    author: headline.article.author,
    isRead: headline.isRead,
  );

  factory fromBookmark(BookmarkRow row) => ArticleView(
    sourceTitle: row.sourceTitle,
    accent: SourceAccent.fromValues(row.accentDark, row.accentLight),
    title: row.title,
    publishedAt: row.publishedAt,
    summary: row.summary,
    imageUrl: row.imageUrl,
    author: row.author,
  );

  final String sourceTitle;
  final SourceAccent accent;
  final String title;
  final DateTime publishedAt;
  final String? summary;
  final String? imageUrl;
  final String? author;
  final bool isRead;
}

/// One item in a list, at whichever size the reader has chosen.
///
/// Anatomy at **large**, the v1 card: a 3dp accent rule, the source label in
/// the accent, the headline in serif, an optional one-line summary, and the
/// timestamp. A thumbnail appears only when the feed provided one.
///
/// **Medium** drops the standfirst, sets the headline a step down and clamps
/// it to three lines, and shrinks the thumbnail. **Small** is headline only:
/// two lines, the source run in at the start in its accent, the time right
/// aligned, hairlines doing the separating instead of rules and images.
///
/// Read items drop to half opacity and add a lowercase "read" after the
/// timestamp. There is no count, no dot and no badge.
class HeadlineCard extends StatelessWidget {
  const new(
    this.view, {
    required this.onTap,
    this.size = ListSize.large,
    this.washed = false,
    this.offline = false,
    this.onLongPress,
    this.highlight,
    super.key,
  });

  /// The list's own model, from an article, a bookmark or a search result.
  final ArticleView view;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ListSize size;

  /// The optional lead-card wash. Light theme only, and only ever a tint.
  final bool washed;

  /// Prefixes the timestamp with "cached", so an offline briefing says so.
  final bool offline;

  /// The search term to mark in the summary, when this row is a result.
  final String? highlight;

  @override
  Widget build(BuildContext context) => switch (size) {
    ListSize.small => _SmallRow(
      view: view,
      onTap: onTap,
      onLongPress: onLongPress,
    ),
    ListSize.medium || ListSize.large => _Card(
      view: view,
      onTap: onTap,
      onLongPress: onLongPress,
      size: size,
      washed: washed,
      offline: offline,
      highlight: highlight,
    ),
  };
}

/// The large and medium card. One layout, two type scales — they differ in
/// the standfirst, the headline step and the thumbnail, and in nothing else.
class _Card extends StatelessWidget {
  const new({
    required this.view,
    required this.onTap,
    required this.onLongPress,
    required this.size,
    required this.washed,
    required this.offline,
    required this.highlight,
  });

  final ArticleView view;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ListSize size;
  final bool washed;
  final bool offline;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final tone = view.accent;
    final accent = tone.resolve(isDark: palette.isDark);
    final medium = size == ListSize.medium;
    final summary = view.summary;
    final imageUrl = view.imageUrl;

    final author = view.author?.trim();
    final hasAuthor = author != null && author.isNotEmpty && !medium;

    final stamp = [
      if (offline) 'cached',
      relativeTime(view.publishedAt),
      if (view.isRead) 'read',
    ].join(' · ');

    final headline = HsType.forText(
      medium ? HsType.cardHeadlineMedium : HsType.cardHeadline,
      view.title,
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SourceLabel(view.sourceTitle, accent: accent, compact: medium),
        if (hasAuthor) ...[
          const SizedBox(height: 3),
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HsType.timestamp.copyWith(color: palette.textSecondary),
          ),
        ],
        SizedBox(height: medium ? 6 : 7),
        Text(
          view.title,
          // Medium clamps: a long headline must not turn a seven-item screen
          // into a four-item one.
          maxLines: medium ? 3 : null,
          overflow: medium ? TextOverflow.ellipsis : null,
          style: headline.copyWith(color: palette.textPrimary),
        ),
        if (!medium &&
            summary != null &&
            summary.isNotEmpty &&
            imageUrl == null) ...[
          const SizedBox(height: 7),
          _Summary(
            summary,
            highlight: highlight,
            style: HsType.forText(
              HsType.cardSummary,
              summary,
            ).copyWith(color: palette.textSecondary),
          ),
        ],
        SizedBox(height: medium ? 6 : 7),
        Text(
          stamp,
          style: (medium ? HsType.timestampSmall : HsType.timestamp).copyWith(
            color: palette.textMuted,
          ),
        ),
      ],
    );

    return AccentScope(
      accent: tone,
      child: Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel:
            '${view.sourceTitle}${hasAuthor ? ', by $author' : ''}. '
            '${view.title}',
        child: Opacity(
          opacity: view.isRead ? 0.5 : 1,
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
                  SizedBox(width: medium ? 12 : 14),
                  Expanded(child: text),
                  if (imageUrl != null) ...[
                    SizedBox(width: medium ? 12 : 14),
                    _Thumbnail(
                      imageUrl,
                      size: medium ? HsSize.thumbnailMedium : HsSize.thumbnail,
                    ),
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

/// The small row: the whole item on two lines.
///
/// No rail and no thumbnail — the source name runs in at the start of the
/// headline in its accent, which is what keeps the list's colour rhythm when
/// there is no room for a rule. Still a 44dp target, because the row's
/// padding and two lines of 14/1.36 clear it.
class _SmallRow extends StatelessWidget {
  const new({
    required this.view,
    required this.onTap,
    required this.onLongPress,
  });

  final ArticleView view;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = view.accent.resolve(isDark: palette.isDark);
    final indic = isIndicText(view.title);

    return AccentScope(
      accent: view.accent,
      child: Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel: '${view.sourceTitle}. ${view.title}',
        child: Opacity(
          opacity: view.isRead ? 0.5 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.divider)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${HsType.sourceLabelText(view.sourceTitle)}'
                                ' ',
                            style: HsType.sourceLabelFor(view.sourceTitle)
                                .copyWith(color: accent),
                          ),
                          TextSpan(text: view.title),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (indic
                                  ? HsType.indic(HsType.cardHeadlineSmall)
                                  : HsType.cardHeadlineSmall)
                              .copyWith(color: palette.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    shortRelativeTime(view.publishedAt),
                    style: HsType.timestampSmall.copyWith(
                      height: 19 / 11,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The publisher's name above a headline.
///
/// Latin sets in tracked caps; an Indic name sets flat, a step larger and
/// unspaced, because letter-spacing pulls a conjunct into its halants and
/// there is no case to raise.
class _SourceLabel extends StatelessWidget {
  const new(this.name, {required this.accent, this.compact = false});

  final String name;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final base = HsType.sourceLabelFor(name);
    return Text(
      HsType.sourceLabelText(name),
      style:
          (compact && !isIndicText(name) ? base.copyWith(fontSize: 10) : base)
              .copyWith(color: accent),
    );
  }
}

/// The summary, with the search term marked where it occurs.
///
/// A quiet surface-variant mark, never a highlight colour: it says where the
/// match is, it does not shout about it.
class _Summary extends StatelessWidget {
  const new(this.text, {required this.style, this.highlight});

  final String text;
  final TextStyle style;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final term = highlight?.trim().toLowerCase();

    if (term == null || term.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final marked = style.copyWith(
      color: palette.textPrimary,
      backgroundColor: palette.surfaceVariant,
    );
    final spans = <TextSpan>[];
    final haystack = text.toLowerCase();
    var cursor = 0;
    while (true) {
      final at = haystack.indexOf(term, cursor);
      if (at < 0) break;
      if (at > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, at)));
      }
      spans.add(
        TextSpan(text: text.substring(at, at + term.length), style: marked),
      );
      cursor = at + term.length;
    }
    spans.add(TextSpan(text: text.substring(cursor)));

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const new(this.url, {required this.size});

  final String url;
  final double size;

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
          width: size,
          height: size,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            // Decoded at the size it is drawn. A publisher's 2000px hero
            // behind a 76dp thumbnail costs ~16MB of bitmap for nothing, and
            // a screen of them is what makes Today scroll badly.
            memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
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

/// The gap between two items at a given size — tighter as the rows shrink.
double listGapFor(ListSize size) => switch (size) {
  ListSize.large => 30,
  ListSize.medium => 20,
  ListSize.small => 0,
};
