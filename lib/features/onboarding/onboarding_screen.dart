import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/search_field.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/sources/source_catalog.dart';
import 'package:headshorts/features/sources/opml_explainer.dart';
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
  final _chosen = <String>{};
  var _query = '';

  /// Which language the catalog is narrowed to while picking, or null for
  /// all of them. A filter on the list, nothing more: it never unpicks a
  /// source that has scrolled out of view.
  String? _language;

  SourceCatalog get _catalog =>
      ref.read(sourceCatalogProvider).value ?? SourceCatalog.empty;

  var _seeded = false;

  /// Calm defaults: a couple from each of the first few categories, rather
  /// than everything. Two or three good ones beat twenty you skim.
  ///
  /// **English only.** A reader who wants a regional paper will pick it —
  /// switching one on for them assumes a language they may not read, and an
  /// unreadable headline in the first briefing is worse than a shorter one.
  ///
  /// Seeded when the catalog actually arrives, not when the step changes —
  /// the asset is read asynchronously and may not be parsed yet.
  void _seedDefaults() {
    if (_seeded || _catalog.sources.isEmpty) return;
    _seeded = true;
    for (final entry in _catalog.grouped('', language: 'en').entries.take(3)) {
      for (final source in entry.value.take(2)) {
        _chosen.add(source.feedUrl);
      }
    }
  }

  Future<void> _continue() async {
    final repository = ref.read(sourceRepositoryProvider);
    for (final source in _catalog.sources.where(
      (s) => _chosen.contains(s.feedUrl),
    )) {
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

  /// Skipping is allowed: an empty briefing that says so beats a set of feeds
  /// nobody chose.
  Future<void> _skip() async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (mounted) context.go('/today');
  }

  void _toggleCategory(String category, {required bool selected}) {
    // The same list the reader is looking at: "Select all" must not reach
    // sources the language filter has hidden.
    final urls =
        (_catalog.grouped(_query, language: _language)[category] ??
                const <CatalogSource>[])
            .map((s) => s.feedUrl);
    setState(() {
      if (selected) {
        _chosen.addAll(urls);
      } else {
        _chosen.removeAll(urls);
      }
    });
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
  Widget build(BuildContext context) {
    // Watched, not read, so the asset starts loading on the welcome step and
    // the picker has something to show the moment it opens.
    ref.watch(sourceCatalogProvider);
    if (_step == _Step.pick) _seedDefaults();
    return _build(context);
  }

  Widget _build(BuildContext context) => ColoredBox(
    color: context.hs.background,
    child: SafeArea(
      // Each step arrives the way a pushed page does: the router's slide and
      // fade on motion-page, the one push transition in the app.
      child: AnimatedSwitcher(
        duration: HsMotion.of(context, HsMotion.page),
        switchInCurve: HsMotion.curveOf(context, HsMotion.pageCurve),
        switchOutCurve: HsMotion.curveOf(context, HsMotion.pageCurve),
        transitionBuilder: (child, animation) {
          final fade = FadeTransition(opacity: animation, child: child);
          if (HsMotion.reduced(context)) return fade;
          return SlideTransition(
            position: Tween(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(animation),
            child: fade,
          );
        },
        child: KeyedSubtree(key: ValueKey(_step), child: _stepView(context)),
      ),
    ),
  );

  Widget _stepView(BuildContext context) => switch (_step) {
    _Step.welcome => _Welcome(
      onChoose: () => setState(() => _step = _Step.pick),
      onImport: () => _leaveTo('/sources/opml'),
    ),
    _Step.pick => _Pick(
      grouped: _catalog.grouped(_query, language: _language),
      languages: _catalog.languages,
      language: _language,
      chosen: _chosen,
      onSearch: (query) => setState(() => _query = query),
      onLanguage: (tag) => setState(() => _language = tag),
      onToggleCategory: _toggleCategory,
      onSkip: _skip,
      onToggle: (url) => setState(() {
        if (!_chosen.remove(url)) _chosen.add(url);
      }),
      onContinue: _chosen.isEmpty ? null : _continue,
      onAddOwn: () => _leaveTo('/sources/add-url'),
      onImport: () => _leaveTo('/sources/opml'),
    ),
    _Step.fetch => const InitialFetch(),
  };
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
    required this.grouped,
    required this.languages,
    required this.language,
    required this.chosen,
    required this.onToggle,
    required this.onToggleCategory,
    required this.onSearch,
    required this.onLanguage,
    required this.onContinue,
    required this.onSkip,
    required this.onAddOwn,
    required this.onImport,
  });

  final Map<String, List<CatalogSource>> grouped;

  /// Every language the catalog carries, not only the ones already picked —
  /// the point of the first run is to find publishers you do not have.
  final List<String> languages;
  final String? language;
  final Set<String> chosen;
  final ValueChanged<String> onToggle;
  final void Function(String category, {required bool selected})
  onToggleCategory;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onLanguage;
  final VoidCallback? onContinue;
  final VoidCallback onSkip;
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
            grouped: grouped,
            chosen: chosen,
            onToggle: onToggle,
            onToggleCategory: onToggleCategory,
            leading: Padding(
              padding: const EdgeInsets.only(top: HsSpace.x2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HsSearchField(
                    hint: 'Search publishers and categories',
                    onChanged: onSearch,
                  ),
                  if (languages.length > 1) ...[
                    const SizedBox(height: HsSpace.x3),
                    LanguageChips(
                      languages: languages,
                      value: language,
                      onChanged: onLanguage,
                    ),
                  ],
                ],
              ),
            ),
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
            child: Row(
              children: [
                Expanded(
                  child: HsButton(
                    'Skip',
                    onPressed: onSkip,
                    kind: HsButtonKind.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: HsButton('Continue', onPressed: onContinue)),
                const SizedBox(width: 10),
                // The two other ways in — pasting an address, importing a
                // file — are choices a handful of readers make once. They
                // belong in an overflow beside the step's own action, not
                // above the catalog competing with it.
                _MoreWaysIn(onAddOwn: onAddOwn, onImport: onImport),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The overflow beside Continue: paste an address, or import a file.
///
/// Wears **Skip's** dress — a hairline outline, no fill — square. These are
/// asides from the step, like Skip, and only Continue should carry the ink:
/// two filled buttons side by side would read as two things to choose
/// between.
class _MoreWaysIn extends StatelessWidget {
  const new({required this.onAddOwn, required this.onImport});

  final VoidCallback onAddOwn;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return Builder(
      builder: (anchorContext) => Pressable(
        onTap: () async {
          final picked = await showHsMenu<String>(
            context: context,
            anchorContext: anchorContext,
            above: true,
            minWidth: 240,
            entries: const [
              HsMenuEntry(
                value: 'url',
                label: 'Add your own',
                icon: Icons.link_rounded,
              ),
              HsMenuEntry(
                value: 'opml',
                label: 'Import OPML',
                icon: Icons.file_open_outlined,
              ),
              HsMenuEntry(
                value: 'about',
                label: 'About OPML',
                icon: Icons.info_outline_rounded,
              ),
            ],
          );
          switch (picked) {
            case 'url':
              onAddOwn();
            case 'opml':
              onImport();
            case 'about':
              if (context.mounted) {
                unawaited(showOpmlExplainer(context, onImport: onImport));
              }
          }
        },
        semanticLabel: 'Other ways to add sources',
        child: Container(
          width: HsSize.buttonLarge,
          height: HsSize.buttonLarge,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: palette.stroke),
            borderRadius: HsRadius.buttonBorder,
          ),
          child: Icon(
            Icons.more_horiz_rounded,
            size: 20,
            color: palette.textPrimary,
          ),
        ),
      ),
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
            AnimatedContainer(
              // Each bar takes its source's colour as that feed lands. The
              // motion is the arrival, not a loop — nothing here animates on
              // its own.
              duration: HsMotion.page,
              curve: HsMotion.pageCurve,
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
