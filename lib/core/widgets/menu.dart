import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/pressable.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/glyphs.dart';

/// One row of a [showHsMenu].
class HsMenuEntry<T> {
  const new({
    required this.value,
    required this.label,
    this.icon,
    this.sub,
    this.selected = false,
    this.enabled = true,
  });

  final T value;
  final String label;

  /// Every menu row should carry one (20dp, 12 before the label).
  final IconData? icon;

  /// A reason under the label — why an item will not do what it says, or
  /// what choosing it means. An item that cannot act stays in the menu and
  /// explains itself rather than disappearing.
  final String? sub;

  /// Draws the row as the one in effect, for a menu that is a choice rather
  /// than a list of actions.
  final bool selected;

  /// A disabled row is announced as such and does nothing when pressed.
  final bool enabled;
}

/// The anchored overflow menu: one panel in one route, hanging off the
/// control that raised it. It fades in over 150ms while dropping 8dp (a 90ms
/// fade at Off), and out over 90ms.
///
/// The menu opens below [anchorContext], or above it when [above] is set —
/// the Reader's floating buttons sit at the foot of the screen. Either way it
/// flips if it does not fit, stays on screen, and scrolls when taller than
/// the room it has.
Future<T?> showHsMenu<T>({
  required BuildContext context,
  required BuildContext anchorContext,
  required List<HsMenuEntry<T>> entries,
  bool above = false,
  double minWidth = 200,
}) {
  final anchor = anchorContext.findRenderObject() as RenderBox?;
  if (anchor == null || !anchor.attached) return Future.value();
  final nav = Navigator.of(context, rootNavigator: true);
  return nav.push(
    _MenuRoute<T>(
      anchor: anchor.localToGlobal(Offset.zero) & anchor.size,
      entries: entries,
      above: above,
      minWidth: minWidth.clamp(_minPanel, _maxPanel),
      level: HsMotion.levelOf(context),
      barrierLabel: 'Dismiss menu',
    ),
  );
}

const _minPanel = 200.0;
const _maxPanel = 320.0;
const _gap = HsSpace.x1;
const _edge = HsSpace.x2;
const _rowMin = 48.0;

class _MenuRoute<T> extends PopupRoute<T> {
  new({
    required this.anchor,
    required this.entries,
    required this.above,
    required this.minWidth,
    required this.level,
    required this.barrierLabel,
  });

  final Rect anchor;
  final List<HsMenuEntry<T>> entries;
  final bool above;
  final double minWidth;
  final MotionLevel level;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration =>
      level == MotionLevel.off ? HsMotion.fxInstant : HsMotion.fxFast;

  @override
  Duration get reverseTransitionDuration => HsMotion.fxInstant;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final palette = context.hs;
    final dir = above ? 1.0 : -1.0;
    final eased = CurveTween(curve: HsMotion.curveEffects).animate(animation);
    final panel = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: HsRadius.menuBorder,
          border: Border.all(color: palette.stroke),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HsSpace.x2),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in entries)
                  _MenuRow<T>(
                    entry: e,
                    onTap: () => Navigator.of(context).pop(e.value),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: barrierLabel,
      child: Material(
        type: MaterialType.transparency,
        child: CustomSingleChildLayout(
          delegate: _MenuLayout(
            anchor: anchor,
            above: above,
            minWidth: minWidth,
            padding: media.padding,
          ),
          child: AnimatedBuilder(
            animation: eased,
            child: panel,
            builder: (context, child) => Opacity(
              opacity: eased.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(
                  0,
                  level == MotionLevel.off
                      ? 0
                      : dir * HsSpace.x2 * (1 - eased.value),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  const new({
    required this.anchor,
    required this.above,
    required this.minWidth,
    required this.padding,
  });

  final Rect anchor;
  final bool above;
  final double minWidth;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: minWidth,
        maxWidth: _maxPanel,
        maxHeight: (constraints.maxHeight - padding.vertical - _edge * 2).clamp(
          0.0,
          double.infinity,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Left edges line up; if that runs off the right, right edges do.
    var x = anchor.left;
    if (x + childSize.width > size.width - padding.right - _edge) {
      x = anchor.right - childSize.width;
    }
    x = x.clamp(
      padding.left + _edge,
      (size.width - padding.right - _edge - childSize.width).clamp(
        padding.left + _edge,
        double.infinity,
      ),
    );

    final top = padding.top + _edge;
    final bottom = size.height - padding.bottom - _edge;
    final below = anchor.bottom + _gap;
    final over = anchor.top - _gap - childSize.height;
    final fitsBelow = below + childSize.height <= bottom;
    final fitsAbove = over >= top;
    final useAbove = above
        ? (fitsAbove || !fitsBelow)
        : (!fitsBelow && fitsAbove);
    var y = useAbove ? over : below;
    y = y.clamp(top, (bottom - childSize.height).clamp(top, double.infinity));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      old.anchor != anchor ||
      old.above != above ||
      old.minWidth != minWidth ||
      old.padding != padding;
}

class _MenuRow<T> extends StatelessWidget {
  const new({required this.entry, required this.onTap});

  final HsMenuEntry<T> entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final sub = entry.sub;
    final enabled = entry.enabled;
    // An item that cannot act reads in secondary ink, not greyed out: with a
    // sub it is still tappable, and tapping it explains.
    final fg = !enabled || sub != null
        ? palette.textSecondary
        : palette.textPrimary;
    final icon = entry.icon;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: entry.selected,
      label: sub == null ? entry.label : '${entry.label}, $sub',
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Pressable(
        kind: PressKind.row,
        enabled: enabled,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: entry.selected ? palette.primaryContainer : null,
            borderRadius: HsRadius.buttonBorder,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _rowMin),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HsSpace.x3,
                vertical: HsSpace.x2,
              ),
              child: Row(
                spacing: HsSpace.x3,
                children: [
                  if (icon != null) Icon(icon, size: 20, color: fg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.label,
                          style: HsType.buttonSmall.copyWith(color: fg),
                        ),
                        if (sub != null) ...[
                          const SizedBox(height: HsSpace.x1),
                          Text(
                            sub,
                            style: HsType.rowSub.copyWith(
                              fontSize: 11,
                              height: 1.3,
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (entry.selected) HsGlyph.tick(palette.onPrimaryContainer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
