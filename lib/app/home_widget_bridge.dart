import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/app/router.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('headshorts/widget');

/// Calls the Android side. A phone without the widget code, or a test with no
/// platform, answers nothing; that is never the reader's problem.
Future<T?> _call<T>(String method, [Object? args]) async {
  try {
    return await _channel.invokeMethod<T>(method, args);
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

/// Asks the home screen widgets to redraw from the database. [fetched] when a
/// refresh just finished, which clears any earlier failure they were showing.
Future<void> notifyHomeWidgets({bool fetched = false}) =>
    _call<void>('update', fetched);

/// Ids of the widgets currently placed on a home screen.
Future<List<int>> placedHomeWidgets() async =>
    (await _call<List<Object?>>('placedWidgets'))?.cast<int>() ?? const [];

Future<bool> canPinHomeWidget() async => await _call<bool>('canPin') ?? false;

Future<bool> requestPinHomeWidget() async =>
    await _call<bool>('requestPin') ?? false;

/// Tells Android the configure screen is done. True means the configure
/// activity closed itself; false means this was an in-app visit to pop.
Future<bool> finishWidgetConfig(int appWidgetId) async =>
    await _call<bool>('finishConfig', appWidgetId) ?? false;

/// The colours a widget below Android 12 paints with, as the app theme sees
/// them. From 12 on the widget uses the system's own colours instead.
Map<String, int> widgetThemeValues({
  required String familyId,
  required ThemeMode mode,
  required bool amoled,
  required bool systemDark,
  bool expressive = true,
  Color? seed,
}) {
  final dark =
      mode == ThemeMode.dark || (mode == ThemeMode.system && systemDark);
  final p = themeFor(
    familyId: familyId,
    mode: mode,
    amoled: amoled,
    systemDark: systemDark,
    expressive: expressive,
    seed: seed,
  ).extension<HsThemeExtension>()!.palette;
  return {
    'widget_bg': p.surface.toARGB32(),
    'widget_fg': p.textPrimary.toARGB32(),
    'widget_fg2': p.textSecondary.toARGB32(),
    'widget_accent': p.primary.toARGB32(),
    'widget_dark': dark ? 1 : 0,
  };
}

/// Opens an article from a widget tap: Headlines first, so Back from the
/// Reader lands there. Does nothing before onboarding, and does not stack a
/// second Reader on the one already showing that article.
void openArticleFromWidget(GoRouter router, int id, {required bool onboarded}) {
  if (!onboarded) return;
  final reader = '/reader/$id';
  if (router.routerDelegate.currentConfiguration.uri.path == reader) return;
  router.go('/today');
  unawaited(router.push<void>(reader));
}

GoRouter? _router() {
  final context = rootNavigatorKey.currentContext;
  return context == null ? null : GoRouter.maybeOf(context);
}

class HomeWidgetBridge with WidgetsBindingObserver {
  new(this._ref);

  final Ref _ref;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _ref
      ..onDispose(() => WidgetsBinding.instance.removeObserver(this))
      ..listen(refreshProvider.select((p) => p.finished), (_, finished) {
        if (finished) unawaited(notifyHomeWidgets(fetched: true));
      })
      ..listen(
        settingsProvider.select(
          (s) => (
            s.familyId,
            s.themeMode,
            s.amoled,
            s.expressiveColors,
            s.wallpaperColor,
            s.wallpaperSeed,
          ),
        ),
        (_, _) => unawaited(_pushTheme()),
      );
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openArticle') _open(call.arguments as int?);
    });
    unawaited(_pushTheme());
    unawaited(_takeLaunchArticle());
  }

  @override
  void didChangePlatformBrightness() => unawaited(_pushTheme());

  Future<void> _takeLaunchArticle() async {
    _open(await _call<int>('takeLaunchArticle'));
  }

  void _open(int? id) {
    final router = _router();
    if (id == null || router == null) return;
    openArticleFromWidget(
      router,
      id,
      onboarded: _ref.read(settingsProvider).onboarded,
    );
  }

  Future<void> _pushTheme() async {
    final s = _ref.read(settingsProvider);
    final values = widgetThemeValues(
      familyId: s.familyId,
      mode: s.themeMode,
      amoled: s.amoled,
      expressive: s.expressiveColors,
      // The stored seed only: the bridge never asks the platform itself.
      seed: s.wallpaperColor && s.wallpaperSeed != null
          ? Color(s.wallpaperSeed!)
          : null,
      systemDark:
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark,
    );
    final prefs = await SharedPreferences.getInstance();
    for (final e in values.entries) {
      await prefs.setInt(e.key, e.value);
    }
    await notifyHomeWidgets();
  }
}

/// Read once, after the first frame, from `main`.
final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>((ref) {
  final bridge = HomeWidgetBridge(ref)..start();
  return bridge;
});
