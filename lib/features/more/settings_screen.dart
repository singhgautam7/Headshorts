import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/info_sheet.dart';
import 'package:headshorts/core/widgets/notice.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/sources/opml.dart';
import 'package:headshorts/features/more/more_screen.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// Settings — one page inside the More hub.
///
/// Everything that changes what the app fetches or how it reads. More is the
/// hub above it; this is the page that does the work.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return PushedScreen(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.only(top: HsSpace.x5, bottom: HsSpace.x7),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: HsSpace.x5),
            child: SectionLabel('Appearance'),
          ),
          const SizedBox(height: HsSpace.x3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
            child: SegmentedControl<HsThemeChoice>(
              value: settings.theme,
              options: const {
                HsThemeChoice.amoled: 'AMOLED',
                HsThemeChoice.white: 'White',
                HsThemeChoice.system: 'System',
              },
              onChanged: controller.setTheme,
            ),
          ),
          const SizedBox(height: HsSpace.x3),
          SettingsRow(
            label: 'Blur behind the nav',
            sub: settings.blurBehindNav
                ? 'On — costs battery'
                : 'Off — costs battery, opaque by default',
            trailing: HsToggle(
              value: settings.blurBehindNav,
              onChanged: (v) => controller.setBlurBehindNav(enabled: v),
            ),
          ),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: HsSpace.x5),
            child: SectionLabel('Sources'),
          ),
          const SizedBox(height: HsSpace.x3),
          SettingsRow(
            label: 'Manage subscriptions',
            sub: _subscriptionSummary(ref),
            chevron: true,
            onTap: () => context.go('/sources'),
          ),
          SettingsRow(
            label: 'Add by address',
            sub: 'Any site with a feed, found from its address',
            chevron: true,
            onTap: () => context.push('/sources/add-url'),
          ),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: HsSpace.x5),
            child: SectionLabel('Reading'),
          ),
          const SizedBox(height: HsSpace.x3),
          SettingsRow(
            label: 'Text size',
            value: settings.textSize.label,
            chevron: true,
            onTap: () => context.push('/more/text-size'),
          ),
          SettingsRow(
            label: 'Open links',
            value: settings.linkOpenMode.label,
            onTap: () => controller.setLinkOpenMode(
              settings.linkOpenMode == LinkOpenMode.inApp
                  ? LinkOpenMode.browser
                  : LinkOpenMode.inApp,
            ),
          ),
          SettingsRow(
            label: 'Cap items in a row from one source',
            sub: settings.maxConsecutivePerSource == 0
                ? 'Off — strictly newest first'
                : 'At most ${settings.maxConsecutivePerSource} in a row',
            onTap: () => _cycleFairness(ref, settings.maxConsecutivePerSource),
            divider: false,
            value: settings.maxConsecutivePerSource == 0
                ? 'Off'
                : '${settings.maxConsecutivePerSource}',
          ),
          const SizedBox(height: 26),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: HsSpace.x5),
            child: SectionLabel('Data'),
          ),
          const SizedBox(height: HsSpace.x3),
          SettingsRow(
            label: 'Check for new',
            value: settings.refreshCadence.label,
            onTap: () => _cycleCadence(ref, settings.refreshCadence),
          ),
          SettingsRow(
            label: 'Export OPML',
            sub: 'Back up your subscriptions, or move them to another app',
            chevron: true,
            onTap: () => _exportOpml(context, ref),
          ),
          SettingsRow(
            label: 'Clear cached articles',
            sub: 'Keeps your sources. The next refresh fills it again.',
            divider: false,
            onTap: () => _clearCache(context, ref),
          ),
        ],
      ),
    );
  }

  /// How many sources are subscribed, and how many are paused — the same
  /// state the Sources screen shows, said in one line.
  static String _subscriptionSummary(WidgetRef ref) {
    final sources = ref.watch(sourcesProvider).value ?? const [];
    if (sources.isEmpty) return 'Nothing subscribed yet';
    final enabled = sources.where((s) => s.enabled).length;
    final paused = sources.length - enabled;
    return '$enabled active${paused == 0 ? '' : ' · $paused paused'}';
  }

  /// A short, ordered list rather than a picker: four choices do not earn a
  /// screen of their own.
  Future<void> _cycleCadence(WidgetRef ref, RefreshCadence current) {
    const order = RefreshCadence.values;
    final next = order[(order.indexOf(current) + 1) % order.length];
    return ref.read(settingsProvider.notifier).setRefreshCadence(next);
  }

  /// Deleting cached articles is destructive enough to confirm, and quiet
  /// enough not to celebrate.
  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showHsSheet<bool>(
      context,
      (context) => InfoSheet(
        title: 'Clear cached articles?',
        paragraphs: const [clearCacheExplainer],
        primaryAction: 'Clear the cache',
        onPrimaryAction: () {},
        secondaryAction: 'Keep it',
      ),
    );
    if (confirmed == null) return;
    await ref.read(databaseProvider).clearCache();
    if (context.mounted) showNotice(context, 'Cached articles cleared.');
  }

  /// Fairness, not ranking: nothing is dropped or scored, an over-represented
  /// source is simply moved down a place. Off by default.
  Future<void> _cycleFairness(WidgetRef ref, int current) {
    const steps = [0, 3, 5, 8];
    final next = steps[(steps.indexOf(current) + 1) % steps.length];
    return ref.read(settingsProvider.notifier).setMaxConsecutivePerSource(next);
  }

  Future<void> _exportOpml(BuildContext context, WidgetRef ref) async {
    final sources = await ref.read(sourceRepositoryProvider).all();
    final location = await getSaveLocation(
      suggestedName: 'headshorts.opml',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'OPML', extensions: ['opml']),
      ],
    );
    if (location == null) return;
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(Opml.write(sources))),
      mimeType: 'text/xml',
    ).saveTo(location.path);
  }
}
