import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/canonical_url.dart' show bodyHasImage;
import 'package:headshorts/core/util/language.dart';
import 'package:headshorts/core/util/open_in_web.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/nav_pill.dart';
import 'package:headshorts/core/widgets/notice.dart';
import 'package:headshorts/data/db/tables.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/readability/extraction_service.dart';
import 'package:headshorts/features/bookmarks/bookmarks_controller.dart';
import 'package:headshorts/features/bookmarks/bookmarks_screen.dart'
    show showActionNotice, showUndoNotice;
import 'package:headshorts/features/reader/article_body.dart';
import 'package:headshorts/features/reader/listen_controller.dart';
import 'package:headshorts/features/reader/listen_view.dart';
import 'package:headshorts/features/reader/reader_controller.dart';
import 'package:share_plus/share_plus.dart';

/// The in-app full article.
///
/// Reader-view parity with a browser, run entirely on the device. Always
/// attributed, always one tap from the publisher, and when extraction comes
/// back thin it says so plainly and hands off rather than showing an empty
/// page.
///
/// Opened by article id normally, and by bookmark id for a saved article
/// whose row has been pruned or unsubscribed away. Both resolve to one
/// [ReaderDoc], so there is one Reader rather than two that drift apart.
class ReaderScreen extends ConsumerStatefulWidget {
  const new(this.articleId, {this.bookmarkId, super.key});

  final int? articleId;
  final int? bookmarkId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  final _opened = DateTime.now();
  final _scroll = ScrollController();

  /// The controller that is actually speaking, held directly rather than read
  /// back through the provider: on the way out the provider may already be
  /// gone, and the voice still has to stop.
  ListenController? _listening;
  bool _sizePanelOpen = false;
  bool _pillVisible = true;
  double _scrollTravel = 0;

  /// The page follows the reading until the reader scrolls away themselves,
  /// at which point it stops and offers to take them back. Scrolling under
  /// someone's thumb is worse than losing the place.
  bool _following = true;
  int _followedIndex = -1;
  final _spokenKey = GlobalKey();

  /// Whether the listen bar is up, mirrored here so the scroll handler can
  /// see it without reaching for the provider on every frame.
  bool _listenActive = false;

  ReaderKey get _key =>
      (articleId: widget.articleId, bookmarkId: widget.bookmarkId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final articleId = widget.articleId;
    if (articleId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Opening the full article is the only thing in the app that counts as
      // reading it — from Today, from Linger or from Bookmarks alike.
      unawaited(
        ref
            .read(articleRepositoryProvider)
            .mark(articleId, mode: ReadMode.full),
      );
    });
  }

  /// Backgrounding stops the reading.
  ///
  /// Not pause: the reader has left, and a voice that starts talking again
  /// when they come back to check the time is worse than losing the place.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _listening?.shutdown();
  }

  @override
  void deactivate() {
    // Leaving the Reader stops it too — the article is what was being read,
    // and it is no longer on screen.
    _listening?.shutdown();
    final articleId = widget.articleId;
    if (articleId != null) {
      // Dwell is recorded once, on the way out, so Stats can report reading
      // time without the article screen carrying a timer.
      unawaited(
        ref
            .read(articleRepositoryProvider)
            .mark(
              articleId,
              mode: ReadMode.full,
              dwell: DateTime.now().difference(_opened),
            ),
      );
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _listening?.shutdown();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      if (_sizePanelOpen) setState(() => _sizePanelOpen = false);
      final delta = notification.scrollDelta ?? 0;
      final metrics = notification.metrics;
      // While the page is following the reading, the scrolling is the app's
      // own. Letting it drive the action row's hide means the row is already
      // hidden when listening ends, and the reader is left with no controls
      // at all until they scroll up to find them.
      if (_listenActive && _following) return;
      // A drag while it is reading is the reader taking the page back.
      if (notification.dragDetails != null && _following) {
        setState(() => _following = false);
      }
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

  /// Brings the action row back when listening ends.
  ///
  /// It hides on a scroll down, and the reading scrolls the page; without
  /// this the row would return from a listen invisible.
  void _syncListenState({required bool active}) {
    if (active == _listenActive) return;
    _listenActive = active;
    if (active) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pillVisible) return;
      setState(() {
        _pillVisible = true;
        _scrollTravel = 0;
      });
    });
  }

  /// Keeps the paragraph being read in the upper third of the screen.
  void _followReading(ListenState listen) {
    if (!listen.active || !_following) return;
    if (listen.index == _followedIndex) return;
    _followedIndex = listen.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _spokenKey.currentContext;
      if (context == null || !mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: HsMotion.reduced(context) ? Duration.zero : HsMotion.tabSlide,
        curve: HsMotion.tabSlideCurve,
      );
    });
  }

  Future<void> _startListening(ReaderDoc doc, Extraction extraction) async {
    final html = switch (extraction) {
      ExtractedArticle(:final html) => html,
      // A thin extraction reads what there is — the standfirst — and says so
      // rather than refusing.
      ThinExtraction() => doc.summary ?? '',
    };
    if (html.trim().isEmpty) return;
    final controller = ref.read(listenProvider(doc.language).notifier);
    setState(() {
      _following = true;
      _followedIndex = -1;
      _listening = controller;
    });
    await controller.start(html);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final doc = ref.watch(readerDocProvider(_key)).value;
    final extraction = ref.watch(readerBodyProvider(_key));
    final textSize = ref.watch(settingsProvider).textSize;

    if (doc == null) {
      return ColoredBox(color: palette.background, child: const SizedBox());
    }

    final accentTone = doc.accent;
    final accent = accentTone.resolve(isDark: palette.isDark);
    final thin = extraction.value is ThinExtraction;
    final listen = ref.watch(listenProvider(doc.language));
    _syncListenState(active: listen.active);
    _followReading(listen);

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
                      source: doc.sourceTitle,
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
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(
                            HsSpace.x5,
                            26,
                            HsSpace.x5,
                            HsSpace.navClearance + 20,
                          ),
                          children: [
                            Text(
                              doc.title,
                              style: HsType.forText(
                                HsType.readerTitle,
                                doc.title,
                              ).copyWith(color: palette.textPrimary),
                            ),
                            // The feed's summary is the publisher's
                            // standfirst — The Hindu's `sub-title`, NDTV's
                            // `sp-descp` — and sits under the headline as it
                            // does on their page, unless the body opens with
                            // the same words, when it would only repeat.
                            if (_standfirst(doc, extraction.value)
                                case final dek?) ...[
                              const SizedBox(height: 14),
                              Text(
                                dek,
                                style: HsType.forText(
                                  HsType.readerStandfirst,
                                  dek,
                                ).copyWith(color: palette.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 18),
                            _Attribution(
                              doc: doc,
                              minutes: switch (extraction.value) {
                                final ExtractedArticle a => a.minutes,
                                _ => null,
                              },
                            ),
                            const SizedBox(height: 18),
                            const HsDivider(),
                            const SizedBox(height: 18),
                            // While it reads, the plain-text listen view
                            // stands in for the rendered body: the engine
                            // reports a word as a range in the string it was
                            // given, so that string has to be what is drawn.
                            if (listen.active)
                              ListenView(
                                listen: listen,
                                accent: accent,
                                bodySize: textSize.fontSize,
                                spokenKey: _spokenKey,
                                highlightWords: ref.watch(
                                  settingsProvider.select(
                                    (s) => s.highlightWords,
                                  ),
                                ),
                              )
                            else ...[
                              // The feed's picture, unless the body carries
                              // it — the publisher's own figure keeps its
                              // caption and its place in the story.
                              if (doc.imageUrl != null &&
                                  !_bodyHasLead(
                                    extraction.value,
                                    doc.imageUrl!,
                                  ))
                                _LeadImage(
                                  url: doc.imageUrl!,
                                  articleUrl: doc.link,
                                ),
                              ...switch (extraction) {
                                AsyncData(:final value) => _body(
                                  context,
                                  value,
                                  textSize,
                                  doc,
                                ),
                                AsyncError() => _body(
                                  context,
                                  const ThinExtraction(
                                    'The article could not be fetched.',
                                  ),
                                  textSize,
                                  doc,
                                ),
                                _ => [const _BodySkeleton()],
                              },
                            ],
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
              // Scrolled away from the line being spoken, a quiet chip brings
              // the page back rather than the page taking itself back.
              if (listen.active && !_following)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 94,
                  child: Center(
                    child: _BackToReading(
                      onTap: () => setState(() {
                        _following = true;
                        _followedIndex = -1;
                      }),
                    ),
                  ),
                ),
              // The phone has no voice for this language. Said in words, with
              // the one fix, rather than a control that quietly does nothing.
              if (listen.unsupported != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 88,
                  child: UnsupportedLanguageCard(
                    language: HsLanguage.of(doc.language).englishName,
                    onDismiss: () => ref
                        .read(listenProvider(doc.language).notifier)
                        .dismissUnsupported(),
                  ),
                ),
              // The actions and the fade beneath them leave together on a
              // scroll down and return together on a scroll up, so the prose
              // gets the whole screen while the reader is reading. The listen
              // bar takes their place and stays put, because losing the
              // transport controls mid-article is not the same as losing a
              // row of links.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                // The two swap on navHide, sliding past the bottom edge:
                // the listen bar drops away as the action row comes back up,
                // rather than one blinking out and the other blinking in.
                child: AnimatedSwitcher(
                  duration: HsMotion.of(context, HsMotion.navHide),
                  switchInCurve: HsMotion.curveOf(
                    context,
                    HsMotion.navHideCurve,
                  ),
                  switchOutCurve: HsMotion.curveOf(
                    context,
                    HsMotion.navHideCurve,
                  ),
                  // Both stay in the tree while they cross, aligned to the
                  // bottom so the taller one does not shove the other up.
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.bottomCenter,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) {
                    final fade = FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                    if (HsMotion.reduced(context)) return fade;
                    // Played in reverse on the way out, so closing the bar
                    // slides it down.
                    return SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: fade,
                    );
                  },
                  child: listen.active
                      ? ListenBar(
                          key: const ValueKey('listen'),
                          listen: listen,
                          accent: accent,
                          language: doc.language,
                        )
                      : IgnorePointer(
                          key: const ValueKey('actions'),
                          ignoring: !_pillVisible,
                          child: AnimatedOpacity(
                            opacity: _pillVisible ? 1 : 0,
                            duration: HsMotion.of(context, HsMotion.navHide),
                            curve: HsMotion.curveOf(
                              context,
                              HsMotion.navHideCurve,
                            ),
                            child: AnimatedSlide(
                              offset: _pillVisible
                                  ? Offset.zero
                                  : const Offset(0, 1),
                              duration: HsMotion.of(context, HsMotion.navHide),
                              curve: HsMotion.curveOf(
                                context,
                                HsMotion.navHideCurve,
                              ),
                              child: _ReaderFloatingButtons(
                                doc: doc,
                                readerKey: _key,
                                thin: thin,
                                onRetry: thin && doc.articleId != null
                                    ? () => ref.invalidate(
                                        extractionProvider(doc.articleId!),
                                      )
                                    : null,
                                onToggleSizePanel: () =>
                                    setState(() => _sizePanelOpen = true),
                                onListen: () => unawaited(
                                  _startListening(
                                    doc,
                                    extraction.value ??
                                        const ThinExtraction(
                                          'Not fetched yet.',
                                        ),
                                  ),
                                ),
                              ),
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
    ReaderDoc doc,
  ) {
    final linkMode = ref.read(settingsProvider).linkOpenMode;

    return switch (extraction) {
      ExtractedArticle(:final html) => () {
        final text = FeedParser.plainText(html).trim();
        if (text.isEmpty) {
          return _thinView(
            context,
            'The publisher did not provide readable body text.',
            doc,
          );
        }
        return [
          ArticleBody(
            html: html,
            articleUrl: doc.link,
            bodySize: size.fontSize,
            linkMode: linkMode,
          ),
          const SizedBox(height: HsSpace.x6),
          _OriginalSourceCard(doc: doc),
        ];
      }(),
      ThinExtraction(:final reason) => _thinView(context, reason, doc),
    };
  }

  List<Widget> _thinView(BuildContext context, String reason, ReaderDoc doc) {
    // The summary already stands under the headline; the card is all that
    // is left to say.
    final palette = context.hs;
    final author = doc.author?.trim();

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
            const SizedBox(height: HsSpace.x2),
            Text(
              'Source: ${doc.sourceTitle}'
              '${author != null && author.isNotEmpty ? ' · By $author' : ''}',
              style: HsType.rowSub.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: HsSpace.x2),
            Text(
              '$reason The rest is on their page.',
              style: HsType.note.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 14),
            HsButton(
              'Open in web',
              onPressed: () => unawaited(openInWeb(doc.link)),
              height: HsSize.buttonSmall,
            ),
          ],
        ),
      ),
    ];
  }

  /// The summary as a standfirst, or null when the body already opens with
  /// it (feeds whose description is the first paragraph) or it is missing.
  static String? _standfirst(ReaderDoc doc, Extraction? extraction) {
    final dek = doc.summary?.trim();
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
  const new({required this.doc, required this.minutes});

  final ReaderDoc doc;
  final int? minutes;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = doc.accent.resolve(isDark: palette.isDark);
    final author = doc.author?.trim();

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
            doc.sourceTitle,
            articleDateline(doc.publishedAt),
            if (minutes != null) '$minutes min read',
          ].join(' · '),
          style: HsType.readerMeta.copyWith(color: palette.textMuted),
        ),
        const SizedBox(height: HsSpace.x2),
        Pressable(
          onTap: () => unawaited(openInWeb(doc.link)),
          semanticLabel: 'Open original article on ${doc.sourceTitle}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Open original in web',
                style: HsType.buttonSmall.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.open_in_new_rounded, size: 14, color: accent),
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginalSourceCard extends StatelessWidget {
  const new({required this.doc});

  final ReaderDoc doc;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final author = doc.author?.trim();

    return Container(
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
            'Original article from ${doc.sourceTitle}',
            style: HsType.statTitle.copyWith(color: palette.textPrimary),
          ),
          if (author != null && author.isNotEmpty) ...[
            const SizedBox(height: HsSpace.x1),
            Text(
              'By $author',
              style: HsType.note.copyWith(color: palette.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          HsButton(
            'Open original in web',
            onPressed: () => unawaited(openInWeb(doc.link)),
            height: HsSize.buttonSmall,
          ),
        ],
      ),
    );
  }
}

/// The chip that returns the page to the line being spoken.
class _BackToReading extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Back to reading',
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.stroke),
          borderRadius: HsRadius.pillBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_downward_rounded,
              size: 12,
              color: palette.textPrimary,
            ),
            const SizedBox(width: HsSpace.x2),
            Text(
              'Back to reading',
              style: HsType.chipSelected.copyWith(
                fontSize: 12,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The overflow menu.
///
/// Listen leads it. When the phone is known to have no voice for the
/// article's language, the item stays — in secondary ink, with the reason as
/// a sub-line — rather than vanishing: an option that disappears leaves the
/// reader wondering what they did wrong.
Future<void> _showReaderMenu({
  required BuildContext context,
  required BuildContext anchorContext,
  required ReaderDoc doc,
  required VoidCallback onToggleSizePanel,
  required VoidCallback onListen,
  String? listenUnavailable,
}) async {
  final selected = await showHsMenu<String>(
    context: context,
    anchorContext: anchorContext,
    above: true,
    minWidth: 224,
    entries: [
      HsMenuEntry(
        value: 'listen',
        label: 'Listen',
        icon: Icons.volume_up_rounded,
        sub: listenUnavailable,
      ),
      const HsMenuEntry(
        value: 'copy',
        label: 'Copy link',
        icon: Icons.link_rounded,
      ),
      const HsMenuEntry(
        value: 'web',
        label: 'Open in browser',
        icon: Icons.open_in_browser_rounded,
      ),
      const HsMenuEntry(
        value: 'text_size',
        label: 'Text size',
        icon: Icons.format_size_rounded,
      ),
    ],
  );

  switch (selected) {
    case 'listen':
      onListen();
    case 'copy':
      await Clipboard.setData(ClipboardData(text: doc.link));
      if (context.mounted) {
        unawaited(HapticFeedback.selectionClick());
        showNotice(context, 'Link copied');
      }
    case 'web':
      unawaited(openInWeb(doc.link));
    case 'text_size':
      onToggleSizePanel();
  }
}

class _ReaderFloatingButtons extends ConsumerWidget {
  const new({
    required this.doc,
    required this.readerKey,
    required this.thin,
    required this.onRetry,
    required this.onToggleSizePanel,
    required this.onListen,
  });

  final ReaderDoc doc;
  final ReaderKey readerKey;
  final bool thin;
  final VoidCallback? onRetry;
  final VoidCallback onToggleSizePanel;
  final VoidCallback onListen;

  Future<void> _toggleSaved(
    BuildContext context,
    WidgetRef ref, {
    required bool saved,
  }) async {
    final repository = ref.read(bookmarkRepositoryProvider);
    unawaited(HapticFeedback.selectionClick());

    if (saved) {
      final row = await repository.byLink(doc.link);
      await repository.removeByLink(doc.link);
      if (!context.mounted || row == null) return;
      showUndoNotice(
        context,
        'Removed from Bookmarks',
        onUndo: () => unawaited(repository.restore(row)),
      );
      return;
    }

    final articleId = doc.articleId;
    if (articleId == null) return;

    final headline = await ref.read(articleProvider(articleId).future);
    if (headline == null) return;

    // Saved at once, with whatever body has arrived, so the confirmation is
    // immediate — the row it is copied from will not outlive the cache.
    final ready = ref.read(readerBodyProvider(readerKey)).value;
    await repository.save(
      headline,
      contentHtml: switch (ready) {
        ExtractedArticle(:final html) => html,
        _ => doc.savedHtml,
      },
    );
    if (context.mounted) {
      showActionNotice(
        context,
        'Saved to Bookmarks',
        actionLabel: 'View',
        onAction: () => unawaited(context.push('/bookmarks')),
      );
    }

    // Saved while extraction was still running: the text catches up when it
    // lands, so a bookmark made on the way into an article still opens
    // offline later.
    if (ready == null) {
      final settled = await ref.read(readerBodyProvider(readerKey).future);
      if (settled is ExtractedArticle) {
        await repository.attachBody(doc.link, settled.html);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final blur = ref.watch(settingsProvider.select((s) => s.blurBehindNav));
    final saved = ref.watch(isBookmarkedProvider(doc.link)).value ?? false;
    final listenSupported = ref
        .watch(listenSupportedProvider(doc.language))
        .value;

    // Separate objects in the home pill's dress — the nav tone, a hairline,
    // the one soft shadow — with air between them. The primary action takes
    // the width; the rest keep their place on the right.
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
                : () => openInWeb(doc.link),
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
                  // Flexible since the bookmark toggle joined the row: at a
                  // large font scale, or on a narrow screen, the label gives
                  // way rather than pushing the other three off the edge.
                  Flexible(
                    child: Text(
                      thin ? 'Try again' : 'Open in web',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HsType.buttonSmall.copyWith(
                        color: palette.textPrimary,
                      ),
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
                    text: '${doc.title}\n\n${doc.link}',
                    subject: doc.title,
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
        // Save for later, between Share and More. Ink only, never the source
        // accent: the control belongs to the reader, not to the publisher.
        Semantics(
          toggled: saved,
          label: 'Save for later',
          child: Pressable(
            onTap: () => unawaited(_toggleSaved(context, ref, saved: saved)),
            child: pill(
              SizedBox(
                width: HsSize.navItem,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: HsMotion.micro,
                    child: HsGlyph.bookmark(
                      palette.textPrimary,
                      filled: saved,
                      key: ValueKey(saved),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: HsSpace.x3),
        Builder(
          builder: (btnContext) => Pressable(
            onTap: () => _showReaderMenu(
              context: context,
              anchorContext: btnContext,
              doc: doc,
              onToggleSizePanel: onToggleSizePanel,
              onListen: onListen,
              // Only when the answer is already in hand. Null — not yet
              // asked — offers Listen, which explains itself if it cannot
              // run. The menu never waits on the speech engine to open.
              listenUnavailable: listenSupported == false
                  ? 'No ${HsLanguage.of(doc.language).englishName} voice '
                        'on this phone'
                  : null,
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
