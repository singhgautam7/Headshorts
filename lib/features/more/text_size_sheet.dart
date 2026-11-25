import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/features/reader/text_size_slider.dart';

/// Text size from Settings: the Reader's own slider, with a line of prose at
/// that size underneath, as Kuber's font sheet does.
Future<void> showTextSizeSheet(BuildContext context) =>
    showHsSheet<void>(context, (_) => const _TextSizeSheet());

class _TextSizeSheet extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final step = ref.watch(settingsProvider.select((s) => s.textSize));
    return HsSheet(
      title: 'Text size',
      subtitle:
          "For the articles you read. Your phone's own size still counts.",
      children: [
        Text(
          step.label,
          textAlign: TextAlign.end,
          style: HsType.buttonSmall.copyWith(color: palette.primary),
        ),
        const SizedBox(height: HsSpace.x2),
        TextSizeSlider(
          step: step,
          onChanged: (next) =>
              ref.read(settingsProvider.notifier).setTextSize(next),
        ),
        const SizedBox(height: HsSpace.x5),
        Container(
          padding: const EdgeInsets.all(HsSpace.x4),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: HsRadius.cardBorder,
            border: Border.all(color: palette.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PREVIEW',
                style: HsType.sectionLabel.copyWith(color: palette.textMuted),
              ),
              const SizedBox(height: HsSpace.x2),
              Text(
                'The first rain of the season reached the coast this morning, '
                'two days earlier than expected.',
                style: HsType.readerBody(step.fontSize)
                    .copyWith(color: palette.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: HsSpace.x5),
        HsButton('Done', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
