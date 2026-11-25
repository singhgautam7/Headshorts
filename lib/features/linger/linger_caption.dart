import 'dart:async';

import 'package:flutter/material.dart' show Icons;
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

  /// The headline's share of the card when it would otherwise take all of it.
  static const titleShare = 0.6;

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
            // The headline alone would fill the card: it gives up 40% of the
            // room, so the description always starts.
            final shared = room - gap;
            bodyLines = hasBody
                ? (shared * (1 - titleShare) / bodyLine).floor().clamp(
                    0,
                    maxLines,
                  )
                : 0;
            titleLines = bodyLines == 0
                ? (room / titleLine).floor()
                : ((shared - bodyLines * bodyLine) / titleLine).floor();
            if (titleLines < 1) {
              titleLines = 1;
              bodyLines = 0;
            }
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
        delegate: _Centred(MediaQuery.viewPaddingOf(context)),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          HsIconButton(
            icon: Icons.close_rounded,
            onPressed: () => Navigator.of(context).pop(),
            semanticLabel: 'Close',
          ),
          const SizedBox(height: _Centred.gap),
          Flexible(child: _panel(context)),
        ],
      ),
    ),
  );

  Widget _panel(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Color.alphaBlend(caption.ground, context.hs.surface),
      borderRadius: HsRadius.cardBorder,
      border: Border.all(color: caption.edge),
    ),
    padding: const EdgeInsets.fromLTRB(
      _Centred.pad,
      _Centred.pad,
      _Centred.pad,
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

/// The card in the middle of the screen, its close button above its top right
/// corner. The card is what is centred, not the pair, unless it is too tall
/// for that.
class _Centred extends SingleChildLayoutDelegate {
  const new(this.insets);

  final EdgeInsets insets;

  static const pad = HsSpace.x4;

  /// Between the close button and the card.
  static const gap = HsSpace.x1;
  static const _above = HsSize.tapTarget + gap;

  double get _top => insets.top + HsSpace.x2;
  double get _bottom => insets.bottom + HsSpace.x3;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = constraints.maxWidth - insets.horizontal - HsSpace.x5 * 2;
    return BoxConstraints(
      minWidth: width.clamp(0, HsSize.litMaxWidth),
      maxWidth: width.clamp(0, HsSize.litMaxWidth),
      maxHeight: constraints.maxHeight - _top - _bottom,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    final card = child.height - _above;
    final lowest = size.height - _bottom - child.height;
    return Offset(
      (size.width - child.width) / 2,
      ((size.height - card) / 2 - _above).clamp(
        _top,
        lowest < _top ? _top : lowest,
      ),
    );
  }

  @override
  bool shouldRelayout(_Centred old) => old.insets != insets;
}
