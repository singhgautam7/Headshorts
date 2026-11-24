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
import 'package:headshorts/core/widgets/app_header.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/info_button.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/feed/feed_discovery.dart';
import 'package:headshorts/features/sources/opml_explainer.dart';
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
  String _category = defaultCategories.first;
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
      title: 'Add by URL',
      form: true,
      onBack: () => context.pop(),
      child: StickySubmit(
        label: _chosen.length > 1 ? 'Add ${_chosen.length} feeds' : 'Add feed',
        onPressed: _chosen.isEmpty ? null : _add,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            HsSpace.x5,
            HsSpace.x3,
            HsSpace.x5,
            HsSpace.x5,
          ),
          children: [
            HeaderPage.gap(),
            Text(
              'Paste the site address. We will find the feed.',
              style: HsType.note.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: HsSpace.x4),
            _UrlField(controller: _input, onSubmitted: (_) => _search()),
            const SizedBox(height: HsSpace.x3),
            HsButton(
              'Find the feed',
              onPressed: _search,
              loading: _searching,
              kind: HsButtonKind.secondary,
            ),
            const SizedBox(height: HsSpace.x5),
            // Always reachable: a reader who came here to bulk-import should
            // not have to search for a site first.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Pressable(
                    kind: PressKind.chip,
                    morphCorners: false,
                    onTap: () => context.pushReplacement('/sources/opml'),
                    semanticLabel: 'Import an OPML file',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: HsSize.tapTarget,
                      ),
                      child: Center(
                        child: Text(
                          'Or import an OPML file',
                          textAlign: TextAlign.center,
                          style: HsType.timestamp.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                InfoButton(
                  semanticLabel: 'About OPML',
                  onTap: () => showOpmlExplainer(
                    context,
                    onImport: () => context.pushReplacement('/sources/opml'),
                  ),
                ),
              ],
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
                    runSpacing: HsChip.runSpacing(HsSpace.x2),
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
            ],
          ],
        ),
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
      kind: PressKind.row,
      haptic: true,
      onTap: onTap,
      selected: selected,
      semanticLabel: feed.title,
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

/// A form's submit, pinned below the scroll area (Part L12): one full-width
/// primary button inside the page margins and nothing else. No bar, divider
/// or shadow; only a short fade over the last of the list so content does not
/// stop at a hard edge. It rides above the keyboard: the system inset (kept by
/// the screen's own safe area) plus 16 when closed, 16 above the keyboard
/// when it is open.
class StickySubmit extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// The scrolling form. Give it enough bottom padding to clear the fade.
  final Widget child;

  /// The fade over the end of the list.
  static const fade = 24.0;

  @override
  Widget build(BuildContext context) {
    final ground = context.hs.background;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: child),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: fade,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [ground.withValues(alpha: 0), ground],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            HsSpace.x5,
            0,
            HsSpace.x5,
            HsSpace.x4 + keyboard,
          ),
          child: HsButton(label, onPressed: onPressed),
        ),
      ],
    );
  }
}
