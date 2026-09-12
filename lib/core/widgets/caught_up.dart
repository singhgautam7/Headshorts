import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';

/// The end of a finite list.
///
/// Every list in the app terminates here. Nothing loads below it, and swiping
/// past it settles back.
class CaughtUp extends StatelessWidget {
  const new({
    required this.detail,
    this.actionLabel,
    this.onAction,
    this.note,
    this.large = false,
    super.key,
  });

  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? note;

  /// The Linger hard stop sets its own display one step larger.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final action = actionLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 34,
            height: HsSize.hairline,
            color: palette.textMuted.withValues(alpha: large ? 1 : 0.4),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          "You're caught up",
          textAlign: TextAlign.center,
          style: (large ? HsType.caughtUpLinger : HsType.caughtUp).copyWith(
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              detail,
              textAlign: TextAlign.center,
              style: HsType.caughtUpBody.copyWith(color: palette.textSecondary),
            ),
          ),
        ),
        if (action != null) ...[
          SizedBox(height: large ? 32 : 30),
          HsButton(
            action,
            onPressed: onAction,
            kind: HsButtonKind.secondary,
            height: large ? HsSize.buttonMedium : HsSize.buttonSmall,
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: HsSpace.x3),
          Text(
            note!,
            textAlign: TextAlign.center,
            style: HsType.note.copyWith(color: palette.textMuted),
          ),
        ],
      ],
    );
  }
}

/// A flat block standing in for a line of text while something loads.
///
/// Every skeleton in the app — Today, Linger, the Reader body, a source row —
/// is built from this and nothing else. It never shimmers: only the arriving
/// content replaces it.
class SkeletonBar extends StatelessWidget {
  const new({this.widthFactor = 1, this.width, this.height = 14, super.key});

  /// Fraction of the available width; ignored when [width] is given.
  final double widthFactor;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.hs.skeleton,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    if (width != null) return block;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: block,
    );
  }
}

/// A flat placeholder card in the shape of a headline.
class HeadlineSkeleton extends StatelessWidget {
  const new({
    this.widths = const [0.78, 0.52],
    this.withThumbnail = false,
    super.key,
  });

  final List<double> widths;
  final bool withThumbnail;

  @override
  Widget build(BuildContext context) {
    final fill = context.hs.skeleton;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: HsSize.accentBar,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SkeletonBar(widthFactor: 0.25, height: 8),
                const SizedBox(height: 9),
                const SkeletonBar(),
                const SizedBox(height: 9),
                SkeletonBar(widthFactor: widths.first),
                const SizedBox(height: 9),
                SkeletonBar(widthFactor: widths.last, height: 9),
              ],
            ),
          ),
          if (withThumbnail) ...[
            const SizedBox(width: 14),
            Container(
              width: HsSize.thumbnail,
              height: HsSize.thumbnail,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: HsRadius.buttonBorder,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
