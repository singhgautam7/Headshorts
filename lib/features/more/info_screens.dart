import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/features/reader/reader_screen.dart';

/// Prose screens: Privacy and About. Both are short on purpose.
class ProseScreen extends StatelessWidget {
  const new({required this.title, required this.paragraphs, super.key});

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return PushedScreen(
      title: title,
      onBack: () => context.pop(),
      child: ListView(
        padding: const EdgeInsets.all(HsSpace.x5),
        children: [
          for (final paragraph in paragraphs) ...[
            Text(
              paragraph,
              style: HsType.bodySerif.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: HsSpace.x4),
          ],
        ],
      ),
    );
  }
}

const privacyScreen = ProseScreen(
  title: 'Privacy',
  paragraphs: [
    'HeadShorts has no account, no server and no analytics. Nothing about  what you read leaves the device.',
    'The app makes exactly two kinds of network request: it fetches the feeds  you subscribed to, and — when you open the Reader — it fetches the  article page so it can be laid out for reading here. Both go  directly to the publisher.',
    'Article extraction runs on the device, using the same heuristics a  browser reader view uses. No page is sent anywhere for processing.',
    'Your subscriptions, read state and reading times are stored in a local  database and are removed when you uninstall the app.',
  ],
);

const aboutScreen = ProseScreen(
  title: 'About HeadShorts',
  paragraphs: [
    'A finite briefing. It ends, and then you are done with it.',
    'HeadShorts reads the feeds you choose, in the order they were published.  There is no algorithm, no ranking and no infinite scroll. When you  reach the bottom, that is the news.',
    'There is deliberately no like, save-count, reaction, streak, goal, badge  or red dot anywhere in the app.',
    'Version 1.0',
  ],
);

/// The text-size screen reached from More — the same control the Reader uses.
class TextSizeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final step = ref.watch(settingsProvider).textSize;

    return PushedScreen(
      title: 'Text size',
      onBack: () => context.pop(),
      child: ListView(
        padding: const EdgeInsets.all(HsSpace.x5),
        children: [
          Text(
            'The slider offsets the system setting rather than overriding it.',
            style: HsType.note.copyWith(color: palette.textMuted),
          ),
          const SizedBox(height: 22),
          TextSizeSlider(
            step: step,
            onChanged: (next) =>
                ref.read(settingsProvider.notifier).setTextSize(next),
          ),
          const SizedBox(height: 30),
          Text(
            'Generous line-height is the whole point. Reader body sits at 1.7 '
            'and honours the system text-size setting.',
            style: HsType.readerBody(step.fontSize)
                .copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
