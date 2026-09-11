import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the floating nav pill is showing.
///
/// The pill is detached from the layout, so hiding it is a translation and
/// nothing reflows. Only Today drives this; every other destination leaves the
/// pill alone, and it is never left stranded off-screen.
class NavVisibility extends Notifier<bool> {
  @override
  bool build() => true;

  /// Movement smaller than this is ignored, so a thumb resting on the list
  /// cannot make the pill flicker.
  static const threshold = 24.0;

  /// Pixels travelled since the scroll last changed direction.
  double _travel = 0;

  /// Forwards a scroll from the list the pill floats over.
  ///
  /// Takes the metrics and the movement rather than the notification itself,
  /// so the rule can be exercised without a live scroll view.
  ///
  /// Returns true when the pill's visibility changed, which is only useful to
  /// tests — callers can ignore it.
  bool onScroll(ScrollMetrics metrics, {required double delta}) {
    // A list that does not scroll, or one at its top, always shows the pill.
    if (!metrics.hasContentDimensions ||
        metrics.maxScrollExtent <= 0 ||
        metrics.pixels <= metrics.minScrollExtent) {
      return _set(visible: true);
    }

    if (delta == 0) return false;

    // Reset the run as soon as the finger changes direction, so the threshold
    // measures this movement rather than the whole session.
    if (delta.sign != _travel.sign) _travel = 0;
    _travel += delta;

    if (_travel > threshold) return _set(visible: false);
    if (_travel < -threshold) return _set(visible: true);
    return false;
  }

  /// Brings the pill back unconditionally — on a tab change, or when leaving
  /// the list entirely.
  void show() => _set(visible: true);

  bool _set({required bool visible}) {
    _travel = visible ? 0 : _travel;
    if (state == visible) return false;
    state = visible;
    return true;
  }
}

final navVisibilityProvider = NotifierProvider<NavVisibility, bool>(
  NavVisibility.new,
);
