import 'package:headshorts/data/prefs/settings.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands off to the publisher, keeping their page, their analytics and their
/// ads where they belong.
///
/// A Custom Tab by default, so the reader comes straight back; the reader can
/// choose their own browser instead, which keeps their session and extensions.
Future<bool> openInWeb(String url, {LinkOpenMode mode = LinkOpenMode.inApp}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return Future.value(false);
  return launchUrl(
    uri,
    mode: mode == LinkOpenMode.inApp
        ? LaunchMode.inAppBrowserView
        : LaunchMode.externalApplication,
  );
}
