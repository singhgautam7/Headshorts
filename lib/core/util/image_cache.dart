import 'package:flutter/painting.dart';

/// Caps decoded images at 60 MB (the framework default is 100 MB).
///
/// Thumbnails are decoded at the size they are drawn, so this is headroom for
/// the Reader's full-width pictures rather than a limit anything runs into.
/// Call once from `main`, after the binding is initialised.
void configureImageCache() {
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 * 1024 * 1024;
}
