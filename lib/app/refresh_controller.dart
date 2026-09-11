import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/feed/refresh_service.dart';

/// Drives refreshes and reports their progress.
///
/// The app never waits on this: it opens from cache and this runs behind the
/// content. Only the first run blocks, in onboarding.
class RefreshController extends Notifier<RefreshProgress> {
  StreamSubscription<RefreshProgress>? _subscription;

  @override
  RefreshProgress build() {
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    return RefreshProgress.idle;
  }

  /// Starts a refresh, or joins the one already running.
  Future<void> refresh() {
    if (state.isRunning) return Future.value();
    final completer = Completer<void>();

    unawaited(_subscription?.cancel());
    _subscription = ref
        .read(refreshServiceProvider)
        .refreshAll()
        .listen(
          (progress) => state = progress,
          onDone: () {
            state = RefreshProgress(
              total: state.total,
              done: state.total,
              added: state.added,
            );
            if (!completer.isCompleted) completer.complete();
          },
          onError: (Object _) {
            // A refresh that cannot run at all is not an error the reader needs
            // to see; the cache is still there and the sources record their own
            // failures.
            state = RefreshProgress.idle;
            if (!completer.isCompleted) completer.complete();
          },
        );

    return completer.future;
  }
}

final refreshProvider = NotifierProvider<RefreshController, RefreshProgress>(
  RefreshController.new,
);

/// When the last successful fetch happened, for Today's "updated 9:38".
final lastUpdatedProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(refreshProvider);
  final sources = await ref.watch(sourceRepositoryProvider).all();
  final stamps =
      sources.map((s) => s.lastFetchedAt).whereType<DateTime>().toList()
        ..sort();
  return stamps.lastOrNull;
});
