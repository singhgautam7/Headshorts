import 'package:flutter/material.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/features/onboarding/onboarding_spec.dart';

/// The welcome illustrations: small working pictures of the app itself, each
/// acting out its page once when the page is reached. Drawn at a fixed size
/// and fitted to the room there is.

const _stories = <(String, String)>[
  ('City News', 'New metro line opens to the public on Sunday'),
  ('Science', 'Telescope spots water on a distant world'),
  ('Business', 'Small shops see their best month in years'),
  ('Sport', 'Underdogs win the cup after extra time'),
  ('World', 'Leaders agree on a plan to protect the ocean'),
  ('Culture', 'An old cinema finds a new audience'),
];

/// Runs once from 0 to 1 whenever [active] turns true. With motion off the
/// picture is simply in its last state.
class _Scene extends StatefulWidget {
  const new({required this.active, required this.builder});

  final bool active;
  final Widget Function(BuildContext context, Animation<double> t) builder;

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: OnboardingSpec.scene,
  );

  void _play() {
    if (!widget.active) {
      _c.value = 0;
    } else if (HsMotion.levelOf(context) == MotionLevel.off) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(_Scene old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _play();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: widget.builder(context, _c));
}

Animation<double> _part(Animation<double> t, double from, double to) =>
    CurvedAnimation(
      parent: t,
      curve: Interval(from, to, curve: HsMotion.pageSlideCurve),
    );

/// A small phone with [child] on its screen.
class _Phone extends StatelessWidget {
  const new({required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Container(
      width: size.width,
      height: size.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.all(HsRadius.sheet),
        border: Border.all(color: palette.stroke, width: 1.5),
      ),
      child: child,
    );
  }
}

class _Row extends StatelessWidget {
  const new(this.story);

  final (String, String) story;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = SourceAccent.fromKey(story.$1)
        .resolve(isDark: palette.isDark);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 2, color: accent),
            const SizedBox(width: HsSpace.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.$1.toUpperCase(),
                    style: HsType.sourceLabel.copyWith(
                      fontSize: 8,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    story.$2,
                    style: HsType.headline.copyWith(
                      fontSize: 12.5,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenTitle extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
    child: Text(
      text,
      style: HsType.screenTitle.copyWith(
        fontSize: 17,
        color: context.hs.textPrimary,
      ),
    ),
  );
}

/// Page 1: the list is read to its end, and it does end.
class BriefingArt extends StatelessWidget {
  const new({required this.active, super.key});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return _Scene(
      active: active,
      builder: (context, t) {
        final scroll = _part(t, 0.1, 0.8);
        final done = _part(t, 0.78, 1);
        return _Phone(
          size: const Size(210, 270),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ScreenTitle('Headlines'),
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: AnimatedBuilder(
                      animation: scroll,
                      builder: (context, child) => FractionalTranslation(
                        // The list less the height of the window onto it.
                        translation: Offset(0, -0.46 * scroll.value),
                        child: child,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final story in _stories) _Row(story),
                            const SizedBox(height: 6),
                            FadeTransition(
                              opacity: done,
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 24,
                                    color: palette.primary,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "You're caught up",
                                    style: HsType.statTitle.copyWith(
                                      fontSize: 13,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Page 2: the two ways to read, side by side. The list on the left; on the
/// right one card, swiped up for the next.
class TwoWaysArt extends StatelessWidget {
  const new({required this.active, super.key});

  final bool active;

  static const _size = Size(150, 220);

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    Widget named(String name, Widget phone) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        phone,
        const SizedBox(height: HsSpace.x2),
        Text(
          name,
          style: HsType.statTitle.copyWith(
            fontSize: 14,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
    return _Scene(
      active: active,
      builder: (context, t) {
        final swipe = _part(t, 0.4, 0.7);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            named(
              'Headlines',
              _Phone(
                size: _size,
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final story in _stories.take(4)) _Row(story),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: HsSpace.x5),
            named(
              'Linger',
              _Phone(
                size: _size,
                child: Stack(
                  children: [
                    for (var i = 0; i < 2; i++)
                      AnimatedBuilder(
                        animation: swipe,
                        builder: (context, child) => FractionalTranslation(
                          translation: Offset(0, i - swipe.value),
                          child: child,
                        ),
                        child: _Card(_stories[i + 1]),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: AnimatedBuilder(
                        animation: swipe,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, -26 * swipe.value),
                          child: Opacity(
                            opacity: 1 - swipe.value * 0.4,
                            child: child,
                          ),
                        ),
                        child: Icon(
                          Icons.swipe_up_rounded,
                          size: 30,
                          color: palette.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const new(this.story);

  final (String, String) story;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = SourceAccent.fromKey(story.$1)
        .resolve(isDark: palette.isDark);
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentWash(accent, palette, on: palette.background),
        borderRadius: HsRadius.cardBorder,
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            story.$1.toUpperCase(),
            style: HsType.sourceLabel.copyWith(fontSize: 8, color: accent),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Text(
              story.$2,
              style: HsType.headline.copyWith(
                fontSize: 17,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 3: sources switched on one by one, kept on this phone.
class SourcesArt extends StatelessWidget {
  const new({required this.active, super.key});

  final bool active;

  static const _names = ['The Hindu', 'BBC News', 'Ars Technica', 'NDTV'];

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return _Scene(
      active: active,
      builder: (context, t) => AnimatedBuilder(
        animation: t,
        builder: (context, _) => Container(
          width: 270,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.all(HsRadius.sheet),
            border: Border.all(color: palette.stroke, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, name) in _names.indexed)
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SourceAccent.fromKey(name)
                            .resolve(isDark: palette.isDark),
                      ),
                    ),
                    const SizedBox(width: HsSpace.x3),
                    Expanded(
                      child: Text(
                        name,
                        style: HsType.row.copyWith(color: palette.textPrimary),
                      ),
                    ),
                    IgnorePointer(
                      child: HsToggle(
                        // The last stays off: the choice is yours.
                        value: i < _names.length - 1 && t.value > 0.2 + i * 0.2,
                        onChanged: (_) {},
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 6),
              const HsDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: palette.textSecondary,
                    ),
                    const SizedBox(width: HsSpace.x2),
                    Flexible(
                      child: Text(
                        'Stays on this phone',
                        style: HsType.note.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
