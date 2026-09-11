import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/sources/starter_set.dart';
import 'package:headshorts/features/sources/add_source_screen.dart';
import 'package:headshorts/features/sources/source_picker.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// The shipped starter set, offered as a list to pick from.
///
/// Small and static on purpose — it exists so a first run has something to
/// show, not as a directory to maintain.
class StarterSetScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<StarterSetScreen> createState() => _StarterSetScreenState();
}

class _StarterSetScreenState extends ConsumerState<StarterSetScreen> {
  late final Set<String> _chosen = starterSet
      .take(5)
      .map((s) => s.feedUrl)
      .toSet();
  bool _adding = false;

  Future<void> _add() async {
    setState(() => _adding = true);
    final repository = ref.read(sourceRepositoryProvider);
    for (final source in starterSet.where((s) => _chosen.contains(s.feedUrl))) {
      await repository.add(
        title: source.title,
        feedUrl: source.feedUrl,
        siteUrl: source.siteUrl,
        category: source.category,
        accent: source.accent,
      );
    }
    if (!mounted) return;
    unawaitedRefresh(ref);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final subscribed = (ref.watch(sourcesProvider).value ?? const [])
        .map((s) => s.feedUrl)
        .toSet();

    return PushedScreen(
      title: 'Starter set',
      onBack: () => context.pop(),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(
          HsSpace.x5,
          HsSpace.x4,
          HsSpace.x5,
          26,
        ),
        child: HsButton(
          _adding ? 'Adding…' : 'Add ${_chosen.length}',
          onPressed: _adding || _chosen.isEmpty ? null : _add,
        ),
      ),
      child: SourcePicker(
        sources: starterSet,
        chosen: _chosen,
        alreadySubscribed: subscribed,
        onToggle: (feedUrl) => setState(() {
          if (!_chosen.remove(feedUrl)) _chosen.add(feedUrl);
        }),
      ),
    );
  }
}
