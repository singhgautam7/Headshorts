import 'package:url_launcher/url_launcher.dart';

/// Hands off to the publisher in a Custom Tab, keeping their page, their
/// analytics and their ads where they belong.
Future<bool> openInWeb(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
}
