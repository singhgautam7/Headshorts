import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/motion.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/canonical_url.dart' show bodyHasImage;
import 'package:headshorts/core/util/language.dart';
import 'package:headshorts/core/util/open_in_web.dart';
import 'package:headshorts/core/util/relative_time.dart';
import 'package:headshorts/core/util/text_direction.dart';
import 'package:headshorts/core/widgets/app_header.dart';
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
import 'package:headshorts/features/reader/related/other_sources_section.dart';
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

  /// Answers derived from the article body, worked out once per body.
  ///
  /// Both used to be computed in `build`, and both walk the whole extracted
  /// document. A body over [_isolateAbove] characters is parsed on a
  /// background isolate, so opening a long article never stalls a frame; until
  /// it lands the body stays on its skeleton ([_derived] is false).
  static const _isolateAbove = 8000;
  Extraction? _derivedFrom;
  ReaderDoc? _derivedFor;
  String? _standfirstText;
  bool _bodyCarriesLead = false;
  bool _bodyIsEmpty = false;
  bool _derived = true;

  /// Whether the route's push has finished. The body is only mounted after
  /// it: building a whole article under a sliding page costs frames.
  bool _pushDone = false;
  Animation<double>? _routeAnimation;

  void _derive(ReaderDoc doc, Extraction? extraction) {
    if (identical(_derivedFrom, extraction) && identical(_derivedFor, doc)) {
      return;
    }
    _derivedFrom = extraction;
    _derivedFor = doc;
    final image = doc.imageUrl;
    if (extraction is! ExtractedArticle) {
      _derived = true;
      _bodyIsEmpty = false;
      _standfirstText = _standfirst(doc, extraction, '');
      _bodyCarriesLead = false;
      return;
    }
    if (extraction.html.length <= _isolateAbove) {
      _apply(doc, extraction, _parseBody((extraction.html, image)));
      return;
    }
    _derived = false;
    unawaited(
      compute(_parseBody, (extraction.html, image)).then((parsed) {
        if (!mounted ||
            !identical(_derivedFrom, extraction) ||
            !identical(_derivedFor, doc)) {
          return;
        }
        setState(() => _apply(doc, extraction, parsed));
      }),
    );
  }

  void _apply(ReaderDoc doc, Extraction extraction, (String, bool) parsed) {
    final (text, hasLead) = parsed;
    _derived = true;
    _bodyIsEmpty = text.isEmpty;
    _standfirstText = _standfirst(doc, extraction, text);
    _bodyCarriesLead = hasLead;
  }

  /// One parse of the body, shared: the standfirst compares against its
  /// opening, the body only needs to know whether there is any, and the lead
  /// image check looks for the feed's picture in it. Top level so it can run
  /// on an isolate.
  static (String, bool) _parseBody((String, String?) args) {
    final (html, image) = args;
    return (
      FeedParser.plainText(html).trim(),
      image != null && bodyHasImage(html, image),
    );
  }

  void _onPushStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_pushDone && mounted) {
      setState(() => _pushDone = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pushDone || _routeAnimation != null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || HsMotion.levelOf(context) == MotionLevel.off) {
      _pushDone = true;
      return;
    }
    _routeAnimation = animation..addStatusListener(_onPushStatus);
    // `route.animation` is a proxy that still reports "completed" during the
    // first build of a push, so the status is only trusted a frame later.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _onPushStatus(animation.status),
    );
  }

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
    _routeAnimation?.removeStatusListener(_onPushStatus);
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
  void _followReading(int index) {
    if (!_following || index == _followedIndex) return;
    _followedIndex = index;
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
    final docAsync = ref.watch(readerDocProvider(_key));
    final doc = docAsync.value;
    final extraction = ref.watch(readerBodyProvider(_key));
    // Selected, not the whole of Settings: the Reader has no business
    // rebuilding because a speech rate or a list size changed — and while
    // read-aloud is running, the speed control writes settings.
    final textSize = ref.watch(settingsProvider.select((s) => s.textSize));

    // A pruned id, or a lookup that failed: say so, rather than an endless
    // skeleton. (`hasError`, not `when`: its error branch never runs here.)
    if (docAsync.hasError || (docAsync.hasValue && doc == null)) {
      return const _MissingStory();
    }
    if (doc == null) {
      return ColoredBox(
        color: palette.background,
        child: const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              HsSpace.x5,
              HsSize.appBarHeight,
              HsSpace.x5,
              0,
            ),
            child: _BodySkeleton(),
          ),
        ),
      );
    }

    final accentTone = doc.accent;
    final accent = accentTone.resolve(isDark: palette.isDark);
    final failed = extraction.hasError;
    final thin = failed || extraction.value is ThinExtraction;
    // Only whether it is active: the word highlight ticks several times a
    // second and the Reader has no business rebuilding for it. The views
    // below watch what they need themselves.
    final listenActive = ref.watch(
      listenProvider(doc.language).select((s) => s.active),
    );
    final voiceMissing = ref.watch(
      listenProvider(doc.language).select((s) => s.unsupported),
    );
    ref.listen(
      listenProvider(doc.language).select((s) => (s.active, s.index)),
      (_, next) {
        if (next.$1) _followReading(next.$2);
      },
    );
    _derive(doc, extraction.value);
    _syncListenState(active: listenActive);
    // The body mounts once the push has landed and its parse is in hand.
    final bodyLoading = !_pushDone || !_derived || extraction.isLoading;

    final header = AppHeader(
      title: doc.sourceTitle.toUpperCase(),
      titleStyle: HsType.lingerLabel.copyWith(color: accent),
      onBack: () => _leave(context),
      actions: [
        HsIconButton(
          semanticLabel: 'Text size',
          onPressed: () => setState(() => _sizePanelOpen = !_sizePanelOpen),
          active: _sizePanelOpen,
          child: (color) =>
              Text('Aa', style: HsType.buttonSmall.copyWith(color: color)),
        ),
      ],
    );

    return AccentScope(
      accent: accentTone,
      child: ColoredBox(
        color: palette.background,
        // The top bar is the app's floating header: it turns into the pill on
        // scroll and the prose runs under it. The bottom actions are separate.
        child: HeaderPage(
          header: header,
          body: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _onScroll(notification);
                          return false;
                        },
                        // Slivers, so the body is laid out as it is reached.
                        child: CustomScrollView(
                          controller: _scroll,
                          slivers: [
                            _padded(
                              SliverList.list(
                                children: [
                                  HeaderPage.gap(),
                                  const SizedBox(height: HsSpace.x2),
                                  Text(
                                    doc.title,
                                    textDirection: textDirectionOf(doc.title),
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
                                  if (_standfirstText case final dek?) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      dek,
                                      textDirection: textDirectionOf(dek),
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
                                ],
                              ),
                            ),
                            // While it reads, the plain-text listen view
                            // stands in for the rendered body: the engine
                            // reports a word as a range in the string it was
                            // given, so that string has to be what is drawn.
                            if (listenActive)
                              _padded(
                                SliverToBoxAdapter(
                                  child: ListenView(
                                    language: doc.language,
                                    accent: accent,
                                    bodySize: textSize.fontSize,
                                    spokenKey: _spokenKey,
                                    highlightWords: ref.watch(
                                      settingsProvider.select(
                                        (s) => s.highlightWords,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            // Flat skeleton while the page slides in and the
                            // body is parsed; the article fades in over it.
                            else if (bodyLoading)
                              _padded(
                                const SliverToBoxAdapter(
                                  child: _BodySkeleton(),
                                ),
                              )
                            else
                              _FadeInSliver(
                                sliver: SliverMainAxisGroup(
                                  slivers: [
                                    // The feed's picture, unless the body
                                    // carries it — the publisher's own figure
                                    // keeps its caption and its place.
                                    if (doc.imageUrl != null &&
                                        !_bodyCarriesLead)
                                      _padded(
                                        SliverToBoxAdapter(
                                          child: _LeadImage(
                                            url: doc.imageUrl!,
                                            articleUrl: doc.link,
                                          ),
                                        ),
                                      ),
                                    for (final sliver in _body(
                                      context,
                                      failed
                                          ? const ThinExtraction(
                                              'The article could not be '
                                              'fetched.',
                                            )
                                          : extraction.value ??
                                                const ThinExtraction(''),
                                      textSize,
                                      doc,
                                    ))
                                      _padded(sliver),
                                  ],
                                ),
                              ),
                            const SliverToBoxAdapter(
                              child: SizedBox(
                                height: HsSpace.navClearance + 20,
                              ),
                            ),
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
                top: _panelTop(context, header),
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
              if (listenActive && !_following)
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
              if (voiceMissing != null)
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
                  child: listenActive
                      ? ListenBar(
                          key: const ValueKey('listen'),
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

  /// Where the text-size card hangs: under whichever form the header is in
  /// right now (the pill once scrolled, the rest header at the top), or under
  /// what is left of it when Floating header is off and it has scrolled away.
  double _panelTop(BuildContext context, AppHeader header) {
    final sb = MediaQuery.paddingOf(context).top;
    final restBottom = sb + header.restHeight(context);
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    if (!ref.read(settingsProvider).floatingHeader) {
      return math.max(sb, restBottom - offset);
    }
    return offset >= HsMotion.pillAt
        ? sb + HeaderSpec.top + HeaderSpec.pillHeight
        : restBottom;
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
        if (_bodyIsEmpty) {
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
            asSliver: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: HsSpace.x6),
              child: _OriginalSourceCard(doc: doc),
            ),
          ),
          // Other publishers' takes on the same story: the end of the full
          // text, cached articles only. Renders nothing when there are none.
          if (doc.articleId case final id?)
            SliverToBoxAdapter(child: OtherSourcesSection(id)),
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
      SliverToBoxAdapter(
        child: Container(
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
      ),
    ];
  }

  /// The summary as a standfirst, or null when the body already opens with
  /// it (feeds whose description is the first paragraph) or it is missing.
  static String? _standfirst(
    ReaderDoc doc,
    Extraction? extraction,
    String bodyText,
  ) {
    final dek = doc.summary?.trim();
    if (dek == null || dek.length < 20) return null;
    if (extraction is! ExtractedArticle) return dek;
    final probe = dek.substring(0, dek.length.clamp(0, 40));
    return bodyText.startsWith(probe) ? null : dek;
  }
}

/// The article's column: the same side margins for every sliver in it.
Widget _padded(Widget sliver) => SliverPadding(
  padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
  sliver: sliver,
);

/// The body fading in where the skeleton was, once. Paint only: the slivers
/// under it are built a single time.
class _FadeInSliver extends StatefulWidget {
  const new({required this.sliver});

  final Widget sliver;

  @override
  State<_FadeInSliver> createState() => _FadeInSliverState();
}

class _FadeInSliverState extends State<_FadeInSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_in.isAnimating || _in.isCompleted) return;
    _in.animateTo(
      1,
      duration: HsMotion.levelOf(context) == MotionLevel.off
          ? HsMotion.fxInstant
          : HsMotion.fxDefault,
      curve: HsMotion.curveEffects,
    );
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SliverFadeTransition(opacity: _in, sliver: widget.sliver);
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

/// Back, even when the Reader is the only route (a deep link, a widget tap):
/// then it goes to Headlines rather than closing the app.
void _leave(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).maybePop();
  } else if (router.canPop()) {
    router.pop();
  } else {
    router.go('/today');
  }
}

/// A story that is no longer in the cache and was never saved.
class _MissingStory extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HsSpace.x5,
                HsSpace.x3,
                HsSpace.x5,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: HsIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => _leave(context),
                  semanticLabel: 'Back',
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(HsSpace.x5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This story is no longer saved on your phone.',
                        textAlign: TextAlign.center,
                        style: HsType.statTitle.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: HsSpace.x5),
                      HsButton(
                        'Back to Headlines',
                        onPressed: () {
                          final router = GoRouter.maybeOf(context);
                          if (router == null) {
                            _leave(context);
                          } else {
                            router.go('/today');
                          }
                        },
                        height: HsSize.buttonSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 0),
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
          kind: PressKind.row,
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
      kind: PressKind.chip,
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
        HsHaptics.confirm();
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
    if (saved) {
      HsHaptics.tick();
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

    HsHaptics.confirm();
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
    // the one soft shadow — with air between them. Each is a Pressable on
    // the icon-button morph: a circle at rest, a 12 dp squircle while held.
    Widget pill({
      required VoidCallback onTap,
      required Widget child,
      String? label,
    }) => Pressable(
      kind: PressKind.iconButton,
      onTap: onTap,
      semanticLabel: label,
      restRadius: HsSize.navItem / 2,
      pressedRadius: HsRadius.heldIcon,
      builder: (context, radius, _) => _PillSurface(
        radius: radius,
        blur: blur,
        child: SizedBox(height: HsSize.navItem, child: child),
      ),
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
          child: pill(
            onTap: thin && onRetry != null
                ? onRetry!
                : () => unawaited(openInWeb(doc.link)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: palette.textPrimary,
                ),
                const SizedBox(width: HsSpace.x2),
                // Flexible: at a large font scale, or on a narrow screen, the
                // label gives way rather than pushing the others off.
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
        const SizedBox(width: HsSpace.x3),
        Builder(
          builder: (btnContext) => pill(
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
            label: 'Share',
            child: glyph(Icons.share_rounded),
          ),
        ),
        const SizedBox(width: HsSpace.x3),
        // Save for later, between Share and More. Ink only, never the source
        // accent: the control belongs to the reader, not to the publisher.
        Semantics(
          toggled: saved,
          label: 'Save for later',
          child: pill(
            onTap: () => unawaited(_toggleSaved(context, ref, saved: saved)),
            child: SizedBox(
              width: HsSize.navItem,
              child: Center(
                child: AnimatedSwitcher(
                  duration: HsMotion.of(context, HsMotion.micro),
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
        const SizedBox(width: HsSpace.x3),
        Builder(
          builder: (btnContext) => pill(
            onTap: () => unawaited(
              _showReaderMenu(
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
            ),
            label: 'More options',
            child: glyph(Icons.more_horiz_rounded),
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

/// [NavPillSurface]'s dress — nav tone, hairline, the one soft shadow,
/// optional blur — with the corner radius handed in, so a held button can
/// relax from a circle to a squircle. `NavPillSurface` itself keeps a fixed
/// pill; this is the same object with the radius as a parameter.
class _PillSurface extends StatelessWidget {
  const new({required this.radius, required this.blur, required this.child});

  final double radius;
  final bool blur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final shape = BorderRadius.circular(radius);
    final inner = DecoratedBox(
      decoration: BoxDecoration(
        color: blur ? palette.nav.withValues(alpha: 0.86) : palette.nav,
        borderRadius: shape,
        border: Border.all(color: palette.stroke),
      ),
      child: child,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: HsSize.navPillInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: [palette.navShadow],
        ),
        child: blur
            ? ClipRRect(
                borderRadius: shape,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: inner,
                ),
              )
            : inner,
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
