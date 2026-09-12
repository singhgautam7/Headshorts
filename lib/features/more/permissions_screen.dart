import 'package:flutter/material.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/features/more/settings_widgets.dart';

/// What HeadShorts asks the OS for, and what it deliberately does not.
class PermissionsScreen extends StatelessWidget {
  const new({super.key});

  static const List<(IconData, String, String, bool)>
  _rows = <(IconData, String, String, bool)>[
    (
      Icons.wifi_rounded,
      'Internet',
      'Used only to fetch your subscribed feeds and article previews directly from publishers.',
      true,
    ),
    (
      Icons.ios_share_rounded,
      'Share sheet',
      'Lets other apps receive an article link. No permission prompt needed.',
      true,
    ),
    (
      Icons.photo_library_outlined,
      'Photos and files',
      'Not requested. OPML backup exports write through the standard system dialog.',
      false,
    ),
    (
      Icons.notifications_none_rounded,
      'Notifications',
      'Not requested. HeadShorts has no background alerts, badges, or streaks.',
      false,
    ),
    (
      Icons.location_on_outlined,
      'Location, contacts, camera',
      'Not requested, and never will be.',
      false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return SettingsScaffold(
      title: 'Permissions',
      children: <Widget>[
        Text(
          'HeadShorts declares minimal permissions. The rest of this list is here '
          'so you can verify what it deliberately does not ask for.',
          style: HsType.bodySans.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: HsSpace.x5),
        for (final (IconData, String, String, bool) row in _rows) ...<Widget>[
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
                    row.$1,
                    size: 20,
                    color: row.$4 ? palette.textPrimary : palette.textMuted,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            row.$2,
                            style: HsType.row.copyWith(
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: row.$4
                                  ? palette.textPrimary.withValues(alpha: 0.1)
                                  : palette.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              row.$4 ? 'USED' : 'NOT USED',
                              style: HsType.lingerLabel.copyWith(
                                fontSize: 9.5,
                                letterSpacing: 0.8,
                                color: row.$4
                                    ? palette.textPrimary
                                    : palette.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.$3,
                        style: HsType.rowSub.copyWith(
                          height: 1.45,
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
