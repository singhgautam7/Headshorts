import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/app.dart';
import 'package:headshorts/app/home_widget_bridge.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/util/image_cache.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/home_widget/widget_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureImageCache();

  // Preferences are read once, before the first frame, so no screen has to
  // render a placeholder for its own theme.
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [settingsStoreProvider.overrideWithValue(SettingsStore(prefs))],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HeadShortsApp(),
    ),
  );
  // After the first frame the router exists, so a widget tap that cold-started
  // the app can be routed, and the widget can follow the theme.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => container.read(homeWidgetBridgeProvider),
  );
}

/// Run by the home screen widget's refresh job in a headless engine. The app
/// is not started; see `features/home_widget/widget_refresh.dart`.
@pragma('vm:entry-point')
Future<void> widgetRefreshMain() => runWidgetRefreshEntry();
