import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';

/// A quiet, transient line confirming something happened.
///
/// Deliberately unremarkable: it states the outcome and leaves. No badge, no
/// celebration, no action to dismiss — the app has nothing to congratulate the
/// reader for.
void showNotice(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Notice(message: message, onDone: entry.remove),
  );
  overlay.insert(entry);
}

class _Notice extends StatefulWidget {
  const new({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_Notice> createState() => _NoticeState();
}

class _NoticeState extends State<_Notice> {
  static const _visibleFor = Duration(seconds: 4);

  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
    _timer = Timer(_visibleFor, () {
      if (!mounted) return;
      setState(() => _shown = false);
      _timer = Timer(HsMotion.page, widget.onDone);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return Positioned(
      left: HsSpace.x5,
      right: HsSpace.x5,
      // Above the floating pill, so it never covers navigation.
      bottom: HsSpace.navClearance,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _shown ? 1 : 0,
          duration: HsMotion.page,
          curve: HsMotion.pageCurve,
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: HsSpace.x4,
                vertical: HsSpace.x3,
              ),
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: HsRadius.buttonBorder,
              ),
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: HsType.bodySans.copyWith(color: palette.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
