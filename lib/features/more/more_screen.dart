import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/app_header.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/features/more/settings_widgets.dart';
import 'package:headshorts/features/more/stats_card.dart';
import 'package:package_info_plus/package_info_plus.dart';

export 'segmented_control.dart';
export 'settings_widgets.dart';

/// More: the stats card leads, then Saved, Manage and About, in Kuber's
/// classic rows. Every setting is behind the Settings row, so this page stays
/// a hub for what the app holds.
class MoreScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return HsScreen(
      title: 'More',
      underHeader: true,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
        children: [
          HeaderPage.gap(),
          const Padding(
            padding: EdgeInsets.only(bottom: HsSpace.x5),
            child: StatsCard(),
          ),
          SettingsGroup(
            label: 'Saved',
            children: [
              SettingsRow(
                icon: Icons.bookmark_border_rounded,
                label: 'Bookmarks',
                sub: 'Articles you kept to read later',
                onTap: () => context.push('/bookmarks'),
              ),
            ],
          ),
          SettingsGroup(
            label: 'Manage',
            children: [
              SettingsRow(
                icon: Icons.swap_vert_rounded,
                label: 'Data',
                sub: 'Export, import and clear',
                onTap: () => context.push('/more/data'),
              ),
              SettingsRow(
                icon: Icons.key_outlined,
                label: 'Permissions',
                sub: 'What HeadShorts asks for',
                onTap: () => context.push('/more/permissions'),
              ),
            ],
          ),
          SettingsGroup(
            label: 'About HeadShorts',
            children: [
              SettingsRow(
                icon: Icons.tune_rounded,
                label: 'Settings',
                sub: 'Look, reading, search, haptics',
                onTap: () => context.push('/more/settings'),
              ),
              SettingsRow(
                icon: Icons.mail_outline_rounded,
                label: 'Contact us',
                sub: 'singhgautam.dev@gmail.com',
                onTap: () => context.push('/more/contact'),
              ),
              SettingsRow(
                icon: Icons.shield_outlined,
                label: 'Privacy',
                sub: 'Everything stays on your phone',
                onTap: () => context.push('/more/privacy'),
              ),
              const _AboutRow(),
            ],
          ),
          const VersionLine(),
          const Padding(
            padding: EdgeInsets.only(
              top: HsSpace.x1,
              bottom: HsSpace.navClearance,
            ),
            child: MadeInIndia(),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(
      packageInfoProvider.select((v) => v.value?.version),
    );
    return SettingsRow(
      icon: Icons.info_outline_rounded,
      label: 'About',
      sub: version == null ? 'Why HeadShorts exists' : 'Version $version',
      onTap: () => context.push('/more/about'),
    );
  }
}

/// The installed package's version and build, resolved once and cached: a
/// `FutureBuilder` in `build` would re-read the platform on every rebuild.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// `HeadShorts 0.1.0 · build 1` — never hardcoded.
class VersionLine extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    return Text(
      info == null
          ? 'HeadShorts'
          : 'HeadShorts ${info.version} · build ${info.buildNumber}',
      textAlign: TextAlign.center,
      style: HsType.note.copyWith(color: context.hs.textMuted),
    );
  }
}

/// Made with love in India. Pinned at the foot of the hub and set between
/// the maker's note and the rest of About: muted, centred, and the only
/// decoration in the app that is not doing a job.
class MadeInIndia extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Text(
    'Made with \u2764\ufe0f in India',
    textAlign: TextAlign.center,
    style: HsType.note.copyWith(color: context.hs.textMuted),
  );
}
