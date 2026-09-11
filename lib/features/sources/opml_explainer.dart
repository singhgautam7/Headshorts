import 'package:flutter/widgets.dart';
import 'package:headshorts/core/widgets/info_sheet.dart';

/// The OPML explainer, offered next to every "Import OPML" affordance.
///
/// The primary action opens the picker directly, so a reader who came here to
/// understand the feature does not have to go back and hunt for the button
/// they were already standing next to.
Future<void> showOpmlExplainer(
  BuildContext context, {
  required VoidCallback onImport,
}) => showInfoSheet(
  context,
  title: "What's an OPML file?",
  paragraphs: _paragraphs,
  stepsTitle: 'How to import',
  steps: _steps,
  note: _privacyNote,
  primaryAction: 'Import OPML file',
  onPrimaryAction: onImport,
  secondaryAction: 'Maybe later',
);

const _whatItIs =
    'An OPML file is just a list of RSS feeds saved in one file — think of it '
    'like a contacts export, but for news sources. Instead of adding feeds one '
    'at a time, you can bring in a whole set at once.';

const _stepGet =
    'Get an OPML file — export one from another reader (Feedly, Inoreader, '
    'NetNewsWire…), or use a shared starter list.';

const _stepChoose = 'Tap "Import OPML" and choose the file from your device.';

const _stepDone =
    'Done — the feeds appear under Sources, already grouped into categories.';

const _privacyNote =
    'Your feeds stay on your device. Nothing is uploaded.\n\n'
    'Tip: you can also export your feeds anytime to back them up or move to '
    'another app.';

const _paragraphs = [_whatItIs];
const _steps = [_stepGet, _stepChoose, _stepDone];
