import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/open_in_web.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/notice.dart';
import 'package:headshorts/data/db/article_repository.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/readability/extraction_service.dart';
import 'package:headshorts/features/reader/article_body.dart';
import 'package:headshorts/features/reader/reader_controller.dart';
import 'package:share_plus/share_plus.dart';

/// The in-app full article.
///
/// Reader-view parity with a browser, run entirely on the device. Always
/// attributed, always one tap from the publisher, and when extraction comes
/// back thin it says so plainly and hands off rather than showing an empty
/// page.
class ReaderScreen extends ConsumerStatefulWidget {
  const new(this.articleId, {super.key});

  final int articleId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _opened = DateTime.now();
  bool _sizePanelOpen = false;
  bool _pillVisible = true;
  double _scrollTravel = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Opening the full article is the only thing in the app that counts as
      // reading it — from Today or from Linger alike.
      unawaited(
        ref
            .read(articleRepositoryProvider)
            .mark(widget.articleId, mode: ReadMode.full),
      );
    });
  }

  @override
  void deactivate() {
    // Dwell is recorded once, on the way out, so Stats can report reading
    // time without the article screen carrying a timer.
    unawaited(
      ref
          .read(articleRepositoryProvider)
          .mark(
            widget.articleId,
            mode: ReadMode.full,
            dwell: DateTime.now().difference(_opened),
          ),
    );
    super.deactivate();
  }

  void _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final metrics = notification.metrics;
      if (!metrics.hasContentDimensions ||
          metrics.maxScrollExtent <= 0 ||
          metrics.pixels <= metrics.minScrollExtent) {
        if (!_pillVisible) setState(() => _pillVisible = true);
        return;
      }
      if (delta == 0) return;
      if (delta.sign != _scrollTravel.sign) _scrollTravel = 0;
      _scrollTravel += delta;
      if (_scrollTravel > 24 && _pillVisible) {
        setState(() => _pillVisible = false);
      } else if (_scrollTravel < -24 && !_pillVisible) {
        setState(() => _pillVisible = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final headline = ref.watch(articleProvider(widget.articleId)).value;
    final extraction = ref.watch(extractionProvider(widget.articleId));
    final textSize = ref.watch(settingsProvider).textSize;

    if (headline == null) {
      return ColoredBox(color: palette.background, child: const SizedBox());
    }

    final accentTone = headline.source.accent;
    final accent = accentTone.resolve(isDark: palette.isDark);
    final article = headline.article;
    final thin = extraction.value is ThinExtraction;

    return AccentScope(
      accent: accentTone,
      child: ColoredBox(
        color: palette.background,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Bar(
                      source: headline.source.title,
                      accent: accent,
                      sizePanelOpen: _sizePanelOpen,
                      onToggleSizePanel: () =>
                          setState(() => _sizePanelOpen = !_sizePanelOpen),
                    ),
                    AnimatedSize(
                      duration: HsMotion.tabSlide,
                      curve: HsMotion.tabSlideCurve,
                      alignment: Alignment.topCenter,
                      child: _sizePanelOpen
                          ? _TextSizePanel(step: textSize)
                          : const SizedBox(width: double.infinity),
                    ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _onScroll(notification);
                          return false;
                        },
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            HsSpace.x5,
                            26,
                            HsSpace.x5,
                            HsSpace.navClearance + 20,
                          ),
                          children: [
                            Text(
                              article.title,
                              style: HsType.readerTitle.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _Attribution(
                              headline: headline,
                              minutes: switch (extraction.value) {
                                final ExtractedArticle a => a.minutes,
                                _ => null,
                              },
                            ),
                            const SizedBox(height: 18),
                            const HsDivider(),
                            const SizedBox(height: 18),
                            // A lead image from the feed. Extraction does not always
                            // carry a publisher's figures into the article body, and
                            // an article that had a picture should still show one.
                            if (article.imageUrl != null &&
                                !_bodyHasImage(extraction.value))
                              _LeadImage(
                                url: article.imageUrl!,
                                articleUrl: article.link,
                              ),
                            ...switch (extraction) {
                              AsyncData(:final value) => _body(
                                context,
                                value,
                                article.summary,
                                textSize,
                                article.link,
                              ),
                              AsyncError() => _body(
                                context,
                                const ThinExtraction(
                                  'The article could not be fetched.',
                                ),
                                article.summary,
                                textSize,
                                article.link,
                              ),
                              _ => [const _BodySkeleton()],
                            },
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedSlide(
                      offset: _pillVisible ? Offset.zero : const Offset(0, 1.8),
                      duration: HsMotion.page,
                      curve: HsMotion.pageCurve,
                      child: _ReaderFloatingButtons(
                        article: article,
                        sourceTitle: headline.source.title,
                        thin: thin,
                        onRetry: thin
                            ? () => ref.invalidate(
                                extractionProvider(widget.articleId),
                              )
                            : null,
                        onToggleSizePanel: () =>
                            setState(() => _sizePanelOpen = !_sizePanelOpen),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    Extraction extraction,
    String? summary,
    TextSizeStep size,
    String link,
  ) {
    final linkMode = ref.read(settingsProvider).linkOpenMode;

    return switch (extraction) {
      ExtractedArticle(:final html) => () {
        final text = FeedParser.plainText(html).trim();
        if (text.isEmpty) {
          return _thinView(
            context,
            'The publisher did not provide readable body text.',
            summary,
            size,
            link,
          );
        }
        return [
          ArticleBody(
            html: html,
            articleUrl: link,
            bodySize: size.fontSize,
            linkMode: linkMode,
          ),
        ];
      }(),
      ThinExtraction(:final reason) => _thinView(
        context,
        reason,
        summary,
        size,
        link,
      ),
    };
  }

  List<Widget> _thinView(
    BuildContext context,
    String reason,
    String? summary,
    TextSizeStep size,
    String link,
  ) {
    final palette = context.hs;
    return [
      if (summary != null && summary.isNotEmpty) ...[
        Text(
          summary,
          style: HsType.readerBody(size.fontSize)
              .copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 18),
      ],
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.stroke),
          borderRadius: HsRadius.cardBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'That is all this feed gives us',
              style: HsType.statTitle.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: HsSpace.x3),
            Text(
              '$reason The rest is on their page.',
              style: HsType.note.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 14),
            HsButton(
              'Open in web',
              onPressed: () => openInWeb(link),
              height: HsSize.buttonSmall,
            ),
          ],
        ),
      ),
    ];
  }

  /// Whether the extracted body already carries a picture of its own.
  static bool _bodyHasImage(Extraction? extraction) =>
      extraction is ExtractedArticle && extraction.html.contains('<img');
}

/// The article's own picture, above the body.
///
/// Fails quietly: a publisher that will not serve its image leaves the article
/// looking like an article without one, rather than like a broken page.
class _LeadImage extends StatelessWidget {
  const new({required this.url, required this.articleUrl});

  final String url;
  final String articleUrl;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CachedNetworkImage(
        imageUrl: url,
        httpHeaders: ExtractionService.imageHeaders(articleUrl),
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const new({
    required this.source,
    required this.accent,
    required this.sizePanelOpen,
    required this.onToggleSizePanel,
  });

  final String source;
  final Color accent;
  final bool sizePanelOpen;
  final VoidCallback onToggleSizePanel;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: SizedBox(
        height: HsSize.appBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Pressable(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(context).maybePop();
                },
                semanticLabel: 'Back',
                child: SizedBox(
                  width: HsSize.navItem,
                  height: HsSize.navItem,
                  child: Center(child: HsGlyph.back(palette.textPrimary)),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    source.toUpperCase(),
                    style: HsType.lingerLabel.copyWith(color: accent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Pressable(
                onTap: onToggleSizePanel,
                semanticLabel: 'Text size',
                child: Container(
                  width: HsSize.navItem,
                  height: HsSize.navItem,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sizePanelOpen ? palette.surfaceVariant : null,
                    borderRadius: HsRadius.pillBorder,
                  ),
                  child: Text(
                    'Aa',
                    style: HsType.buttonSmall.copyWith(
                      color: sizePanelOpen
                          ? palette.textPrimary
                          : palette.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextSizePanel extends ConsumerWidget {
  const new({required this.step});

  final TextSizeStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: HsSpace.x4),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.divider),
        borderRadius: HsRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Text size',
                  style: HsType.buttonSmall.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Text(
                'Follows the system setting',
                style: HsType.timestamp.copyWith(color: palette.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextSizeSlider(
            step: step,
            onChanged: (next) =>
                ref.read(settingsProvider.notifier).setTextSize(next),
          ),
        ],
      ),
    );
  }
}

/// The A—A slider. It offsets the system size rather than overriding it.
class TextSizeSlider extends StatelessWidget {
  const new({required this.step, required this.onChanged, super.key});

  final TextSizeStep step;
  final ValueChanged<TextSizeStep> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    const steps = TextSizeStep.values;
    final fraction = steps.length == 1 ? 0.0 : step.index / (steps.length - 1);

    return Row(
      children: [
        Text(
          'A',
          style: HsType.readerBody(13).copyWith(color: palette.textMuted),
        ),
        const SizedBox(width: HsSpace.x3),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => onChanged(
                steps[_indexAt(details.localPosition.dx, constraints.maxWidth)],
              ),
              onHorizontalDragUpdate: (details) => onChanged(
                steps[_indexAt(details.localPosition.dx, constraints.maxWidth)],
              ),
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
                      duration: HsMotion.micro,
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
                    AnimatedAlign(
                      duration: HsMotion.micro,
                      curve: HsMotion.microCurve,
                      alignment: Alignment(fraction * 2 - 1, 0),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: HsSpace.x3),
        Text(
          'A',
          style: HsType.readerBody(21).copyWith(color: palette.textPrimary),
        ),
      ],
    );
  }

  int _indexAt(double dx, double width) {
    final steps = TextSizeStep.values.length;
    return ((dx / width) * (steps - 1)).round().clamp(0, steps - 1);
  }
}

class _Attribution extends StatelessWidget {
  const new({required this.headline, required this.minutes});

  final Headline headline;
  final int? minutes;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final author = headline.article.author;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (author != null && author.isNotEmpty) ...[
          Text(
            author,
            style: HsType.readerByline.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: HsSpace.x1),
        ],
        Text(
          [
            headline.source.title,
            articleDateline(headline.article.publishedAt),
            if (minutes != null) '$minutes min read',
          ].join(' · '),
          style: HsType.readerMeta.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}

Future<void> _showReaderMenu({
  required BuildContext context,
  required BuildContext anchorContext,
  required ArticleRow article,
  required VoidCallback onToggleSizePanel,
}) async {
  final palette = context.hs;
  final overlay =
      Navigator.of(context, rootNavigator: true).overlay?.context
              .findRenderObject() as RenderBox?;
  if (overlay == null) return;

  final anchor = anchorContext.findRenderObject() as RenderBox?;
  final topLeft = anchor != null
      ? anchor.localToGlobal(Offset.zero, ancestor: overlay)
      : Offset.zero;
  final size = anchor?.size ?? const Size(HsSize.navItem, HsSize.navItem);

  final position = RelativeRect.fromLTRB(
    topLeft.dx - 140,
    topLeft.dy - 170,
    overlay.size.width - (topLeft.dx + size.width),
    overlay.size.height - topLeft.dy,
  );

  final selected = await showMenu<String>(
    context: context,
    position: position,
    useRootNavigator: true,
    color: palette.surface,
    elevation: 8,
    shadowColor: palette.navShadow.color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: palette.stroke),
    ),
    items: [
      PopupMenuItem<String>(
        value: 'copy',
        height: 44,
        child: Row(
          children: [
            Icon(Icons.copy_rounded, size: 18, color: palette.textPrimary),
            const SizedBox(width: 12),
            Text(
              'Copy link',
              style: HsType.buttonSmall.copyWith(color: palette.textPrimary),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'web',
        height: 44,
        child: Row(
          children: [
            Icon(Icons.open_in_browser_rounded, size: 18, color: palette.textPrimary),
            const SizedBox(width: 12),
            Text(
              'Open in browser',
              style: HsType.buttonSmall.copyWith(color: palette.textPrimary),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'text_size',
        height: 44,
        child: Row(
          children: [
            Icon(Icons.format_size_rounded, size: 18, color: palette.textPrimary),
            const SizedBox(width: 12),
            Text(
              'Text size',
              style: HsType.buttonSmall.copyWith(color: palette.textPrimary),
            ),
          ],
        ),
      ),
    ],
  );

  if (selected == 'copy') {
    await Clipboard.setData(ClipboardData(text: article.link));
    if (context.mounted) {
      unawaited(HapticFeedback.selectionClick());
      showNotice(context, 'Link copied');
    }
  } else if (selected == 'web') {
    unawaited(openInWeb(article.link));
  } else if (selected == 'text_size') {
    onToggleSizePanel();
  }
}

class _ReaderFloatingButtons extends ConsumerWidget {
  const new({
    required this.article,
    required this.sourceTitle,
    required this.thin,
    required this.onRetry,
    required this.onToggleSizePanel,
  });

  final ArticleRow article;
  final String sourceTitle;
  final bool thin;
  final VoidCallback? onRetry;
  final VoidCallback onToggleSizePanel;

  Widget _buildSurface({
    required Widget child,
    required HsPalette palette,
    required bool blur,
    required BoxShape shape,
    BorderRadius? borderRadius,
  }) {
    final inner = blur
        ? (shape == BoxShape.circle
            ? ClipOval(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.navActive.withValues(alpha: 0.86),
                      border: Border.all(color: palette.stroke),
                    ),
                    child: child,
                  ),
                ),
              )
            : ClipRRect(
                borderRadius: borderRadius ?? HsRadius.pillBorder,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius ?? HsRadius.pillBorder,
                      color: palette.navActive.withValues(alpha: 0.86),
                      border: Border.all(color: palette.stroke),
                    ),
                    child: child,
                  ),
                ),
              ))
        : DecoratedBox(
            decoration: BoxDecoration(
              shape: shape,
              borderRadius: shape == BoxShape.circle
                  ? null
                  : (borderRadius ?? HsRadius.pillBorder),
              color: palette.navActive,
              border: Border.all(color: palette.stroke),
            ),
            child: child,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : (borderRadius ?? HsRadius.pillBorder),
        boxShadow: [palette.navShadow],
      ),
      child: inner,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final blur = ref.watch(settingsProvider).blurBehindNav;

    final webButton = Pressable(
      onTap: thin && onRetry != null
          ? onRetry
          : () => openInWeb(article.link),
      child: _buildSurface(
        palette: palette,
        blur: blur,
        shape: BoxShape.rectangle,
        borderRadius: HsRadius.pillBorder,
        child: Container(
          height: HsSize.navItem,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            thin ? 'Try again' : 'Open in web',
            style: HsType.buttonSmall.copyWith(
              color: palette.textPrimary,
            ),
          ),
        ),
      ),
    );

    final shareButton = Builder(
      builder: (btnContext) => Pressable(
        onTap: () {
          final box = btnContext.findRenderObject() as RenderBox?;
          final origin = box != null
              ? (box.localToGlobal(Offset.zero) & box.size)
              : null;
          unawaited(
            SharePlus.instance.share(
              ShareParams(
                text: '${article.title}\n\n${article.link}',
                subject: article.title,
                sharePositionOrigin: origin,
              ),
            ),
          );
        },
        semanticLabel: 'Share',
        child: _buildSurface(
          palette: palette,
          blur: blur,
          shape: BoxShape.circle,
          child: SizedBox(
            width: HsSize.navItem,
            height: HsSize.navItem,
            child: Center(
              child: Icon(
                Icons.share_rounded,
                size: 18,
                color: palette.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );

    final moreButton = Builder(
      builder: (btnContext) => Pressable(
        onTap: () => _showReaderMenu(
          context: context,
          anchorContext: btnContext,
          article: article,
          onToggleSizePanel: onToggleSizePanel,
        ),
        semanticLabel: 'More options',
        child: _buildSurface(
          palette: palette,
          blur: blur,
          shape: BoxShape.circle,
          child: SizedBox(
            width: HsSize.navItem,
            height: HsSize.navItem,
            child: Center(
              child: Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: palette.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: HsSize.navPillInset),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          webButton,
          const SizedBox(width: 10),
          shareButton,
          const SizedBox(width: 10),
          moreButton,
        ],
      ),
    );
  }
}

class _BodySkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final fill = context.hs.skeleton;
    Widget bar(double factor) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: factor,
        child: Container(
          height: 14,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );

    return Column(
      children: [
        bar(1),
        bar(0.94),
        bar(0.62),
        const SizedBox(height: 12),
        bar(0.98),
        bar(0.86),
      ],
    );
  }
}
