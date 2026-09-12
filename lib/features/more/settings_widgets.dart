import 'package:flutter/material.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/screen.dart';

/// A titled group of rows, drawn as one rounded container with hairlines
/// between them, matching Perch design.
class SettingsGroup extends StatelessWidget {
  const new({required this.label, required this.children, super.key});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Padding(
      padding: const EdgeInsets.only(bottom: HsSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label.toUpperCase(),
              style: HsType.lingerLabel.copyWith(
                fontSize: 11,
                letterSpacing: 1.2,
                color: palette.textMuted,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: HsRadius.cardBorder,
              border: Border.all(color: palette.stroke),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  if (i > 0) Divider(color: palette.divider, height: 1),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row: an icon, a label, optional subtitle, value on the right, and
/// a chevron or custom trailing control.
class SettingsRow extends StatelessWidget {
  const new({
    required this.label,
    this.icon,
    this.sub,
    this.value,
    this.onTap,
    this.trailing,
    this.chevron = true,
    this.divider = true,
    super.key,
  });

  final IconData? icon;
  final String label;
  final String? sub;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool chevron;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: <Widget>[
            if (icon != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Icon(icon, size: 20, color: palette.textSecondary),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: HsType.row.copyWith(color: palette.textPrimary),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub!,
                        style: HsType.rowSub.copyWith(color: palette.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else ...<Widget>[
              if (value != null)
                Text(
                  value!,
                  style: HsType.rowValue.copyWith(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              if (onTap != null && chevron) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: palette.textMuted,
                ),
              ],
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      child: InkWell(
        onTap: onTap,
        splashColor: palette.textPrimary.withValues(alpha: 0.06),
        highlightColor: palette.textPrimary.withValues(alpha: 0.04),
        child: content,
      ),
    );
  }
}

/// A pushed settings page: the shared back-button header, then a list.
class SettingsScaffold extends StatelessWidget {
  const new({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PushedScreen(
    title: title,
    divider: false,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(
        HsSpace.x4,
        HsSpace.x3,
        HsSpace.x4,
        HsSpace.x7,
      ),
      children: children,
    ),
  );
}
