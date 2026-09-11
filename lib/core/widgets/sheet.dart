import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';

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
      builder: builder,
    );
