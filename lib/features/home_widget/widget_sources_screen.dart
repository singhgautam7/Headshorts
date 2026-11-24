import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/home_widget_bridge.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/app_header.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/features/home_widget/widget_sources.dart';
import 'package:headshorts/features/more/settings_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Subscribed sources the widget can show. Paused ones are left out: a
/// source that is switched off shows nothing wherever it is chosen.
/// Overridden in tests.
final widgetSourcesProvider = StreamProvider.autoDispose<List<SourceRow>>(
  (ref) => ref
      .watch(sourceRepositoryProvider)
      .watchAll()
      .map((all) => all.where((s) => s.enabled).toList()),
);

/// `/widget/:id` — which sources one widget shows. Also the widget's own
/// configure screen, where Back cancels the placement.
class WidgetSourcesScreen extends ConsumerStatefulWidget {
  const new(this.appWidgetId, {super.key});

  final int appWidgetId;

  @override
  ConsumerState<WidgetSourcesScreen> createState() =>
      _WidgetSourcesScreenState();
}

class _WidgetSourcesScreenState extends ConsumerState<WidgetSourcesScreen> {
  /// Null is "all sources".
  Set<int>? _selection;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await WidgetSources.read(prefs, widget.appWidgetId);
    if (mounted) {
      setState(() {
        _selection = saved;
        _loaded = true;
      });
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      // The configure activity's only route: leaving it cancels.
      unawaited(SystemNavigator.pop());
    }
  }

  Set<int> _ids(List<SourceRow> sources) => {for (final s in sources) s.id};

  void _toggleAll(List<SourceRow> sources, {required bool on}) =>
      setState(() => _selection = on ? null : _ids(sources));

  void _toggle(List<SourceRow> sources, int id, {required bool on}) {
    final next = {...(_selection ?? _ids(sources))};
    on ? next.add(id) : next.remove(id);
    // Covering everything is "all", so a source added later joins in.
    setState(() => _selection = next.containsAll(_ids(sources)) ? null : next);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await WidgetSources.write(prefs, widget.appWidgetId, _selection);
    final finished = await finishWidgetConfig(widget.appWidgetId);
    if (!finished && mounted) _back();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final sources = ref.watch(widgetSourcesProvider).value ?? const [];
    final loading = !_loaded || ref.watch(widgetSourcesProvider).isLoading;
    final none = _selection != null && _selection!.isEmpty;

    return PushedScreen(
      title: 'Widget sources',
      onBack: _back,
      footer: Padding(
        padding: const EdgeInsets.all(HsSpace.x4),
        child: HsButton(
          'Save',
          onPressed: loading || sources.isEmpty || none || _saving
              ? null
              : _save,
        ),
      ),
      child: loading
          ? const SizedBox.shrink()
          : sources.isEmpty
          ? Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.all(HsSpace.x5)
                    .copyWith(top: HsSpace.x5 + HeaderPage.insetOf(context)),
                child: Text(
                  'Choose some sources in HeadShorts',
                  style: HsType.bodySans.copyWith(color: palette.textSecondary),
                ),
              ),
            )
          : ListView.builder(
              itemCount: sources.length + 2,
              itemBuilder: (context, i) {
                if (i == 0) return HeaderPage.gap();
                final at = i - 1;
                if (at == 0) {
                  return _Row(
                    label: 'All sources',
                    value: _selection == null,
                    toggle: true,
                    onChanged: (on) => _toggleAll(sources, on: on),
                  );
                }
                final s = sources[at - 1];
                return _Row(
                  label: s.title,
                  value: _selection == null || _selection!.contains(s.id),
                  onChanged: (on) => _toggle(sources, s.id, on: on),
                );
              },
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    this.toggle = false,
  });

  final String label;
  final bool value;
  final bool toggle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Semantics(
      label: label,
      child: Pressable(
        kind: PressKind.row,
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: HsSize.rowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HsType.row.copyWith(color: palette.textPrimary),
                  ),
                ),
                if (toggle)
                  HsToggle(value: value, onChanged: onChanged)
                else
                  HsCheckbox(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `/widget` — the widgets placed on the home screen, each with its source
/// choice, or how to add one.
class WidgetsScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen>
    with WidgetsBindingObserver {
  List<int>? _placed;
  Map<int, bool> _chosen = {};
  bool _canPin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the launcher's own pin dialog: the list may have grown.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  Future<void> _load() async {
    final placed = await placedHomeWidgets();
    final pin = await canPinHomeWidget();
    final prefs = await SharedPreferences.getInstance();
    final chosen = <int, bool>{};
    for (final id in placed) {
      chosen[id] = await WidgetSources.read(prefs, id) != null;
    }
    if (mounted) {
      setState(() {
        _placed = placed;
        _chosen = chosen;
        _canPin = pin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final placed = _placed;
    return PushedScreen(
      title: 'Home screen widget',
      child: placed == null
          ? const SizedBox.shrink()
          : placed.isEmpty
          ? Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.all(HsSpace.x5)
                    .copyWith(top: HsSpace.x5 + HeaderPage.insetOf(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Put the latest headlines on your home screen. Touch and '
                      'hold an empty spot, choose Widgets, then HeadShorts.',
                      style: HsType.bodySans.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    if (_canPin) ...[
                      const SizedBox(height: HsSpace.x5),
                      HsButton(
                        'Add to home screen',
                        onPressed: () async {
                          await requestPinHomeWidget();
                          await _load();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            )
          : ListView.builder(
              itemCount: placed.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return HeaderPage.gap();
                final i = index - 1;
                return SettingsRow(
                  icon: Icons.widgets_outlined,
                  label: 'Headlines widget ${i + 1}',
                  sub: _chosen[placed[i]]! ? 'Chosen sources' : 'All sources',
                  onTap: () async {
                    await context.push('/widget/${placed[i]}');
                    await _load();
                  },
                );
              },
            ),
    );
  }
}
