import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/search_field.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/features/search/search_controller.dart';
import 'package:headshorts/features/sources/sources_controller.dart';

/// Which sources a search looks through.
///
/// A **lens**, exactly like Headlines' Filter: adding The Verge here searches
/// it once without subscribing to it, and removing a source you follow does
/// not pause it. Paused sources start out of scope but can be brought back
/// in, because the cache still holds what they published.
Future<void> showSearchScopeSheet(BuildContext context) =>
    showHsSheet<void>(context, (context) => const _ScopeSheet());

class _ScopeSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_ScopeSheet> createState() => _ScopeSheetState();
}

class _ScopeSheetState extends ConsumerState<_ScopeSheet> {
  late final Set<String> _draft = {
    for (final entry in ref.read(searchScopeEntriesProvider)) entry.feedUrl,
  };
  String? _language;
  String _query = '';

  void _toggle(String feedUrl) => setState(() {
    if (!_draft.remove(feedUrl)) _draft.add(feedUrl);
  });

  bool _matches(SourceEntry entry) {
    if (_language != null && entry.language != _language) return false;
    if (_query.isEmpty) return true;
    final haystack = '${entry.title} ${entry.category}'.toLowerCase();
    return _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .every(haystack.contains);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final entries = ref.watch(allSourceEntriesProvider).where(_matches);
    final languages = ref.watch(sourceLanguagesProvider);

    final followed = [
      for (final e in entries)
        if (e.isSubscribed) e,
    ];
    final rest = [
      for (final e in entries)
        if (!e.isSubscribed) e,
    ];
    final chosen = _draft.length;

    return HsSheet(
      title: 'Search in',
      subtitle:
          'Search looks only through these. What you follow stays as it is.',
      children: [
        // A single-language catalog is shown no language control at all.
        if (languages.length > 1) ...[
          LanguageChips(
            languages: languages,
            value: _language,
            onChanged: (tag) => setState(() => _language = tag),
          ),
          const SizedBox(height: HsSpace.x5),
        ],
        if (followed.isNotEmpty) ...[
          // How many of what you follow are in scope — not how many of the
          // whole catalog, which is a number nobody asked about.
          SectionLabel(
            'You follow · '
            '${followed.where((e) => _draft.contains(e.feedUrl)).length}'
            ' of ${followed.length}',
          ),
          const SizedBox(height: HsSpace.x3),
          _Chips(entries: followed, chosen: _draft, onTap: _toggle),
          const SizedBox(height: 26),
        ],
        const SectionLabel('From the catalog · not followed'),
        const SizedBox(height: HsSpace.x3),
        HsSearchField(
          hint: 'Find a source',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: HsSpace.x3),
        if (rest.isEmpty)
          Text(
            'Nothing else matches.',
            style: HsType.note.copyWith(color: palette.textMuted),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: _Chips(entries: rest, chosen: _draft, onTap: _toggle),
            ),
          ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: HsButton(
                'Reset to followed',
                onPressed: () {
                  ref.read(searchScopeProvider.notifier).reset();
                  Navigator.of(context).pop();
                },
                kind: HsButtonKind.secondary,
              ),
            ),
            const SizedBox(width: HsSpace.x3),
            Expanded(
              child: HsButton(
                'Search $chosen',
                // An empty scope searches nothing, and saying so beats
                // quietly falling back to everything.
                onPressed: chosen == 0
                    ? null
                    : () {
                        ref.read(searchScopeProvider.notifier).set({..._draft});
                        Navigator.of(context).pop();
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The source chips: in scope carries the source's accent wash, out of scope
/// is a plain hairline. A paused source says so, because "why is nothing
/// coming from this one" is a fair question to answer before it is asked.
class _Chips extends StatelessWidget {
  const new({required this.entries, required this.chosen, required this.onTap});

  final List<SourceEntry> entries;
  final Set<String> chosen;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: HsSpace.x2,
    runSpacing: HsSpace.x2,
    children: [
      for (final entry in entries)
        AccentScope(
          accent: entry.accent,
          child: HsChip(
            entry.isSubscribed && !entry.isOn
                ? '${entry.title} · paused'
                : entry.title,
            accentDot: chosen.contains(entry.feedUrl),
            onTap: () => onTap(entry.feedUrl),
          ),
        ),
    ],
  );
}
