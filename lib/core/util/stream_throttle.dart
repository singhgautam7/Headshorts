import 'dart:async';

/// At most one event per [window], always ending on the latest.
///
/// The first event goes straight through; events inside the window are
/// collapsed to the newest, which is emitted when the window closes. A refresh
/// writes to the database a hundred times in a few seconds, and a list that
/// re-queries and rebuilds for each of them is the jank this prevents.
///
/// Single-subscription, like the streams it is put on.
Stream<T> throttleLatest<T>(Stream<T> source, Duration window) {
  late final StreamController<T> out;
  StreamSubscription<T>? sub;
  Timer? timer;
  T? pending;
  var hasPending = false;

  void flush() {
    timer = null;
    if (!hasPending) return;
    final value = pending as T;
    pending = null;
    hasPending = false;
    out.add(value);
    timer = Timer(window, flush);
  }

  out = StreamController<T>(
    onListen: () {
      sub = source.listen(
        (value) {
          if (timer == null) {
            out.add(value);
            timer = Timer(window, flush);
          } else {
            pending = value;
            hasPending = true;
          }
        },
        onError: out.addError,
        onDone: () {
          timer?.cancel();
          if (hasPending) out.add(pending as T);
          unawaited(out.close());
        },
      );
    },
    onCancel: () {
      timer?.cancel();
      return sub?.cancel();
    },
  );
  return out.stream;
}
