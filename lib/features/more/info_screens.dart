import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/features/more/settings_widgets.dart';

/// Prose screens: About is short on purpose.
class ProseScreen extends StatelessWidget {
  const new({required this.title, required this.paragraphs, super.key});

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return PushedScreen(
      title: title,
      onBack: () => context.pop(),
      child: ListView(
        padding: const EdgeInsets.all(HsSpace.x5),
        children: [
          for (final paragraph in paragraphs) ...[
            Text(
              paragraph,
              style: HsType.bodySerif.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: HsSpace.x4),
          ],
        ],
      ),
    );
  }
}

/// Rich Privacy screen ported from Perch: leads with the brief statement,
/// then verifiable claims with success indicators.
class PrivacyScreen extends StatelessWidget {
  const new({super.key});

  static const List<(String, String)> _claims = <(String, String)>[
    ('No account, ever', 'There is nothing to sign in to.'),
    ('No analytics, no ads', 'No third-party tracking SDKs are bundled.'),
    (
      'Direct to publisher',
      'Feeds and article pages are fetched straight from publishers. No HeadShorts proxy or server exists.',
    ),
    (
      'Device-only storage',
      'Your subscriptions, read history, and cached stories stay on your device and are wiped upon uninstall.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return SettingsScaffold(
      title: 'Privacy',
      children: <Widget>[
        Text(
          'HeadShorts stores everything on your device.',
          style: HsType.screenTitle.copyWith(
            fontSize: 26,
            height: 1.2,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Feeds and articles are fetched directly from the sources you choose. '
          'There is no HeadShorts server, so nothing you read is ever tracked or sent anywhere.',
          style: HsType.bodySans.copyWith(
            color: palette.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        for (final (String, String) claim in _claims) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: HsRadius.cardBorder,
              border: Border.all(color: palette.stroke),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        claim.$1,
                        style: HsType.row.copyWith(
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        claim.$2,
                        style: HsType.rowSub.copyWith(
                          height: 1.4,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

const privacyScreen = PrivacyScreen();
