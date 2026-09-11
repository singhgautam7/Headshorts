import 'dart:async';

import 'package:flutter/material.dart' show InputDecoration, TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/features/more/more_screen.dart';

/// The API key lives in the Android keystore and is never read by anything
/// but the provider the reader chooses.
const _keyStorage = FlutterSecureStorage();

const _keyName = 'ai.apiKey';

/// AI summaries — the entry point and the key screen only.
///
/// The summariser itself is a later phase and is deliberately not built: this
/// screen stores a key securely and states plainly that nothing runs yet.
class AiSummariesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AiSummariesScreen> createState() => _AiSummariesScreenState();
}

class _AiSummariesScreenState extends ConsumerState<AiSummariesScreen> {
  final _key = TextEditingController();
  bool _revealed = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final stored = await _keyStorage.read(key: _keyName);
    if (!mounted || stored == null) return;
    setState(() => _key.text = stored);
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _key.text.trim();
    if (value.isEmpty) {
      await _keyStorage.delete(key: _keyName);
    } else {
      await _keyStorage.write(key: _keyName, value: value);
    }
    if (!mounted) return;
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return PushedScreen(
      title: 'AI summaries',
      onBack: () => context.pop(),
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HsSpace.x2,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: palette.stroke),
          borderRadius: HsRadius.chipBorder,
        ),
        child: Text(
          'LATER PHASE',
          style: HsType.sectionLabel.copyWith(
            fontSize: 10,
            color: palette.textMuted,
          ),
        ),
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(
          HsSpace.x5,
          HsSpace.x4,
          HsSpace.x5,
          26,
        ),
        child: HsButton(_saved ? 'Key saved' : 'Save key', onPressed: _save),
      ),
      child: ListView(
        padding: const EdgeInsets.all(HsSpace.x5),
        children: [
          Text(
            'Summaries run on your own API key, stored in the device keystore '
            'and never sent anywhere but the provider you choose. Off until '
            'you add one.',
            style: HsType.row.copyWith(
              height: 1.7,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Provider'),
          const SizedBox(height: 10),
          SegmentedControl<String>(
            value: settings.aiProvider,
            options: const {
              'Anthropic': 'Anthropic',
              'OpenAI': 'OpenAI',
              'Local': 'Local',
            },
            onChanged: controller.setAiProvider,
          ),
          const SizedBox(height: 22),
          const SectionLabel('API key'),
          const SizedBox(height: 10),
          Container(
            height: HsSize.buttonLarge,
            padding: const EdgeInsets.symmetric(horizontal: HsSpace.x4),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.stroke),
              borderRadius: HsRadius.buttonBorder,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _key,
                    obscureText: !_revealed,
                    onChanged: (_) => setState(() => _saved = false),
                    cursorColor: palette.textPrimary,
                    style: HsType.buttonLarge.copyWith(
                      color: palette.textPrimary,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: '••••••••••••••••',
                      hintStyle: HsType.buttonLarge.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ),
                Pressable(
                  onTap: () => setState(() => _revealed = !_revealed),
                  child: Text(
                    _revealed ? 'Hide' : 'Show',
                    style: HsType.buttonSmall.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Kept in the Android keystore. Cleared if you uninstall.',
            style: HsType.noteTight.copyWith(color: palette.textMuted),
          ),
          const SizedBox(height: 22),
          const HsDivider(),
          const SizedBox(height: 22),
          SettingsRow(
            label: 'Summarise on request only',
            sub: 'Never in the background, never automatically',
            divider: false,
            trailing: HsToggle(
              value: settings.aiOnRequestOnly,
              onChanged: (v) => controller.setAiOnRequestOnly(enabled: v),
            ),
          ),
          Opacity(
            opacity: 0.5,
            child: SettingsRow(
              label: 'Only where full text exists',
              sub: 'Summarising a summary is not useful',
              divider: false,
              trailing: HsToggle(
                value: settings.aiFullTextOnly,
                onChanged: (v) => controller.setAiFullTextOnly(enabled: v),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Nothing is summarised yet. This screen stores the key so the '
            'feature can be switched on in a later release.',
            style: HsType.noteTight.copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}
