import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';

/// A Linger card's headline and description, cut to the room it has.
///
/// It never scrolls: a scroll inside a card that is itself paged fights the
/// page, and reaching the end of one flung several of the other. What does not
/// fit is behind "Show more", which lights the text and darkens the rest.
class LingerCaption extends StatelessWidget {
  const new({
    required this.title,
    required this.description,
    required this.titleStyle,
    required this.bodyStyle,
    required this.ground,
    required this.edge,
    this.gap = 22,
    super.key,
  });

  final String title;
  final String description;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;

  /// The card's own ground and hairline, so the lit panel is the same object.
  final Color ground;
  final Color edge;
  final double gap;

  /// The most of a description a card shows before "Show more".
  static const maxLines = 6;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, box) {
        TextPainter measure(String text, TextStyle style, {int? lines}) =>
            TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: direction,
              textScaler: scaler,
              maxLines: lines,
            )..layout(maxWidth: box.maxWidth);

        final titleText = measure(title, titleStyle);
        final bodyText = measure(description, bodyStyle, lines: maxLines);
        final titleHeight = titleText.height;
        final titleLine = titleText.preferredLineHeight;
        final bodyLine = bodyText.preferredLineHeight;
        final hasBody = description.isNotEmpty;
        final needed = titleHeight + (hasBody ? gap + bodyText.height : 0);
        final cut =
            needed > box.maxHeight || (hasBody && bodyText.didExceedMaxLines);
        titleText.dispose();
        bodyText.dispose();

        int? titleLines;
        int? bodyLines;
        if (cut) {
          final room = box.maxHeight - HsSize.tapTarget;
          final forBody = ((room - titleHeight - gap) / bodyLine).floor();
          if (hasBody && forBody >= 1) {
            bodyLines = forBody.clamp(1, maxLines);
          } else {
            // The headline alone fills the card.
            bodyLines = 0;
            titleLines = (room / titleLine).floor().clamp(1, 99);
          }
        }

        // Clipped, never scrolled: the last resort in a window so short that
        // one line and the button do not fit.
        return ClipRect(
          child: OverflowBox(
            alignment: AlignmentDirectional.topStart,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: titleLines,
                  overflow: titleLines == null ? null : TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                if (hasBody && bodyLines != 0) ...[
                  SizedBox(height: gap),
                  Text(
                    description,
                    maxLines: bodyLines ?? maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle,
                  ),
                ],
                if (cut)
                  _MoreLess(
                    label: 'Show more',
                    color: titleStyle.color,
                    onTap: () => unawaited(_open(context)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _open(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final level = HsMotion.levelOf(context);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close the description',
      barrierColor: context.hs.scrim.withValues(alpha: 0.82),
      transitionDuration: level == MotionLevel.off
          ? HsMotion.fxInstant
          : HsMotion.fxDefault,
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: HsMotion.curveEffects,
        ),
        child: child,
      ),
      pageBuilder: (context, _, _) => CustomSingleChildLayout(
        delegate: _OverCaption(rect, MediaQuery.viewPaddingOf(context)),
        child: _Lit(caption: this),
      ),
    );
  }
}

/// The caption, lit: the whole text, scrolling only if it is taller than the
/// screen, and "Show less" beneath it.
class _Lit extends StatelessWidget {
  const new({required this.caption});

  final LingerCaption caption;

  @override
  Widget build(BuildContext context) => Semantics(
    scopesRoute: true,
    namesRoute: true,
    explicitChildNodes: true,
    label: 'Description',
    child: DefaultTextStyle(
      style: caption.bodyStyle,
      child: Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(caption.ground, context.hs.surface),
          borderRadius: HsRadius.cardBorder,
          border: Border.all(color: caption.edge),
        ),
        padding: const EdgeInsets.fromLTRB(
          _OverCaption.pad,
          _OverCaption.pad,
          _OverCaption.pad,
          0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(caption.title, style: caption.titleStyle),
                    if (caption.description.isNotEmpty) ...[
                      SizedBox(height: caption.gap),
                      Text(
                        caption.description,
                        style: caption.bodyStyle.copyWith(
                          color: context.hs.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _MoreLess(
              label: 'Show less',
              color: caption.titleStyle.color,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MoreLess extends StatelessWidget {
  const new({required this.label, required this.onTap, this.color});

  final String label;

  /// The headline's own ink.
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    kind: PressKind.chip,
    morphCorners: false,
    onTap: onTap,
    semanticLabel: label,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: HsSize.tapTarget),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: ExcludeSemantics(
          child: Text(
            label,
            style: HsMotion.weightStyle(
              HsType.buttonSmall,
              700,
            ).copyWith(color: color),
          ),
        ),
      ),
    ),
  );
}

/// Over the caption it came from, moving up only as far as it must to fit.
class _OverCaption extends SingleChildLayoutDelegate {
  const new(this.caption, this.insets);

  final Rect caption;
  final EdgeInsets insets;

  static const pad = HsSpace.x4;

  double get _top => insets.top + HsSpace.x3;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = (caption.width + pad * 2).clamp(0.0, constraints.maxWidth);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: constraints.maxHeight - _top - insets.bottom - HsSpace.x3,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    final lowest = size.height - insets.bottom - HsSpace.x3 - child.height;
    return Offset(
      (caption.left - pad).clamp(0.0, size.width - child.width),
      (caption.top - pad).clamp(_top, lowest < _top ? _top : lowest),
    );
  }

  @override
  bool shouldRelayout(_OverCaption old) =>
      old.caption != caption || old.insets != insets;
}
