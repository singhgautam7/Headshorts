import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/sheet.dart';

/// An explainer sheet: a few paragraphs, optionally a numbered list of steps,
/// optionally a quieter closing note, and at most two actions.
///
/// Deliberately content-driven rather than one-off, so the next thing that
/// needs explaining — AMOLED, AI summaries — is a call with different text
/// rather than another screen. Everything comes from the token layer, so it
/// looks like the rest of the app in both themes without any new design.
class InfoSheet extends StatelessWidget {
  const new({
    required this.title,
    required this.paragraphs,
    this.stepsTitle,
    this.steps = const [],
    this.note,
    this.primaryAction,
    this.onPrimaryAction,
    this.secondaryAction,
    super.key,
  });

  final String title;
  final List<String> paragraphs;

  /// Heading above [steps], if there are any.
  final String? stepsTitle;
  final List<String> steps;

  /// A quieter line at the foot — a tip, or a caveat.
  final String? note;

  final String? primaryAction;
  final VoidCallback? onPrimaryAction;

  /// The dismissing action. Defaults to closing the sheet.
  final String? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final stepsHeading = stepsTitle;
    final closing = note;
    final primary = primaryAction;
    final secondary = secondaryAction;

    return HsSheet(
      title: title,
      children: [
        for (final paragraph in paragraphs) ...[
          Text(
            paragraph,
            style: HsType.lead.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: HsSpace.x4),
        ],
        if (stepsHeading != null) ...[
          SectionLabel(stepsHeading),
          const SizedBox(height: HsSpace.x3),
        ],
        for (var i = 0; i < steps.length; i++) ...[
          _Step(number: i + 1, text: steps[i]),
          if (i < steps.length - 1) const SizedBox(height: HsSpace.x3),
        ],
        if (steps.isNotEmpty) const SizedBox(height: HsSpace.x4),
        if (closing != null) ...[
          Text(closing, style: HsType.note.copyWith(color: palette.textMuted)),
          const SizedBox(height: HsSpace.x4),
        ],
        if (primary != null)
          HsButton(
            primary,
            onPressed: () {
              Navigator.of(context).pop();
              onPrimaryAction?.call();
            },
          ),
        if (secondary != null) ...[
          const SizedBox(height: HsSpace.x2),
          HsButton(
            secondary,
            onPressed: () => Navigator.of(context).pop(),
            kind: HsButtonKind.tertiary,
            height: HsSize.buttonSmall,
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const new({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '$number.',
            style: HsType.bodySans.copyWith(color: palette.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: HsType.bodySans.copyWith(color: palette.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Opens an explainer over the current screen.
Future<void> showInfoSheet(
  BuildContext context, {
  required String title,
  required List<String> paragraphs,
  String? stepsTitle,
  List<String> steps = const [],
  String? note,
  String? primaryAction,
  VoidCallback? onPrimaryAction,
  String? secondaryAction,
}) => showHsSheet<void>(
  context,
  (context) => InfoSheet(
    title: title,
    paragraphs: paragraphs,
    stepsTitle: stepsTitle,
    steps: steps,
    note: note,
    primaryAction: primaryAction,
    onPrimaryAction: onPrimaryAction,
    secondaryAction: secondaryAction,
  ),
);
