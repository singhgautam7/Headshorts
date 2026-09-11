import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/app.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferences are read once, before the first frame, so no screen has to
  // render a placeholder for its own theme.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore(prefs)),
      ],
      child: const HeadShortsApp(),
    ),
  );
}
