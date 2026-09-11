import 'package:flutter/material.dart' show InputDecoration, TextField;
import 'package:flutter/services.dart' show TextInputAction, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/feed/feed_discovery.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// Add a source by pasting a *site*, not a feed.
///
/// The address is fetched, its `<link rel="alternate">` declarations are read,
/// and the feeds behind it are offered with what they actually contain.
class AddSourceScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends ConsumerState<AddSourceScreen> {
  final _input = TextEditingController();
  List<DiscoveredFeed> _found = const [];
  Set<String> _chosen = {};
  String _category = 'India';
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _searching = true;
      _searched = true;
      _found = const [];
      _chosen = {};
    });
    final found = await ref.read(feedDiscoveryProvider).discover(text);
    if (!mounted) return;
    setState(() {
      _found = found;
      _chosen = found.isEmpty ? {} : {found.first.url};
      _searching = false;
    });
  }

  Future<void> _add() async {
    final repository = ref.read(sourceRepositoryProvider);
    for (final feed in _found.where((f) => _chosen.contains(f.url))) {
      await repository.add(
        title: feed.title,
        feedUrl: feed.url,
        siteUrl: feed.siteUrl,
        category: _category,
        accent: SourceAccent.fromKey(feed.url),
      );
    }
    if (!mounted) return;
    unawaitedRefresh(ref);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final categories = (ref.watch(categoriesProvider).value ?? const ['Top'])
        .where((c) => c != 'Top')
        .toList();
    final options = {
      ...categories,
      'India',
      'World',
      'Technology',
      _category,
    }.toList();

    return PushedScreen(
      title: 'Add a source',
      onBack: () => context.pop(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          HsSpace.x5,
          22,
          HsSpace.x5,
          HsSpace.x5,
        ),
        children: [
          Text(
            'Paste the site address. We will find the feed.',
            style: HsType.note.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: HsSpace.x4),
          _UrlField(controller: _input, onSubmitted: (_) => _search()),
          const SizedBox(height: HsSpace.x3),
          HsButton(
            _searching ? 'Looking…' : 'Find the feed',
            onPressed: _searching ? null : _search,
            kind: HsButtonKind.secondary,
          ),
          const SizedBox(height: HsSpace.x5),
          if (_searched && !_searching && _found.isEmpty)
            Text(
              'No feed found behind that address. Some publishers only list '
              'theirs on the page itself — try pasting the feed address '
              'directly.',
              style: HsType.note.copyWith(color: palette.textSecondary),
            ),
          if (_found.isNotEmpty) ...[
            SectionLabel(
              _found.length == 1
                  ? 'One feed found'
                  : '${_found.length} feeds found',
            ),
            const SizedBox(height: 10),
            for (final feed in _found) ...[
              _FeedOption(
                feed: feed,
                selected: _chosen.contains(feed.url),
                onTap: () => setState(() {
                  if (!_chosen.remove(feed.url)) _chosen.add(feed.url);
                }),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: HsSpace.x2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Category',
                    style: HsType.statLabel.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                Wrap(
                  spacing: HsSpace.x2,
                  children: [
                    for (final option in options)
                      HsChip(
                        option,
                        selected: option == _category,
                        onTap: () => setState(() => _category = option),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: HsSpace.x5),
            HsButton(
              _chosen.length == 1
                  ? 'Add 1 feed'
                  : 'Add ${_chosen.length} feeds',
              onPressed: _chosen.isEmpty ? null : _add,
            ),
            const SizedBox(height: HsSpace.x3),
            Center(
              child: Pressable(
                onTap: () => context.pushReplacement('/sources/opml'),
                child: Text(
                  'Or import an OPML file',
                  style: HsType.timestamp.copyWith(color: palette.textMuted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void unawaitedRefresh(WidgetRef ref) {
  ref.read(refreshProvider.notifier).refresh().ignore();
}

/// A plain text field in the app's own dress — Material's decoration is
/// stripped entirely so the container comes from the token set.
class _UrlField extends StatelessWidget {
  const new({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Container(
      height: HsSize.buttonLarge,
      padding: const EdgeInsets.symmetric(horizontal: HsSpace.x4),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: palette.stroke),
        borderRadius: HsRadius.buttonBorder,
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go,
        onSubmitted: onSubmitted,
        cursorColor: palette.textPrimary,
        style: HsType.buttonLarge.copyWith(color: palette.textPrimary),
        decoration: InputDecoration.collapsed(
          hintText: 'thehindu.com',
          hintStyle: HsType.buttonLarge.copyWith(color: palette.textMuted),
        ),
      ),
    );
  }
}

class _FeedOption extends StatelessWidget {
  const new({required this.feed, required this.selected, required this.onTap});

  final DiscoveredFeed feed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = SourceAccent.fromKey(feed.url)
        .resolve(isDark: palette.isDark);

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accentWash(accent, palette) : null,
          border: Border.all(color: selected ? accent : palette.divider),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: selected ? 1 : 0.5),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feed.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HsType.statTitle.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: HsSpace.x1),
                  Text(
                    '${feed.hasFullContent ? 'full articles' : 'summaries only'}'
                    ' · about ${feed.itemsPerDay} a day',
                    style: HsType.timestamp.copyWith(color: palette.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : null,
                border: selected
                    ? null
                    : Border.all(
                        color: palette.stroke,
                        width: HsSize.glyphStroke,
                      ),
              ),
              child: selected ? HsGlyph.tick(palette.surface) : null,
            ),
          ],
        ),
      ),
    );
  }
}
