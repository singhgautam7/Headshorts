import 'package:shared_preferences/shared_preferences.dart';

/// Which sources one placed widget shows, kept in the preferences file the
/// Kotlin provider also reads (`flutter.widget_sources_<id>`).
///
/// `null` means "every source I follow and have switched on", so a source
/// enabled tomorrow is in the widget tomorrow. An explicit set is exactly
/// those ids, and an empty one shows nothing.
abstract final class WidgetSources {
  static const all = 'all';

  static String key(int appWidgetId) => 'widget_sources_$appWidgetId';

  static Set<int>? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw == all) return null;
    return {for (final part in raw.split(',')) ?int.tryParse(part.trim())};
  }

  static String encode(Set<int>? ids) =>
      ids == null ? all : (ids.toList()..sort()).join(',');

  static Future<Set<int>?> read(
    SharedPreferences prefs,
    int appWidgetId,
  ) async {
    // The provider deletes the key when a widget is removed; Dart's cached
    // copy would not know.
    await prefs.reload();
    return parse(prefs.getString(key(appWidgetId)));
  }

  static Future<void> write(
    SharedPreferences prefs,
    int appWidgetId,
    Set<int>? ids,
  ) => prefs.setString(key(appWidgetId), encode(ids));
}
