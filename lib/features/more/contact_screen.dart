import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/open_in_web.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/notice.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/more/settings_widgets.dart';

/// Contact screen for Headshorts.
///
/// Provides direct, prominent, and verifiable in-app contact channels
/// complying with Google Play's News & Magazines policy requirements:
/// - Official developer email with one-tap `mailto:` launch and copy action.
/// - Direct link to the Headshorts official website contact page.
class ContactScreen extends StatelessWidget {
  const new({super.key});

  static const developerEmail = 'singhgautam.dev@gmail.com';
  static const websiteContactUrl = 'https://headshorts.pages.dev/contact';
  static const websiteUrl = 'https://headshorts.pages.dev';

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return SettingsScaffold(
      title: 'Contact us',
      children: [
        Text(
          'Get in touch with the developer.',
          style: HsType.screenTitle.copyWith(
            fontSize: 26,
            height: 1.2,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Have questions, feedback, publisher attribution inquiries, or bug reports? '
          'Reach out directly via email or through the Headshorts website.',
          style: HsType.bodySans.copyWith(
            color: palette.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // Primary email card
        _EmailCard(
          email: developerEmail,
          onEmailTap: () => unawaited(openInWeb('mailto:$developerEmail')),
          onCopyTap: () async {
            await Clipboard.setData(
              const ClipboardData(text: developerEmail),
            );
            if (context.mounted) {
              unawaited(HapticFeedback.selectionClick());
              showNotice(context, 'Email copied to clipboard');
            }
          },
        ),

        const SizedBox(height: 24),

        // Web & Support Links
        SettingsGroup(
          label: 'Website & online support',
          children: [
            SettingsRow(
              icon: Icons.open_in_browser_rounded,
              label: 'Website contact page',
              sub: 'headshorts.pages.dev/contact',
              onTap: () => openInWeb(
                websiteContactUrl,
                mode: LinkOpenMode.browser,
              ),
            ),
            SettingsRow(
              icon: Icons.language_rounded,
              label: 'Headshorts website',
              sub: 'headshorts.pages.dev',
              onTap: () => openInWeb(
                websiteUrl,
                mode: LinkOpenMode.browser,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Information card
        const _InfoDetailsCard(),

        const SizedBox(height: 20),
        Text(
          'Headshorts is local-first. We do not run user accounts or remote tracking servers.',
          textAlign: TextAlign.center,
          style: HsType.note.copyWith(color: palette.textMuted),
        ),
      ],
    );
  }
}

class _EmailCard extends StatelessWidget {
  const new({
    required this.email,
    required this.onEmailTap,
    required this.onCopyTap,
  });

  final String email;
  final VoidCallback onEmailTap;
  final VoidCallback onCopyTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: HsRadius.cardBorder,
        border: Border.all(color: palette.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OFFICIAL DEVELOPER EMAIL',
            style: HsType.lingerLabel.copyWith(
              fontSize: 11,
              letterSpacing: 1.2,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Direct Email Support',
            style: HsType.row.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'For app feedback, store compliance verification, feed issues, or questions:',
            style: HsType.rowSub.copyWith(
              height: 1.4,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: HsButton(
                  email,
                  onPressed: onEmailTap,
                  height: HsSize.buttonSmall,
                ),
              ),
              const SizedBox(width: HsSpace.x2),
              HsIconButton(
                icon: Icons.copy_rounded,
                onPressed: onCopyTap,
                semanticLabel: 'Copy email address',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoDetailsCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: HsRadius.cardBorder,
        border: Border.all(color: palette.stroke),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(label: 'Developer', value: 'Gautam Rajeev Singh'),
          SizedBox(height: 10),
          _DetailRow(label: 'Application', value: 'Headshorts (com.grs.news)'),
          SizedBox(height: 10),
          _DetailRow(label: 'Location', value: 'India 🇮🇳'),
          SizedBox(height: 10),
          _DetailRow(label: 'Response Time', value: 'Typically 24–48 hours'),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label.toUpperCase(),
            style: HsType.lingerLabel.copyWith(
              fontSize: 10,
              letterSpacing: 0.8,
              color: palette.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: HsType.rowSub.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
