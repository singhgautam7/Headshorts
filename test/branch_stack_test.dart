import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/shell.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The tab slide: pages side by side, a finger that follows, a warm tab that
/// is never Linger.
void main() {
  late SettingsStore store;
  late GoRouter router;
  var lingerBuilt = 0;
  const tabs = ['today', 'linger', 'sources', 'search', 'more'];

  setUp(() async {
    lingerBuilt = 0;
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    router = GoRouter(
      initialLocation: '/today',
      routes: [
        StatefulShellRoute(
          builder: (context, state, shell) => AppShell(shell),
          navigatorContainerBuilder: appBranchContainer,
          branches: [
            for (final tab in tabs)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/$tab',
                    builder: (context, state) => tab == 'linger'
                        ? _Counting(() => lingerBuilt++)
                        : _Page(tab),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  });

  Future<void> pump(WidgetTester tester) async {
    // A status bar and a gesture bar, as on a phone.
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 32, bottom: 24);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(
          theme: buildHsTheme(HsPalette.amoled),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double dx(WidgetTester tester, String tab) =>
      tester.getCenter(find.text('page:$tab')).dx;

  testWidgets('at rest only the active page is on stage', (tester) async {
    await pump(tester);
    expect(find.text('page:today'), findsOneWidget);
    expect(find.text('page:sources'), findsNothing);
    // Linger is not built until visited.
    expect(lingerBuilt, 0);
  });

  testWidgets('mid-slide both pages are side by side', (tester) async {
    await pump(tester);
    router.go('/sources');
    await tester.pump();
    await tester.pump(); // the clock starts after the frame that built it
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('page:today'), findsOneWidget);
    expect(find.text('page:sources'), findsOneWidget);
    // A far tab slides in from next door: one page apart, not two.
    final width = tester.getSize(find.byType(AppShell)).width;
    expect(dx(tester, 'sources') - dx(tester, 'today'), closeTo(width, 1));
    await tester.pumpAndSettle();
    expect(find.text('page:today'), findsNothing);
  });

  testWidgets('a tap mid-slide carries on from where the pages are', (
    tester,
  ) async {
    await pump(tester);
    router.go('/sources');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final before = dx(tester, 'sources');
    expect(before, greaterThan(0));

    router.go('/search');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    // Sources has not jumped to either end.
    expect((dx(tester, 'sources') - before).abs(), lessThan(40));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/search');
    expect(find.text('page:search'), findsOneWidget);
  });

  testWidgets('a short drag returns, and a peek builds nothing', (
    tester,
  ) async {
    await pump(tester);
    final rest = dx(tester, 'today');
    final gesture = await tester.startGesture(const Offset(300, 300));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump(const Duration(milliseconds: 300));
    // The page follows the finger, the neighbour's slot is empty (Linger has
    // not been visited, so nothing of it is built).
    expect(dx(tester, 'today'), lessThan(rest));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/today');
    expect(dx(tester, 'today'), closeTo(rest, 0.5));
    expect(lingerBuilt, 0);
  });

  testWidgets('a drag past half switches', (tester) async {
    await pump(tester);
    final width = tester.getSize(find.byType(AppShell)).width;
    final gesture = await tester.startGesture(const Offset(300, 300));
    await gesture.moveBy(Offset(-width * 0.7, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/linger');
  });

  testWidgets('a fling switches', (tester) async {
    await pump(tester);
    await tester.fling(find.byType(AppShell), const Offset(-100, 0), 1000);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/linger');
    expect(lingerBuilt, 1);
  });

  testWidgets('the page left behind is off stage, still, and keeps its place', (
    tester,
  ) async {
    await pump(tester);
    router.go('/linger');
    await tester.pumpAndSettle();
    router.go('/today');
    await tester.pumpAndSettle();

    final left = find.text('page:linger', skipOffstage: false);
    expect(left, findsOneWidget);
    expect(find.text('page:linger'), findsNothing);
    expect(TickerMode.valuesOf(tester.element(left)).enabled, isFalse);
    // Not hit-testable either: it is not on stage to be hit.
    expect(find.byType(Offstage, skipOffstage: false), findsWidgets);
    expect(lingerBuilt, 1, reason: 'kept, not rebuilt');
  });

  testWidgets('each page paints its own ground while two are on stage', (
    tester,
  ) async {
    await pump(tester);
    router.go('/linger');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final grounds = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(BranchStack),
            matching: find.byType(ColoredBox),
          ),
        )
        .map((b) => b.color)
        .toSet();
    expect(grounds, contains(HsPalette.amoled.lingerBackground));
    expect(grounds, contains(HsPalette.amoled.background));
  });
}

class _Page extends StatelessWidget {
  const new(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Center(child: Text('page:$name'));
}

class _Counting extends StatefulWidget {
  const new(this.onBuilt);

  final VoidCallback onBuilt;

  @override
  State<_Counting> createState() => _CountingState();
}

class _CountingState extends State<_Counting> {
  @override
  void initState() {
    super.initState();
    widget.onBuilt();
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('page:linger'));
}
