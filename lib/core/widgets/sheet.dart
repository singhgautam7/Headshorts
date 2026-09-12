import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';

/// A bottom sheet in the app's own dress: a 26dp top radius, the surface
/// tone, a hairline top edge and a grab handle.
class HsSheet extends StatelessWidget {
  const new({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final sub = subtitle;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: HsRadius.sheetTop,
        border: Border(top: BorderSide(color: palette.divider)),
      ),
      padding: EdgeInsets.only(
        left: HsSpace.x5,
        right: HsSpace.x5,
        top: 20,
        bottom: 28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: HsType.stepTitle.copyWith(
              fontSize: 20,
              color: palette.textPrimary,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub,
              style: HsType.note.copyWith(color: palette.textSecondary),
            ),
          ],
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

/// Presents [builder] over a scrim, at the app's own corner radius.
Future<T?> showHsSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: const Color(0x00000000),
      barrierColor: context.hs.scrim,
      elevation: 0,
      isScrollControlled: true,
      // Above the shell, so the floating nav pill does not sit on top of the
      // sheet's own actions.
      useRootNavigator: true,
      builder: builder,
    );

/// One choice in [showOptionSheet].
class SheetOption<T> {
  const new({required this.value, required this.label, this.description});

  final T value;
  final String label;
  final String? description;
}

/// A single-select list in the shared sheet: the option, what it means, and
/// a tick on the one in effect. Every one-of-N setting goes through here.
///
/// Resolves to the pick, or null when the sheet is dismissed.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetOption<T>> options,
  required T selected,
  String? description,
}) => showHsSheet<T>(
  context,
  (sheetContext) => HsSheet(
    title: title,
    subtitle: description,
    children: [
      for (final option in options)
        _OptionRow<T>(
          option: option,
          selected: option.value == selected,
          onTap: () => Navigator.of(sheetContext).pop(option.value),
        ),
    ],
  ),
);

class _OptionRow<T> extends StatelessWidget {
  const new({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SheetOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final description = option.description;
    return Padding(
      padding: const EdgeInsets.only(bottom: HsSpace.x2),
      child: Semantics(
        button: true,
        selected: selected,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: HsMotion.micro,
            curve: HsMotion.microCurve,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: HsSpace.x3,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? palette.primaryContainer
                  : palette.surfaceVariant,
              borderRadius: HsRadius.cardBorder,
              border: Border.all(
                color: selected ? palette.primary : palette.surfaceVariant,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: HsType.row.copyWith(
                          color: selected
                              ? palette.onPrimaryContainer
                              : palette.textPrimary,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: HsType.rowSub.copyWith(
                            color: selected
                                ? palette.onPrimaryContainer
                                : palette.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: palette.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: HsGlyph.tick(palette.onPrimary)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
