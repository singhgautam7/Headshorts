import 'package:flutter/widgets.dart';
import 'package:headshorts/core/widgets/info_sheet.dart';

/// Why a search of the reader's own sources can come up empty while Google
/// News returns results from those very same publishers.
///
/// It is the most confusing thing about Search, and it is confusing for a good
/// reason: the mastheads match, so the reader reasonably concludes the app is
/// broken. It is not — the two are searching different corpora. Saying so in
/// one sheet is cheaper than a setting, and honest in a way that quietly
/// widening the query would not be.
Future<void> showCacheExplainer(BuildContext context) => showInfoSheet(
  context,
  title: 'Why your sources found nothing',
  paragraphs: _paragraphs,
  stepsTitle: 'Two reasons',
  steps: _reasons,
  note: _note,
  secondaryAction: 'Got it',
);

const _theShortVersion =
    'Your sources and Google News are not looking at the same thing.';

const _feedIsNotAnArchive =
    'An RSS feed carries a publisher\u2019s latest headlines, usually the last '
    'few dozen. It is not an archive, so your copy of The Hindu reaches back '
    'days rather than months.';

const _googleIsTheWholeSite =
    'Google News searches the publisher\u2019s whole site. That is how it finds '
    'stories your own feed never carried.';

const _note =
    'Widening the dates will not reach further back, because nothing older '
    'was ever stored. Google News is the way past that, and it is the one '
    'thing here that sends your search off the device.';

const _paragraphs = [_theShortVersion];
const _reasons = [_feedIsNotAnArchive, _googleIsTheWholeSite];
