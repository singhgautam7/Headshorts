import 'dart:async';

import 'package:flutter/material.dart'
    show MaterialLocalizations, ModalBottomSheetRoute;
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/motion/pressable.dart';
import 'package:headshorts/core/motion/route_styles.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
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
      // Scrolls only when it has to: the view sizes itself to its content, so
      // a three-row option sheet still hugs the bottom of the screen. Without
      // it a sheet longer than the screen — a long explainer, or any sheet at
      // a large system font size — overflowed its column and clipped the
      // actions at the foot, which are the part that must always be reachable.
      child: SingleChildScrollView(
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
      ),
    );
  }
}

/// Presents [builder] over a scrim, at the app's own corner radius, on
/// Kuber's sheet spring. The sheet moves as one layer and its slide starts
/// only once its first frame is built.
Future<T?> showHsSheet<T>(BuildContext context, WidgetBuilder builder) {
  // Above the shell, so the floating nav pill does not sit on top of the
  // sheet's own actions.
  final nav = Navigator.of(context, rootNavigator: true);
  return nav.push(
    _SheetRoute<T>(
      capturedThemes: InheritedTheme.capture(from: context, to: nav.context),
      barrierLabel: MaterialLocalizations.of(context).scrimLabel,
      isScrollControlled: true,
      backgroundColor: const Color(0x00000000),
      modalBarrierColor: context.hs.scrim,
      elevation: 0,
      sheetAnimationStyle: sheetStyle(context),
      builder: (context) => RepaintBoundary(child: builder(context)),
    ),
  );
}

/// Holds the slide until the sheet's first frame is built. Flutter starts the
/// clock on push, so a heavy first frame spent the fastest part of the slide
/// before anything showed and the sheet popped instead of sliding.
class _SheetRoute<T> extends ModalBottomSheetRoute<T> {
  new({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.backgroundColor,
    super.elevation,
    super.modalBarrierColor,
    super.sheetAnimationStyle,
  });

  @override
  TickerFuture didPush() {
    final future = super.didPush();
    if (controller case final AnimationController c when c.isAnimating) {
      c.stop();
      unawaited(
        WidgetsBinding.instance.endOfFrame.then((_) {
          // Popped or moved meanwhile: leave it.
          if (isActive &&
              !c.isAnimating &&
              c.value == 0 &&
              c.status == AnimationStatus.forward) {
            c.forward();
          }
        }),
      );
    }
    return future;
  }
}

/// One choice in [showOptionSheet].
class SheetOption<T> {
  const new({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
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
          onTap: () {
            HsHaptics.tick();
            Navigator.of(sheetContext).pop(option.value);
          },
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
          kind: PressKind.row,
          onTap: onTap,
          child: AnimatedContainer(
            duration: HsMotion.fxFast,
            curve: HsMotion.curveEffects,
            constraints: const BoxConstraints(minHeight: 48),
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
                if (option.icon != null) ...[
                  Icon(
                    option.icon,
                    size: 20,
                    color: selected
                        ? palette.onPrimaryContainer
                        : palette.textSecondary,
                  ),
                  const SizedBox(width: HsSpace.x3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
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
