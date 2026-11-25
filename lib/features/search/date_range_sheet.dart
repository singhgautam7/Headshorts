import 'package:flutter/material.dart' show showDatePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/core/motion/expand_collapse.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/features/search/search_controller.dart';

/// The date range a search covers.
///
/// Presets cover nearly every search; "Between dates" opens the system date
/// picker on each field. Results stay newest first either way — a range
/// narrows the list, it never reorders it.
Future<void> showDateRangeSheet(BuildContext context) =>
    showHsSheet<void>(context, (context) => const _DateRangeSheet());

class _DateRangeSheet extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends ConsumerState<_DateRangeSheet> {
  late SearchDateRange _draft = ref.read(searchDateProvider);

  Future<void> _pick({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _draft.from : _draft.to) ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _draft = SearchDateRange(
        DateRangePreset.between,
        from: isStart ? picked : _draft.from,
        to: isStart ? _draft.to : picked,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return HsSheet(
      title: 'Date range',
      subtitle: 'By publication date. Results stay newest first.',
      children: [
        for (final preset in DateRangePreset.values)
          _PresetRow(
            preset: preset,
            selected: _draft.preset == preset,
            showDivider: preset != DateRangePreset.values.last,
            onTap: () => setState(
              () => _draft = preset == DateRangePreset.between
                  ? SearchDateRange(preset, from: _draft.from, to: _draft.to)
                  : SearchDateRange(preset),
            ),
          ),
        // The two fields belong to "Between dates" and arrive with it. They
        // grow out from under the row that opened them rather than appearing
        // fully formed, so the sheet reads as one thing changing shape.
        ExpandCollapse(
          expanded: _draft.preset == DateRangePreset.between,
          child: Padding(
            padding: const EdgeInsets.only(top: HsSpace.x3),
            child: Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'From',
                    value: _draft.from == null
                        ? 'Pick a date'
                        : SearchDateRange.shortDate(_draft.from!),
                    onTap: () => _pick(isStart: true),
                  ),
                ),
                const SizedBox(width: HsSpace.x3),
                Expanded(
                  child: _DateField(
                    label: 'To',
                    value: _draft.to == null
                        ? 'Today'
                        : SearchDateRange.shortDate(_draft.to!),
                    onTap: () => _pick(isStart: false),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: HsSpace.x5),
        Row(
          children: [
            Expanded(
              child: HsButton(
                'Reset',
                onPressed: () {
                  ref
                      .read(searchDateProvider.notifier)
                      .set(SearchDateRange.initial);
                  Navigator.of(context).pop();
                },
                kind: HsButtonKind.secondary,
              ),
            ),
            const SizedBox(width: HsSpace.x3),
            Expanded(
              child: HsButton(
                'Apply',
                // A "between" with no start date would silently mean "any
                // time"; saying nothing about that is how a filter reads as
                // broken.
                onPressed:
                    _draft.preset == DateRangePreset.between &&
                        _draft.from == null
                    ? null
                    : () {
                        ref.read(searchDateProvider.notifier).set(_draft);
                        Navigator.of(context).pop();
                      },
              ),
            ),
          ],
        ),
        ExpandCollapse(
          expanded:
              _draft.preset == DateRangePreset.between && _draft.from == null,
          child: Padding(
            padding: const EdgeInsets.only(top: HsSpace.x3),
            child: Text(
              'Pick a start date.',
              style: HsType.note.copyWith(color: palette.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetRow extends StatelessWidget {
  const new({
    required this.preset,
    required this.selected,
    required this.onTap,
    this.showDivider = true,
  });

  final DateRangePreset preset;
  final bool selected;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        kind: PressKind.row,
        haptic: true,
        onTap: onTap,
        selected: selected,
        semanticLabel: preset.label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: palette.divider))
                : null,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: HsSize.tapTarget),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    preset.label,
                    style: (selected ? HsType.chipSelected : HsType.row)
                        .copyWith(fontSize: 15, color: palette.textPrimary),
                  ),
                ),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The board's radio: a 20dp ring with an ink dot that springs in when
/// chosen. Ink, not accent: the control belongs to the reader.
class _Radio extends StatelessWidget {
  const new({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final level = HsMotion.levelOf(context);
    final curve = HsMotion.spatialCurve(level, HsMotion.fastCurve);
    final off = level == MotionLevel.off;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1 : 0),
      duration: off ? HsMotion.fxInstant : curve.settle,
      curve: off ? HsMotion.curveEffects : curve,
      builder: (context, k, _) {
        final c = k.clamp(0.0, 1.0);
        return Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Color.lerp(palette.stroke, palette.textPrimary, c)!,
              width: 1.6,
            ),
          ),
          child: Container(
            width: 10 * k.clamp(0.0, 1.3),
            height: 10 * k.clamp(0.0, 1.3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.textPrimary.withValues(alpha: c),
            ),
          ),
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const new({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Pressable(
      kind: PressKind.row,
      onTap: onTap,
      semanticLabel: '$label, $value',
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: palette.stroke),
          borderRadius: HsRadius.buttonBorder,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: HsType.rowSub.copyWith(
                fontSize: 11,
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: HsType.chipSelected.copyWith(
                fontSize: 15,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
