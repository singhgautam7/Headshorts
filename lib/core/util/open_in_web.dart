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
  final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
  return launchUrl(
    uri,
    mode: isHttp && mode == LinkOpenMode.inApp
        ? LaunchMode.inAppBrowserView
        : LaunchMode.externalApplication,
  );
}
