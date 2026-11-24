import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/refresh_controller.dart';
import 'package:headshorts/app/router.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/core/motion/theme_ripple.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/theme_family.dart';

class HeadShortsApp extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HeadShortsApp> createState() => _HeadShortsAppState();
}

class _HeadShortsAppState extends ConsumerState<HeadShortsApp>
    with WidgetsBindingObserver {
  /// The last system-bar look applied; the platform call is made only when it
  /// changes.
  (Color, bool)? _chrome;

  // Built once: rebuilding the router on a theme change would reset
  // navigation, and the theme is applied above it anyway.
  late final GoRouter _router = buildRouter(
    onboarded: ref.read(settingsProvider).onboarded,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pre-warm the catalog parse in background so Sources screen opens without lag.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(sourceCatalogProvider.future));
      // Automatic motion: the one-off RAM check, after the first frame.
      unawaited(ref.read(settingsProvider.notifier).checkDevice());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(refreshProvider.notifier).onResume());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only the fields that decide the theme — a text-size change must not
    // rebuild the whole app.
    final (familyId, mode, amoled) = ref.watch(
      settingsProvider.select((s) => (s.familyId, s.themeMode, s.amoled)),
    );
    final systemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final darkInEffect =
        mode == ThemeMode.dark || (mode == ThemeMode.system && systemDark);
    final tone = !darkInEffect
        ? Tone.light
        : amoled
        ? Tone.amoled
        : Tone.dark;
    final theme = hsThemeOf(ThemeFamily.byId(familyId), tone);
    final palette = theme.extension<HsThemeExtension>()!.palette;

    // The system bars take the app's ground, so the pill is the only thing
    // that looks like chrome.
    final chrome = (palette.background, palette.isDark);
    if (_chrome != chrome) {
      _chrome = chrome;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: palette.background,
          statusBarIconBrightness: palette.isDark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarIconBrightness: palette.isDark
              ? Brightness.light
              : Brightness.dark,
        ),
      );
    }

    return MaterialApp.router(
      title: 'HeadShorts',
      debugShowCheckedModeBanner: false,
      theme: theme,
      // The theme ripple reveals a change; an implicit theme tween under it
      // would fight it.
      themeAnimationDuration: Duration.zero,
      routerConfig: _router,
      // Every screen is built from plain widgets rather than Scaffolds, so
      // one Material at the root gives text its ink and gives sheets and
      // ripples something to draw on.
      builder: (context, child) => _MotionHost(
        child: ThemeRipple(
          child: Material(color: palette.background, child: child),
        ),
      ),
    );
  }
}

/// Puts the motion level in scope above the navigator (so sheets and dialogs
/// are covered) and tells [HsHaptics] while a scroll is under way.
class _MotionHost extends ConsumerWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(settingsProvider.select((s) => s.motionLevel));
    final off = systemMotionOff(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification) HsHaptics.scrolling = true;
        if (n is ScrollEndNotification) HsHaptics.scrolling = false;
        return false;
      },
      child: MotionScope(
        level: off ? MotionLevel.off : level,
        systemOff: off,
        child: child,
      ),
    );
  }
}
