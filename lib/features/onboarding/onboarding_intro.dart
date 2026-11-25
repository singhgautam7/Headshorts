import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/theme_ripple.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/features/more/segmented_control.dart';
import 'package:headshorts/features/onboarding/onboarding_art.dart';
import 'package:headshorts/features/onboarding/onboarding_spec.dart';

/// The pager: three short pages, one idea each, then the setup page every
/// install passes. State lives in the screen (it needs the page for Android
/// back); this is the view of it.
class OnboardingIntro extends StatelessWidget {
  const new({
    required this.pages,
    required this.page,
    required this.onPageChanged,
    required this.onGoTo,
    required this.onFinish,
    required this.onImport,
    super.key,
  });

  /// Three feature pages, then setup.
  static const featureCount = 3;
  static const setupIndex = featureCount;
  static const count = featureCount + 1;

  final PageController pages;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onGoTo;

  /// The setup page's primary: on to choosing sources.
  final VoidCallback onFinish;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final setup = page == setupIndex;
    return Column(
      children: [
        SizedBox(
          height: OnboardingSpec.skipHeight,
          child: setup
              ? null
              : _Skip(onSkip: () => pages.jumpToPage(setupIndex)),
        ),
        Expanded(
          child: Stack(
            children: [
              PageView(
                controller: pages,
                onPageChanged: onPageChanged,
                children: [
                  _FeaturePage(
                    art: BriefingArt(active: page == 0),
                    title: 'A briefing that ends.',
                    titleStyle: HsType.welcome,
                    body:
                        'HeadShorts reads the feeds you choose, in the order '
                        'they were published. No algorithm, no counts, no '
                        'infinite scroll. When you reach the bottom, that is '
                        'the news.',
                  ),
                  _FeaturePage(
                    art: TwoWaysArt(active: page == 1),
                    title: 'Two ways to read',
                    body:
                        'Headlines lists every story from all your sources, '
                        'newest first. Linger shows one story at a time: '
                        'swipe up for the next.',
                  ),
                  _FeaturePage(
                    art: SourcesArt(active: page == 2),
                    title: 'Yours, on your phone',
                    body:
                        'Your sources, your list. No account and no server. '
                        'What you follow and what you read stay on this '
                        'phone.',
                  ),
                  const _SetupPage(),
                ],
              ),
              // Content that scrolls at a large font fades out above the
              // bar rather than meeting a hard edge. A gradient of the
              // ground, not a mask: no offscreen layer for the whole pager.
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: OnboardingSpec.fade,
                child: IgnorePointer(child: _FadeOut()),
              ),
            ],
          ),
        ),
        _NavBar(
          page: page,
          count: count,
          primaryLabel: setup ? 'Choose your sources' : 'Next',
          onPrimary: setup ? onFinish : () => onGoTo(page + 1),
          onBack: () => onGoTo(page - 1),
          onImport: page == 0 ? onImport : null,
        ),
      ],
    );
  }
}

class _FadeOut extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final ground = context.hs.background;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ground.withValues(alpha: 0), ground],
        ),
      ),
    );
  }
}

/// A page's frame: content centred when it fits, or filling the page with
/// [fill], and scrolling when it does not fit.
class _PageFrame extends StatelessWidget {
  const new({required this.child, this.fill = false});

  final Widget child;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.fromLTRB(
      HsSpace.x5,
      HsSpace.x2,
      HsSpace.x5,
      OnboardingSpec.fade,
    );
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: pad,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - pad.vertical),
          child: fill ? child : Align(child: child),
        ),
      ),
    );
  }
}

class _FeaturePage extends StatelessWidget {
  const new({
    required this.art,
    required this.title,
    required this.body,
    this.titleStyle,
  });

  final Widget art;
  final String title;
  final TextStyle? titleStyle;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return _PageFrame(
      fill: true,
      // The picture takes whatever the words leave, so a short phone shrinks
      // it and a tall one shows it large.
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: OnboardingSpec.artMin,
                ),
                // Positioned, so the drawing adds nothing to the intrinsic
                // height it is being fitted into.
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: OnboardingEntrance(
                        delay: OnboardingSpec.delayArt,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: OnboardingSpec.artMax,
                            ),
                            // A drawing: it does not grow with the font.
                            child: SizedBox.expand(
                              child: FittedBox(
                                child: MediaQuery.withNoTextScaling(
                                  child: ExcludeSemantics(child: art),
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
            const SizedBox(height: HsSpace.x5),
            OnboardingEntrance(
              delay: OnboardingSpec.delayTitle,
              child: Text(
                title,
                style: (titleStyle ?? HsType.stepTitle).copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: HsSpace.x3),
            OnboardingEntrance(
              delay: OnboardingSpec.delayBody,
              child: Text(
                body,
                style: HsType.bodySans.copyWith(color: palette.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page every install passes. One choice, Light / Dark / System, saved
/// the moment it is made and revealed from the finger.
class _SetupPage extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<_SetupPage> {
  /// Where the pointer last went down: the theme ripple grows from there.
  Offset _down = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingEntrance(
            delay: OnboardingSpec.delayArt,
            child: Text(
              'Make it yours',
              style: HsType.welcome.copyWith(color: palette.textPrimary),
            ),
          ),
          const SizedBox(height: HsSpace.x3),
          OnboardingEntrance(
            delay: OnboardingSpec.delayTitle,
            child: Text(
              'You can change this any time in Settings.',
              style: HsType.bodySans.copyWith(color: palette.textSecondary),
            ),
          ),
          const SizedBox(height: HsSpace.x6),
          OnboardingEntrance(
            delay: OnboardingSpec.delayBody,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: HsSpace.x2),
                  child: Text(
                    'LOOK',
                    style: HsType.sectionLabel.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ),
                Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (e) => _down = e.position,
                  child: SegmentedControl<ThemeMode>(
                    value: mode,
                    options: const {
                      ThemeMode.light: 'Light',
                      ThemeMode.dark: 'Dark',
                      ThemeMode.system: 'System',
                    },
                    onChanged: (m) => unawaited(
                      ThemeRipple.of(context).run(
                        _down,
                        () =>
                            ref.read(settingsProvider.notifier).setThemeMode(m),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade with a short slide in. Subtle: no delay, half the distance. Off: a
/// 90 ms fade. The delay is the head of one controller's timeline, so no
/// timer is left pending.
class OnboardingEntrance extends StatefulWidget {
  const new({
    required this.child,
    this.delay = Duration.zero,
    this.beginOffset = OnboardingSpec.entranceSlide,
    this.duration = OnboardingSpec.entrance,
    this.rise = 0,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final Offset beginOffset;
  final Duration duration;
  final double rise;

  @override
  State<OnboardingEntrance> createState() => _OnboardingEntranceState();
}

class _OnboardingEntranceState extends State<OnboardingEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late Animation<double> _value;
  MotionLevel _level = MotionLevel.expressive;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _level = HsMotion.levelOf(context);
    final delay = _level == MotionLevel.expressive
        ? widget.delay
        : Duration.zero;
    final run = switch (_level) {
      MotionLevel.off => HsMotion.fxInstant,
      MotionLevel.subtle => HsMotion.fxDefault,
      MotionLevel.expressive => widget.duration,
    };
    final total = (delay + run).inMilliseconds.toDouble();
    _controller.duration = delay + run;
    _value = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMilliseconds / total,
        1,
        curve: HsMotion.curveEffects,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = switch (_level) {
      MotionLevel.expressive => 1.0,
      MotionLevel.subtle => 0.5,
      MotionLevel.off => 0.0,
    };
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _value,
        child: AnimatedBuilder(
          animation: _value,
          child: widget.child,
          builder: (context, child) => FractionalTranslation(
            translation: widget.beginOffset * k * (1 - _value.value),
            child: Transform.translate(
              offset: Offset(0, widget.rise * k * (1 - _value.value)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dots: the active one a 24 wide pill in the primary.
class OnboardingDots extends StatelessWidget {
  const new({required this.current, required this.count, super.key});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final off = HsMotion.levelOf(context) == MotionLevel.off;
    return Semantics(
      label: 'Step ${current + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: off ? Duration.zero : HsMotion.page,
              curve: HsMotion.pageCurve,
              width: i == current
                  ? OnboardingSpec.dotActive
                  : OnboardingSpec.dotInactive,
              height: OnboardingSpec.dotHeight,
              margin: const EdgeInsets.symmetric(
                horizontal: OnboardingSpec.dotMargin,
              ),
              decoration: BoxDecoration(
                color: i == current ? palette.primary : palette.stroke,
                borderRadius: HsRadius.pillBorder,
              ),
            ),
        ],
      ),
    );
  }
}

/// Top right.
class _Skip extends StatelessWidget {
  const new({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: HsSpace.x3),
      child: IntrinsicWidth(
        child: HsButton(
          'Skip',
          onPressed: onSkip,
          kind: HsButtonKind.tertiary,
          height: HsSize.buttonCompact,
        ),
      ),
    ),
  );
}

/// The bottom bar: dots, then Back and the primary. It has no ground of its
/// own; the page's content fades out above it.
///
/// At a large system font the two buttons stack, Back under the primary, so
/// a label is never cut to fit beside the other.
class _NavBar extends StatelessWidget {
  const new({
    required this.page,
    required this.count,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onBack,
    this.onImport,
  });

  final int page;
  final int count;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onBack;

  /// Import OPML, on the first page only. Its room is kept on every page, so
  /// the pager does not change height underneath a swipe.
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final off = HsMotion.levelOf(context) == MotionLevel.off;
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
    final showBack = page > 0;

    final primary = AnimatedSwitcher(
      duration: off ? HsMotion.fxInstant : HsMotion.fxFast,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: off
            ? child
            : SlideTransition(
                position: Tween(
                  begin: OnboardingSpec.labelSlide,
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
      ),
      child: HsButton(
        primaryLabel,
        key: ValueKey(primaryLabel),
        onPressed: onPrimary,
      ),
    );
    final back = HsButton(
      'Back',
      onPressed: showBack ? onBack : null,
      kind: HsButtonKind.secondary,
    );

    final Widget buttons = large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              if (showBack) ...[const SizedBox(height: HsSpace.x3), back],
            ],
          )
        : Row(
            children: [
              AnimatedContainer(
                duration: off ? Duration.zero : HsMotion.page,
                curve: HsMotion.pageCurve,
                width: showBack ? OnboardingSpec.backWidth : 0,
                // Fixed: the overflow box would otherwise take all the height
                // there is. Below the large-font cut a button is one line.
                height: HsSize.buttonLarge,
                margin: EdgeInsets.only(right: showBack ? HsSpace.x3 : 0),
                child: ClipRect(
                  child: ExcludeSemantics(
                    excluding: !showBack,
                    child: OverflowBox(
                      maxWidth: OnboardingSpec.backWidth,
                      alignment: Alignment.centerLeft,
                      child: back,
                    ),
                  ),
                ),
              ),
              Expanded(child: primary),
            ],
          );

    return OnboardingEntrance(
      delay: OnboardingSpec.barEntranceDelay,
      duration: OnboardingSpec.barEntrance,
      beginOffset: Offset.zero,
      rise: OnboardingSpec.barRise,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HsSpace.x5,
            0,
            HsSpace.x5,
            HsSpace.x5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Visibility(
                visible: onImport != null,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: HsButton(
                  'Import OPML',
                  onPressed: onImport,
                  kind: HsButtonKind.tertiary,
                  height: HsSize.buttonCompact,
                ),
              ),
              const SizedBox(height: HsSpace.x2),
              OnboardingDots(current: page, count: count),
              const SizedBox(height: HsSpace.x4),
              buttons,
            ],
          ),
        ),
      ),
    );
  }
}
