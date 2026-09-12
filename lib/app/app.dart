import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/router.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/prefs/settings.dart';

class HeadShortsApp extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HeadShortsApp> createState() => _HeadShortsAppState();
}

class _HeadShortsAppState extends ConsumerState<HeadShortsApp> {
  // Built once: rebuilding the router on a theme change would reset
  // navigation, and the theme is applied above it anyway.
  late final GoRouter _router = buildRouter(
    onboarded: ref.read(settingsProvider).onboarded,
  );

  @override
  void initState() {
    super.initState();
    // Pre-warm the catalog parse in background so Sources screen opens without lag.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(sourceCatalogProvider.future));
    });
  }

  @override
  Widget build(BuildContext context) {
    final choice = ref.watch(settingsProvider).theme;
    final systemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    final palette = switch (choice) {
      HsThemeChoice.amoled => HsPalette.amoled,
      HsThemeChoice.white => HsPalette.light,
      HsThemeChoice.system => systemDark ? HsPalette.amoled : HsPalette.light,
    };

    // The system bars take the app's ground, so the pill is the only thing
    // that looks like chrome.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: palette.background,
        statusBarIconBrightness: palette.isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarIconBrightness: palette.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return MaterialApp.router(
      title: 'HeadShorts',
      debugShowCheckedModeBanner: false,
      theme: buildHsTheme(palette),
      routerConfig: _router,
      // Every screen is built from plain widgets rather than Scaffolds, so
      // one Material at the root gives text its ink and gives sheets and
      // ripples something to draw on.
      builder: (context, child) =>
          Material(color: palette.background, child: child),
    );
  }
}
