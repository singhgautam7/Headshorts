import 'package:flutter/material.dart';
import 'package:headshorts/core/motion/pressable.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/app_header.dart';
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
            padding: const EdgeInsets.only(bottom: HsSpace.x2),
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

/// One row, Kuber's classic arrangement: a 40 dp tile, the title with its
/// description (or the current value of a one-of-N setting) always directly
/// beneath it, and a chevron. At least 72 dp tall, and taller as text grows.
///
/// [value] is the current value of a setting and takes the description's
/// place; it never sits on the right.
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

  /// The least a row is tall.
  static const minHeight = 72.0;

  /// The icon tile.
  static const tile = 40.0;

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
    final subtitle = value ?? sub;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HsSpace.x4,
        vertical: HsSpace.x2,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight - 16),
        child: Row(
          children: <Widget>[
            if (icon != null) ...[
              Container(
                width: tile,
                height: tile,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.primaryContainer,
                  borderRadius: BorderRadius.circular(HsRadius.squircle),
                ),
                child: Icon(icon, size: 22, color: palette.onPrimaryContainer),
              ),
              const SizedBox(width: HsSpace.x4),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: HsType.row.copyWith(color: palette.textPrimary),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: HsType.rowValue.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: HsSpace.x3),
              trailing!,
            ] else if (onTap != null && chevron) ...[
              const SizedBox(width: HsSpace.x3),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: palette.textMuted,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return content;
    return Pressable(
      kind: PressKind.row,
      onTap: onTap,
      semanticLabel: subtitle == null ? label : '$label, $subtitle',
      child: ExcludeSemantics(child: content),
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
    child: ListView(
      padding: pushedListPadding,
      children: [HeaderPage.gap(), ...children],
    ),
  );
}
