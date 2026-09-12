import 'package:flutter/material.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';

/// One row of a [showHsMenu].
class HsMenuEntry<T> {
  const new({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// The anchored overflow menu: a rounded card of rows, hanging off the
/// control that raised it. Its dress comes from `popupMenuTheme`, so it is the
/// same object in both themes and on every screen.
///
/// The menu opens below [anchorContext], or above it when [above] is set —
/// the Reader's floating buttons sit at the foot of the screen.
Future<T?> showHsMenu<T>({
  required BuildContext context,
  required BuildContext anchorContext,
  required List<HsMenuEntry<T>> entries,
  bool above = false,
  double minWidth = 200,
}) {
  final overlay =
      Navigator.of(
            context,
            rootNavigator: true,
          ).overlay?.context.findRenderObject()
          as RenderBox?;
  final anchor = anchorContext.findRenderObject() as RenderBox?;
  if (overlay == null || anchor == null) return Future.value();

  final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
  final right = overlay.size.width - topLeft.dx - anchor.size.width;
  // `showMenu` places the menu's top edge at `top`, so opening above the
  // anchor means estimating the menu's height from its row count; anything
  // off by a few pixels is clamped back on-screen by the menu itself.
  final estimatedHeight = entries.length * _rowHeight + HsSpace.x4;
  final top = above
      ? topLeft.dy - estimatedHeight - HsSpace.x2
      : topLeft.dy + anchor.size.height;
  final position = RelativeRect.fromLTRB(topLeft.dx, top, right, 0);

  return showMenu<T>(
    context: context,
    position: position,
    useRootNavigator: true,
    constraints: BoxConstraints(minWidth: minWidth),
    items: [
      for (final e in entries)
        PopupMenuItem<T>(
          value: e.value,
          height: 0,
          padding: EdgeInsets.zero,
          child: _MenuRow(entry: e),
        ),
    ],
  );
}

/// One row's height: the label line plus its vertical padding.
const _rowHeight = 42.0;

class _MenuRow<T> extends StatelessWidget {
  const new({required this.entry});

  final HsMenuEntry<T> entry;

  @override
  Widget build(BuildContext context) {
    final fg = context.hs.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      child: Row(
        spacing: HsSpace.x3,
        children: [
          if (entry.icon != null)
            SizedBox(width: 18, child: Icon(entry.icon, size: 17, color: fg)),
          Flexible(
            child: Text(
              entry.label,
              style: HsType.buttonSmall.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
