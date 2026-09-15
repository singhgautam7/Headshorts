import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/canonical_url.dart' show bodyHasImage;
import 'package:headshorts/core/util/open_in_web.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/nav_pill.dart';
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
      if (_sizePanelOpen) setState(() => _sizePanelOpen = false);
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
                            // The feed's summary is the publisher's
                            // standfirst — The Hindu's `sub-title`, NDTV's
                            // `sp-descp` — and sits under the headline as it
                            // does on their page, unless the body opens with
                            // the same words, when it would only repeat.
                            if (_standfirst(article, extraction.value)
                                case final dek?) ...[
                              const SizedBox(height: 14),
                              Text(
                                dek,
                                style: HsType.readerStandfirst.copyWith(
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
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
                            // The feed's picture, unless the body carries
                            // it — the publisher's own figure keeps its
                            // caption and its place in the story.
                            if (article.imageUrl != null &&
                                !_bodyHasLead(
                                  extraction.value,
                                  article.imageUrl!,
                                ))
                              _LeadImage(
                                url: article.imageUrl!,
                                articleUrl: article.link,
                              ),
                            ...switch (extraction) {
                              AsyncData(:final value) => _body(
                                context,
                                value,
                                textSize,
                                article.link,
                              ),
                              AsyncError() => _body(
                                context,
                                const ThinExtraction(
                                  'The article could not be fetched.',
                                ),
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
              // The text-size popover floats over the prose beneath the bar.
              // Anything outside it — a tap, the start of a scroll — closes
              // it, so it never has to be put away deliberately.
              //
              // The barrier stays in the tree and is merely switched off, so
              // the stack's child list never changes shape: inserting it
              // would shift the switcher below into a new slot, and a
              // freshly built switcher shows its first child without
              // animating.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_sizePanelOpen,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _sizePanelOpen = false),
                    onVerticalDragStart: (_) =>
                        setState(() => _sizePanelOpen = false),
                    onHorizontalDragStart: (_) =>
                        setState(() => _sizePanelOpen = false),
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              // The card slides down from under the bar and back up into
              // it, on the same clock the inline panel used to grow on.
              Positioned(
                top: HsSize.appBarHeight,
                left: 0,
                right: 0,
                child: AnimatedSwitcher(
                  duration: HsMotion.of(context, HsMotion.tabSlide),
                  switchInCurve: HsMotion.curveOf(
                    context,
                    HsMotion.tabSlideCurve,
                  ),
                  switchOutCurve: HsMotion.curveOf(
                    context,
                    HsMotion.tabSlideCurve,
                  ),
                  transitionBuilder: (child, animation) {
                    final fade = FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                    if (HsMotion.reduced(context)) return fade;
                    return SlideTransition(
                      position: Tween(
                        begin: const Offset(0, -0.25),
                        end: Offset.zero,
                      ).animate(animation),
                      child: fade,
                    );
                  },
                  child: _sizePanelOpen
                      ? _TextSizePanel(step: textSize)
                      : const SizedBox.shrink(),
                ),
              ),
              // The actions and the fade beneath them leave together on a
              // scroll down and return together on a scroll up, so the prose
              // gets the whole screen while the reader is reading.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !_pillVisible,
                  child: AnimatedOpacity(
                    opacity: _pillVisible ? 1 : 0,
                    duration: HsMotion.of(context, HsMotion.navHide),
                    curve: HsMotion.curveOf(context, HsMotion.navHideCurve),
                    child: AnimatedSlide(
                      offset: _pillVisible ? Offset.zero : const Offset(0, 1),
                      duration: HsMotion.of(context, HsMotion.navHide),
                      curve: HsMotion.curveOf(context, HsMotion.navHideCurve),
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
      ThinExtraction(:final reason) => _thinView(context, reason, link),
    };
  }

  List<Widget> _thinView(BuildContext context, String reason, String link) {
    // The summary already stands under the headline; the card is all that
    // is left to say.
    final palette = context.hs;
    return [
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

  /// The summary as a standfirst, or null when the body already opens with
  /// it (feeds whose description is the first paragraph) or it is missing.
  static String? _standfirst(ArticleRow article, Extraction? extraction) {
    final dek = article.summary?.trim();
    if (dek == null || dek.length < 20) return null;
    if (extraction is! ExtractedArticle) return dek;
    final opening = FeedParser.plainText(extraction.html).trimLeft();
    final probe = dek.substring(0, dek.length.clamp(0, 40));
    return opening.startsWith(probe) ? null : dek;
  }

  static bool _bodyHasLead(Extraction? extraction, String url) =>
      extraction is ExtractedArticle && bodyHasImage(extraction.html, url);
}

/// The article's own picture, above the body.
class _LeadImage extends StatelessWidget {
  const new({required this.url, required this.articleUrl});

  final String url;
  final String articleUrl;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: ArticleImage(url: url, articleUrl: articleUrl),
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
              HsIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(context).maybePop();
                },
                semanticLabel: 'Back',
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
              HsIconButton(
                semanticLabel: 'Text size',
                onPressed: onToggleSizePanel,
                active: sizePanelOpen,
                child: (color) => Text(
                  'Aa',
                  style: HsType.buttonSmall.copyWith(color: color),
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
        // Floating over the prose now, it borrows the pill's one shadow.
        boxShadow: [palette.navShadow],
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
                step.label,
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

    void step_(int by) {
      final next = (step.index + by).clamp(0, last);
      if (next != step.index) onChanged(steps[next]);
    }

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
                  onTapDown: (d) =>
                      onChanged(steps[indexAt(d.localPosition.dx)]),
                  onHorizontalDragUpdate: (d) =>
                      onChanged(steps[indexAt(d.localPosition.dx)]),
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
                          duration: HsMotion.micro,
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
  final selected = await showHsMenu<String>(
    context: context,
    anchorContext: anchorContext,
    above: true,
    entries: const [
      HsMenuEntry(value: 'copy', label: 'Copy link', icon: Icons.link_rounded),
      HsMenuEntry(
        value: 'web',
        label: 'Open in browser',
        icon: Icons.open_in_browser_rounded,
      ),
      HsMenuEntry(
        value: 'text_size',
        label: 'Text size',
        icon: Icons.format_size_rounded,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final blur = ref.watch(settingsProvider.select((s) => s.blurBehindNav));

    // Three separate objects in the home pill's dress — the nav tone, a
    // hairline, the one soft shadow — with air between them. The primary
    // action takes the width; share and more keep their place on the right.
    Widget pill(Widget child) => NavPillSurface(
      blur: blur,
      child: SizedBox(height: HsSize.navItem, child: child),
    );
    Widget glyph(IconData icon) => SizedBox(
      width: HsSize.navItem,
      child: Center(child: Icon(icon, size: 20, color: palette.textPrimary)),
    );

    final actions = Row(
      children: [
        // On a thin extraction the card in the body already offers the
        // publisher, so this becomes the retry instead of a second copy.
        Expanded(
          child: Pressable(
            onTap: thin && onRetry != null
                ? onRetry
                : () => openInWeb(article.link),
            child: pill(
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: palette.textPrimary,
                  ),
                  const SizedBox(width: HsSpace.x2),
                  Text(
                    thin ? 'Try again' : 'Open in web',
                    style: HsType.buttonSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: HsSpace.x3),
        Builder(
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
            child: pill(glyph(Icons.share_rounded)),
          ),
        ),
        const SizedBox(width: HsSpace.x3),
        Builder(
          builder: (btnContext) => Pressable(
            onTap: () => _showReaderMenu(
              context: context,
              anchorContext: btnContext,
              article: article,
              onToggleSizePanel: onToggleSizePanel,
            ),
            semanticLabel: 'More options',
            child: pill(glyph(Icons.more_horiz_rounded)),
          ),
        ),
      ],
    );

    // The page ground rising under the actions, so the last lines of prose
    // fade out beneath them instead of colliding with a hairline.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.background.withValues(alpha: 0),
            palette.background.withValues(alpha: 0.9),
            palette.background,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HsSpace.x5,
            HsSpace.x7,
            HsSpace.x5,
            0,
          ),
          child: actions,
        ),
      ),
    );
  }
}

class _BodySkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    Widget bar(double factor) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SkeletonBar(widthFactor: factor),
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
