import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/nav_visibility.dart';

/// Metrics for a list [extent] long, currently at [pixels].
ScrollMetrics _metrics({double pixels = 400, double extent = 2000}) =>
    FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: extent,
      pixels: pixels,
      viewportDimension: 800,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

void main() {
  late ProviderContainer container;
  NavVisibility notifier() => container.read(navVisibilityProvider.notifier);
  bool visible() => container.read(navVisibilityProvider);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts visible', () {
    expect(visible(), isTrue);
  });

  test('hides once a downward scroll passes the threshold', () {
    notifier().onScroll(_metrics(), delta: NavVisibility.threshold + 1);
    expect(visible(), isFalse);
  });

  test('ignores a micro-scroll, so it cannot flicker', () {
    for (var i = 0; i < 3; i++) {
      notifier().onScroll(_metrics(), delta: 1);
    }
    expect(visible(), isTrue);
  });

  test('comes back on an upward scroll', () {
    notifier()
      ..onScroll(_metrics(), delta: NavVisibility.threshold + 1)
      ..onScroll(_metrics(), delta: -NavVisibility.threshold - 1);
    expect(visible(), isTrue);
  });

  test('a change of direction restarts the threshold', () {
    // Scroll down hard, then a nudge back up that is under the threshold.
    notifier()
      ..onScroll(_metrics(), delta: 200)
      ..onScroll(_metrics(), delta: -2);
    expect(visible(), isFalse);
  });

  test('always shows at the top of the list', () {
    notifier()
      ..onScroll(_metrics(), delta: 200)
      ..onScroll(_metrics(pixels: 0), delta: -10);
    expect(visible(), isTrue);
  });

  test('always shows when the list does not scroll at all', () {
    notifier()
      ..onScroll(_metrics(), delta: 200)
      ..onScroll(_metrics(extent: 0, pixels: 0), delta: 200);
    expect(visible(), isTrue);
  });

  test('show() brings it back, for a tab change', () {
    notifier()
      ..onScroll(_metrics(), delta: 200)
      ..show();
    expect(visible(), isTrue);
  });

  test('is never left stranded: showing again always takes', () {
    final controller = notifier();
    for (var i = 0; i < 5; i++) {
      controller.onScroll(_metrics(), delta: 200);
    }
    expect(visible(), isFalse);
    controller.show();
    expect(visible(), isTrue);
  });
}
