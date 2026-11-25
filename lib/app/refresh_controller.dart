import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/feed/refresh_service.dart';

/// A reader who has been away longer than this is told, once, that the feeds
/// only carry recent items.
const awayThreshold = Duration(days: 3);

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
  /// Used on launch and on coming back to the app. A pull, or the refresh
  /// mark, always fetches — [refresh] itself never consults the cadence,
  /// because an ask is never quietly ignored.
  ///
  /// Staleness is the **oldest** success among sources that are working, not
  /// the newest: one freshly added source must not make the rest look fresh.
  /// A source that is failing is left out, or one dead feed would force a
  /// refresh on every resume.
  Future<void> refreshIfDue() async {
    final cadence = ref.read(settingsProvider).refreshCadence.interval;
    if (cadence == null) return;

    final sources = await ref.read(sourceRepositoryProvider).enabled();
    var working = sources.where((s) => s.failingSince == null).toList();
    // All of them failing is what being offline looks like, not a reason to
    // stop trying.
    if (working.isEmpty) {
      working = sources.where((s) => !s.isAbandoned).toList();
    }
    if (working.isEmpty) return;
    // A source never fetched is as stale as it gets.
    final stamps = [for (final s in working) s.lastFetchedAt]
      ..sort((a, b) => (a ?? DateTime(0)).compareTo(b ?? DateTime(0)));
    final oldest = stamps.first;
    if (oldest != null && DateTime.now().difference(oldest) < cadence) return;
    await _run(explicit: false);
  }

  /// The app came back to the foreground. A headless engine (a widget's
  /// background refresh) may have written to the file meanwhile, and drift
  /// only sees its own writes, so wake the streams first.
  Future<void> onResume() async {
    ref.read(databaseProvider).notifyExternalWrite();
    ref.invalidate(lastUpdatedProvider);
    await refreshIfDue();
  }

  /// Starts a refresh, or **joins** the one already running.
  ///
  /// Joining matters: onboarding awaits this before it will show the
  /// briefing, and returning early from a refresh that is still fetching
  /// would hand the reader an empty Today and call it caught up.
  Future<void> refresh() => _run(explicit: true);

  Future<void> _run({required bool explicit}) {
    final running = _inFlight;
    if (running != null && !running.isCompleted) return running.future;
    // Claimed before anything is awaited, so a second caller joins this run.
    final completer = Completer<void>();
    _inFlight = completer;
    unawaited(_begin(completer, explicit: explicit));
    return completer.future;
  }

  Future<void> _begin(
    Completer<void> completer, {
    required bool explicit,
  }) async {
    var away = false;
    try {
      away = await _wasAway();
    } on Object catch (e) {
      // Only decides a line of copy; it must never hold up the fetch.
      debugPrint('refresh: could not read the last fetch: $e');
    }

    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    unawaited(_subscription?.cancel());
    _subscription = ref
        .read(refreshServiceProvider)
        .refreshAll(explicit: explicit)
        .listen(
          (progress) {
            state = progress;
            if (progress.finished && away) {
              ref.read(awayNoticeProvider.notifier).show();
            }
          },
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
  }

  /// Whether the last fetch before this one was more than [awayThreshold]
  /// ago — a reader coming back after a long absence.
  Future<bool> _wasAway() async {
    final last = await _newestFetch(ref);
    return last != null && DateTime.now().difference(last) > awayThreshold;
  }
}

/// Whether to say, for this session, that the feeds only carry recent items.
///
/// Set after a refresh that followed a long absence. One quiet line, no count.
class AwayNotice extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
}

final awayNoticeProvider = NotifierProvider<AwayNotice, bool>(AwayNotice.new);

Future<DateTime?> _newestFetch(Ref ref) async {
  final sources = await ref.read(sourceRepositoryProvider).all();
  final stamps =
      sources.map((s) => s.lastFetchedAt).whereType<DateTime>().toList()
        ..sort();
  return stamps.lastOrNull;
}

final refreshProvider = NotifierProvider<RefreshController, RefreshProgress>(
  RefreshController.new,
);

/// When the last successful fetch happened, for Today's "updated 9:38".
final lastUpdatedProvider = FutureProvider<DateTime?>((ref) {
  // Only a completed run moves this, so it re-queries twice per refresh
  // rather than once per feed.
  ref.watch(refreshProvider.select((p) => p.finished));
  return _newestFetch(ref);
});
