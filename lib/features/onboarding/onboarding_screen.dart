import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/sources/starter_set.dart';
import 'package:headshorts/features/sources/source_picker.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// First run, and the only place a loading screen earns its keep.
enum _Step { welcome, pick, fetch }

class OnboardingScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.welcome;
  late final Set<String> _chosen = starterSet
      .take(5)
      .map((s) => s.feedUrl)
      .toSet();

  Future<void> _continue() async {
    final repository = ref.read(sourceRepositoryProvider);
    for (final source in starterSet.where((s) => _chosen.contains(s.feedUrl))) {
      await repository.add(
        title: source.title,
        feedUrl: source.feedUrl,
        siteUrl: source.siteUrl,
        category: source.category,
        accent: source.accent,
      );
    }
    if (!mounted) return;
    setState(() => _step = _Step.fetch);

    await ref.read(refreshProvider.notifier).refresh();
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (mounted) context.go('/today');
  }

  /// Leaves onboarding for a screen that adds sources directly. The reader
  /// has made their choice about how to start, so the walkthrough is done.
  Future<void> _leaveTo(String location) async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go('/today');
    unawaited(context.push<void>(location));
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.hs.background,
    child: SafeArea(
      child: switch (_step) {
        _Step.welcome => _Welcome(
          onChoose: () => setState(() => _step = _Step.pick),
          onImport: () => _leaveTo('/sources/opml'),
        ),
        _Step.pick => _Pick(
          chosen: _chosen,
          onToggle: (url) => setState(() {
            if (!_chosen.remove(url)) _chosen.add(url);
          }),
          onContinue: _chosen.isEmpty ? null : _continue,
          onAddOwn: () => _leaveTo('/sources/add'),
          onImport: () => _leaveTo('/sources/opml'),
        ),
        _Step.fetch => const InitialFetch(),
      },
    ),
  );
}

class _Welcome extends StatelessWidget {
  const new({required this.onChoose, required this.onImport});

  final VoidCallback onChoose;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(HsSpace.x5, 26, HsSpace.x5, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const FadingBriefingMark(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A briefing that ends.',
                style: HsType.welcome.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: HsSpace.x5),
              Text(
                'HeadShorts reads the feeds you choose, in the order they were '
                'published. No algorithm, no counts, no infinite scroll. When '
                'you reach the bottom, that is the news.',
                style: HsType.lead.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: HsSpace.x6),
              HsButton('Choose your sources', onPressed: onChoose),
              const SizedBox(height: 14),
              HsButton(
                'Import OPML instead',
                onPressed: onImport,
                kind: HsButtonKind.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The product's one idea, drawn: a column of headlines fading down the page,
/// closed by a short accent rule where the feed stops.
///
/// The same graphic as the app icon, so the icon and the first screen
/// recognise each other.
class FadingBriefingMark extends StatelessWidget {
  const new({
    this.ruleHeight = 2,
    this.gap = 12,
    this.showCaption = true,
    super.key,
  });

  final double ruleHeight;
  final double gap;
  final bool showCaption;

  static const widths = [
    1.0,
    0.84,
    0.95,
    0.71,
    0.88,
    0.62,
    0.79,
    0.5,
    0.66,
    0.36,
  ];
  static const opacities = [
    0.92,
    0.8,
    0.7,
    0.6,
    0.5,
    0.41,
    0.32,
    0.24,
    0.17,
    0.11,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = AccentScope.of(context).resolve(isDark: palette.isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widths.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          FractionallySizedBox(
            widthFactor: widths[i],
            child: Container(
              height: ruleHeight,
              decoration: BoxDecoration(
                color: palette.textPrimary.withValues(alpha: opacities[i]),
                borderRadius: BorderRadius.circular(ruleHeight / 2),
              ),
            ),
          ),
        ],
        if (showCaption) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                width: 28,
                height: ruleHeight,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(ruleHeight / 2),
                ),
              ),
              const SizedBox(width: HsSpace.x3),
              Text(
                'END OF BRIEFING',
                style: HsType.sectionLabel.copyWith(
                  fontSize: 10,
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Pick extends StatelessWidget {
  const new({
    required this.chosen,
    required this.onToggle,
    required this.onContinue,
    required this.onAddOwn,
    required this.onImport,
  });

  final Set<String> chosen;
  final ValueChanged<String> onToggle;
  final VoidCallback? onContinue;
  final VoidCallback onAddOwn;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HsSpace.x5,
            HsSpace.x2,
            HsSpace.x5,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your sources',
                style: HsType.stepTitle.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick a few. You can change them any time in Sources.',
                style: HsType.note.copyWith(color: palette.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: SourcePicker(
            sources: starterSet,
            chosen: chosen,
            onToggle: onToggle,
          ),
        ),
        FadingFooter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              HsSpace.x5,
              HsSpace.x4,
              HsSpace.x5,
              26,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: HsButton(
                        'Add your own',
                        onPressed: onAddOwn,
                        kind: HsButtonKind.secondary,
                        height: HsSize.buttonCompact,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: HsButton(
                        'Import OPML',
                        onPressed: onImport,
                        kind: HsButtonKind.secondary,
                        height: HsSize.buttonCompact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HsSpace.x3),
                HsButton(
                  'Continue with ${chosen.length}',
                  onPressed: onContinue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One bar per feed, filling as each returns. No spinner, no percentage.
class InitialFetch extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final progress = ref.watch(refreshProvider);
    final sources = ref.watch(sourcesProvider).value ?? const [];
    final enabled = sources.where((s) => s.enabled).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < enabled.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: progress.pending.contains(enabled[i].id)
                    ? palette.skeleton
                    : enabled[i].accent.resolve(isDark: palette.isDark),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
          const SizedBox(height: HsSpace.x6),
          Text(
            'Fetching your first briefing',
            style: HsType.headline.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: HsSpace.x2),
          Text(
            '${progress.done} of ${progress.total == 0 ? enabled.length : progress.total} '
            'feeds in. This is the only time the app will make you wait — '
            'after this it opens straight from cache.',
            style: HsType.bodySans.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: HsSpace.x7),
          Text(
            'One bar per feed, filling as each returns. No spinner, no '
            'percentage.',
            textAlign: TextAlign.center,
            style: HsType.noteTight.copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}
