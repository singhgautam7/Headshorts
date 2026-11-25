import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The accent Android derives from the wallpaper (Android 12 and later), one
/// ARGB int over the platform channel; null below that, or on any failure.
///
/// Nothing asks for it unless the reader has switched wallpaper colour on, so
/// it never sits in front of the first frame. The theme screen asks too, to
/// know whether the option can be offered at all.
final wallpaperSeedProvider = FutureProvider<Color?>((ref) async {
  try {
    final argb = await const MethodChannel('headshorts/platform')
        .invokeMethod<int>('wallpaperSeed');
    return argb == null ? null : Color(argb);
  } on Object catch (_) {
    // No channel (a test, an old phone), a refusal, a bad reply: no seed.
    return null;
  }
});
