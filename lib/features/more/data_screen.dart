import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/widgets/info_sheet.dart';
import 'package:headshorts/core/widgets/notice.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/data/sources/opml.dart';
import 'package:headshorts/features/more/settings_widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Data is where you act on your library. Privacy answers "what does this
/// app do with my data"; this page answers "how do I move it".
class DataScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsScaffold(
    title: 'Data',
    children: [
      SettingsGroup(
        label: 'Subscriptions',
        children: [
          SettingsRow(
            icon: Icons.ios_share_rounded,
            label: 'Export OPML',
            sub: 'Back up your subscriptions, or move to another app',
            onTap: () => _exportOpml(context, ref),
          ),
          SettingsRow(
            icon: Icons.file_download_outlined,
            label: 'Import OPML',
            sub: 'Folders become categories',
            onTap: () => context.push('/sources/opml'),
          ),
        ],
      ),
      SettingsGroup(
        label: 'Cache',
        children: [
          SettingsRow(
            icon: Icons.delete_outline_rounded,
            label: 'Clear cached articles',
            sub: 'Keeps your sources. The next refresh fills it again.',
            onTap: () => _clearCache(context, ref),
          ),
        ],
      ),
    ],
  );

  /// Hands the file to the system share sheet. HeadShorts asks for no storage
  /// permission, and Android's save-file dialog is not available to it, so
  /// the reader picks the destination there — Drive, Files, another app.
  static Future<void> _exportOpml(BuildContext context, WidgetRef ref) async {
    final sources = await ref.read(sourceRepositoryProvider).all();
    if (sources.isEmpty) {
      if (context.mounted) showNotice(context, 'Nothing subscribed yet.');
      return;
    }
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final name = 'headshorts-$stamp.opml';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(Opml.write(sources))),
            mimeType: 'text/xml',
            name: name,
          ),
        ],
        fileNameOverrides: [name],
      ),
    );
  }

  /// Deleting cached articles is destructive enough to confirm, and quiet
  /// enough not to celebrate.
  static Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
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
}

const clearCacheExplainer =
    'Every article currently stored on the device is removed, along with what '
    'you have read. Your sources and settings stay exactly as they are, and '
    'the next refresh fills the briefing again.';
