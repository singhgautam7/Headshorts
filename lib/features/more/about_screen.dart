import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/open_in_web.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/more/more_screen.dart';

/// About HeadShorts.
///
/// Kuber's arrangement in HeadShorts' dress: a note from the maker, four
/// tiles for what the app stands for, what it is in a paragraph, the version,
/// and the ways out to the developer. Every surface is the settings card;
/// nothing here has a colour of its own.
class AboutScreen extends StatelessWidget {
  const new({super.key});

  static const portfolio = 'https://singhgautam.com';
  static const moreApps =
      'https://play.google.com/store/apps/developer?id=Gautam+Rajeev+Singh';
  static const listing =
      'https://play.google.com/store/apps/details?id=com.grs.news';

  @override
  Widget build(BuildContext context) => const SettingsScaffold(
    title: 'About HeadShorts',
    children: [
      _Letter(),
      SizedBox(height: HsSpace.x5),
      MadeInIndia(),
      SizedBox(height: HsSpace.x5),
      _Pillars(),
      SizedBox(height: HsSpace.x6),
      _WhatItIs(),
      SizedBox(height: HsSpace.x6),
      _Version(),
      SizedBox(height: HsSpace.x6),
      SettingsGroup(
        label: 'The developer',
        children: [
          _Link(
            icon: Icons.person_outline_rounded,
            label: 'Gautam Rajeev Singh',
            sub: 'singhgautam.com',
            url: AboutScreen.portfolio,
          ),
          _Link(
            icon: Icons.apps_rounded,
            label: 'More apps',
            sub: 'Everything else on Google Play',
            url: AboutScreen.moreApps,
          ),
          _Link(
            icon: Icons.star_outline_rounded,
            label: 'Rate HeadShorts',
            sub: 'Helps others find it',
            url: AboutScreen.listing,
          ),
        ],
      ),
      _Foot(),
    ],
  );
}

/// The eyebrow above a section, in the settings group's dress.
class _Eyebrow extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: HsType.lingerLabel.copyWith(
      fontSize: 11,
      letterSpacing: 1.2,
      color: context.hs.textMuted,
    ),
  );
}

/// The card every block sits on.
class _Card extends StatelessWidget {
  const new({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: HsRadius.cardBorder,
        border: Border.all(color: palette.stroke),
      ),
      child: child,
    );
  }
}

class _Letter extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final body = HsType.bodySerif.copyWith(
      color: palette.textPrimary,
      height: 1.7,
    );
    return _Card(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow('A note from the maker'),
          const SizedBox(height: 12),
          Text(
            'A briefing that ends.',
            style: HsType.screenTitle.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: 18),
          Text(
            'Hey there,\n\n'
            'Thank you for installing HeadShorts.\n\n'
            'Most news apps are built to keep you scrolling. They rank, they '
            'recommend, they refill the list the moment you reach the end, '
            'and somewhere in there the news stops being the point.\n\n'
            'I wanted the opposite: the feeds I chose, in the order they were '
            'published, and a bottom I could actually reach. No counts to '
            'fall behind on, no red dots, nothing that runs on its own.\n\n'
            'So I built one. Read it, reach the end, and get on with your '
            'day.',
            style: body,
          ),
          const SizedBox(height: 22),
          Text(
            'Gautam Rajeev Singh',
            style: HsType.row.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Pressable(
            onTap: () =>
                openInWeb(AboutScreen.portfolio, mode: LinkOpenMode.browser),
            semanticLabel: 'Open singhgautam.com',
            child: Text(
              'singhgautam.com',
              style: HsType.rowSub.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the app stands for, as four tiles.
class _Pillars extends StatelessWidget {
  const new();

  static const _tiles = [
    (
      Icons.horizontal_rule_rounded,
      'Finite',
      'Every list ends. When you reach the bottom, that is the news.',
    ),
    (
      Icons.schedule_rounded,
      'Chronological',
      'Newest first, always. Nothing is ranked or recommended.',
    ),
    (
      Icons.lock_outline_rounded,
      'Private',
      'No account, no server, no analytics. Everything stays on the phone.',
    ),
    (
      Icons.tune_rounded,
      'Yours',
      'Only the publishers you picked. Add any feed, mute any firehose.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: _Eyebrow('What it stands for'),
        ),
        for (var row = 0; row < _tiles.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = row; i < row + 2; i++) ...[
                  if (i > row) const SizedBox(width: 10),
                  Expanded(child: _Tile(_tiles[i], palette: palette)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One tile: the glyph, then the title and line at the foot. The row is as
/// tall as the longest line needs, so nothing is clipped at any text size.
class _Tile extends StatelessWidget {
  const new(this.tile, {required this.palette});

  final (IconData, String, String) tile;
  final HsPalette palette;

  @override
  Widget build(BuildContext context) {
    final (icon, title, line) = tile;
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: palette.textSecondary),
          const SizedBox(height: 22),
          Text(
            title,
            style: HsType.row.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            line,
            style: HsType.rowSub.copyWith(
              height: 1.4,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatItIs extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow('What it is'),
          const SizedBox(height: 12),
          Text(
            'An RSS reader with a strong opinion. HeadShorts fetches the '
            'feeds you subscribe to, merges them newest first, and shows '
            'each story as a headline, then as a card to linger on, then as '
            "the full article, extracted on the phone from the publisher's "
            'own page.',
            style: HsType.bodySans.copyWith(
              height: 1.6,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'There is deliberately no like, save count, reaction, streak, '
            'goal, badge or red dot anywhere in the app.',
            style: HsType.bodySans.copyWith(
              height: 1.6,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Version extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final info = ref.watch(packageInfoProvider).value;
    return _Card(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Version',
              style: HsType.row.copyWith(color: palette.textPrimary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: palette.surfaceVariant,
              borderRadius: HsRadius.chipBorder,
              border: Border.all(color: palette.stroke),
            ),
            child: Text(
              info == null ? '…' : '${info.version} (${info.buildNumber})',
              style: HsType.buttonSmall.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row in the developer group that leaves the app.
class _Link extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.sub,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String sub;
  final String url;

  @override
  Widget build(BuildContext context) => SettingsRow(
    icon: icon,
    label: label,
    sub: sub,
    divider: false,
    onTap: () => openInWeb(url, mode: LinkOpenMode.browser),
  );
}

class _Foot extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: HsSpace.x2),
    child: Text(
      'No account. No server. Nothing leaves the phone.',
      textAlign: TextAlign.center,
      style: HsType.note.copyWith(color: context.hs.textMuted),
    ),
  );
}
