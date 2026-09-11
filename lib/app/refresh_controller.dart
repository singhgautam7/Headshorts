import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/data/feed/refresh_service.dart';

/// Drives refreshes and reports their progress.
///
/// The app never waits on this: it opens from cache and this runs behind the
/// content. Only the first run blocks, in onboarding.
class RefreshController extends Notifier<RefreshProgress> {
  StreamSubscription<RefreshProgress>? _subscription;
  Completer<void>? _inFlight;

  @override
  RefreshProgress build() {
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    return RefreshProgress.idle;
  }

  /// Refreshes only if the cache is staler than the reader's chosen cadence.
  ///
  /// Used on launch and on returning to Today. A pull, or the refresh mark,
  /// always fetches — [refresh] itself never consults the cadence, because an
  /// explicit ask should never be quietly ignored.
  Future<void> refreshIfDue() async {
    final cadence = ref.read(settingsProvider).refreshCadence.interval;
    if (cadence == null) return;

    final last = await ref.read(lastUpdatedProvider.future);
    if (last != null && DateTime.now().difference(last) < cadence) return;
    await refresh();
  }

  /// Starts a refresh, or **joins** the one already running.
  ///
  /// Joining matters: onboarding awaits this before it will show the
  /// briefing, and returning early from a refresh that is still fetching
  /// would hand the reader an empty Today and call it caught up.
  Future<void> refresh() {
    final running = _inFlight;
    if (running != null && !running.isCompleted) return running.future;

    final completer = Completer<void>();
    _inFlight = completer;

    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    unawaited(_subscription?.cancel());
    _subscription = ref
        .read(refreshServiceProvider)
        .refreshAll()
        .listen(
          (progress) => state = progress,
          onDone: finish,
          onError: (Object _) {
            // A refresh that cannot run at all is not an error the reader
            // needs to see; the cache is still there and the sources record
            // their own failures. It still counts as an attempt, so Today
            // stops waiting and shows what it has.
            state = RefreshProgress(
              total: state.total,
              done: state.total,
              added: state.added,
              finished: true,
            );
            finish();
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
  // Only a completed run moves this, so it re-queries twice per refresh
  // rather than once per feed.
  ref.watch(refreshProvider.select((p) => p.finished));
  final sources = await ref.watch(sourceRepositoryProvider).all();
  final stamps =
      sources.map((s) => s.lastFetchedAt).whereType<DateTime>().toList()
        ..sort();
  return stamps.lastOrNull;
});
