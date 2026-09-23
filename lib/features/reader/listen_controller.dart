import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/data/feed/feed_parser.dart';
import 'package:headshorts/data/prefs/settings.dart';

/// One paragraph of the article as plain text, with where it starts in the
/// whole.
///
/// Read-aloud works on the **plain text**, not on the rendered HTML: the
/// engine reports a word as a character range in the string it was handed, so
/// the string it was handed has to be the string on screen. A listen view
/// stands in for the article body while it reads, and the rich rendering
/// comes straight back when it stops.
@immutable
class ListenParagraph {
  const new({required this.text, required this.offset});

  final String text;

  /// Where this paragraph starts in the whole article, for the progress bar.
  final int offset;

  int get length => text.length;
}

/// Splits an extracted body into the paragraphs read-aloud speaks.
///
/// One utterance per paragraph rather than one for the whole article: an
/// engine's word offsets are relative to the utterance, and a long article as
/// a single utterance puts every offset thousands of characters out and makes
/// pausing coarse. A paragraph is also the natural unit to scroll to.
List<ListenParagraph> listenParagraphs(String html) {
  final out = <ListenParagraph>[];
  var offset = 0;

  // `blockText`, not `plainText`: the latter collapses the whole document
  // into one line, which would make the article a single utterance and the
  // "paragraph being read" the entire article.
  for (final block in FeedParser.blockText(html)) {
    if (block.length < 2) continue;
    out.add(ListenParagraph(text: block, offset: offset));
    offset += block.length + 1;
  }
  return out;
}

/// Where in the article the engine currently is.
@immutable
class ListenState {
  const new({
    this.paragraphs = const [],
    this.index = 0,
    this.wordStart = 0,
    this.wordEnd = 0,
    this.playing = false,
    this.active = false,
    this.unsupported,
  });

  final List<ListenParagraph> paragraphs;

  /// Which paragraph is being spoken.
  final int index;

  /// The current word, as a range inside that paragraph.
  final int wordStart;
  final int wordEnd;

  final bool playing;

  /// The listen bar is up. Distinct from [playing]: paused is still active,
  /// and the current sentence keeps its wash so the place is never lost.
  final bool active;

  /// Set when the phone has no voice for this article's language. The Reader
  /// shows the explaining card rather than silently doing nothing.
  final String? unsupported;

  ListenParagraph? get current =>
      index >= 0 && index < paragraphs.length ? paragraphs[index] : null;

  int get totalChars => paragraphs.fold(0, (sum, p) => sum + p.length + 1);

  int get spokenChars => (current?.offset ?? totalChars) + wordEnd;

  double get progress {
    final total = totalChars;
    return total == 0 ? 0 : (spokenChars / total).clamp(0.0, 1.0);
  }

  /// The sentence the current word falls in, as a range in the paragraph.
  ///
  /// The design washes the sentence and solid-fills the word; a sentence is
  /// what a listener has actually just heard, so it is the right unit to
  /// keep in view.
  (int, int) get sentenceRange {
    final text = current?.text;
    if (text == null || text.isEmpty) return (0, 0);
    var start = 0;
    for (var i = 0; i < wordStart && i < text.length; i++) {
      if ('.!?।'.contains(text[i])) start = i + 1;
    }
    var end = text.length;
    for (var i = wordEnd.clamp(0, text.length); i < text.length; i++) {
      if ('.!?।'.contains(text[i])) {
        end = i + 1;
        break;
      }
    }
    while (start < text.length && text[start] == ' ') {
      start++;
    }
    return (start, end);
  }

  ListenState copyWith({
    List<ListenParagraph>? paragraphs,
    int? index,
    int? wordStart,
    int? wordEnd,
    bool? playing,
    bool? active,
    String? unsupported,
    bool clearUnsupported = false,
  }) => ListenState(
    paragraphs: paragraphs ?? this.paragraphs,
    index: index ?? this.index,
    wordStart: wordStart ?? this.wordStart,
    wordEnd: wordEnd ?? this.wordEnd,
    playing: playing ?? this.playing,
    active: active ?? this.active,
    unsupported: clearUnsupported ? null : (unsupported ?? this.unsupported),
  );
}

/// Read-aloud, on the phone's own speech engine.
///
/// Nothing leaves the device: this is the same engine TalkBack uses, given a
/// string. There is no network call, no account and no audio file.
///
/// The engine is created on the first listen and disposed when the Reader
/// closes, so an app that is not reading aloud holds no speech resources.
class ListenController extends Notifier<ListenState> {
  new(this.language);

  /// The article's language tag, which is what the engine is asked for.
  final String language;

  FlutterTts? _tts;
  var _stopping = false;

  @override
  ListenState build() {
    ref.onDispose(() {
      _stopping = true;
      unawaited(_tts?.stop());
    });
    return const ListenState();
  }

  /// Every voice the engine has for this article's language.
  ///
  /// An engine that offers none, or a platform that has none, is not a
  /// failure: the sheet says the default voice will read and moves on.
  Future<List<Map<String, String>>> voices() async {
    try {
      final engine = await _engine();
      final all = (await engine.getVoices as List<dynamic>?) ?? const [];
      final tag = language.split('-').first.toLowerCase();
      return [
            for (final voice in all)
              if (voice is Map)
                {
                  for (final entry in voice.entries)
                    entry.key.toString(): entry.value.toString(),
                },
          ]
          .where((v) => (v['locale'] ?? '').toLowerCase().startsWith(tag))
          .toList();
    } on Object catch (_) {
      return const [];
    }
  }

  Future<FlutterTts> _engine() async {
    final existing = _tts;
    if (existing != null) return existing;

    final engine = FlutterTts()
      ..setStartHandler(() {
        if (!_stopping) state = state.copyWith(playing: true);
      })
      ..setCompletionHandler(_next)
      ..setCancelHandler(() => state = state.copyWith(playing: false))
      ..setPauseHandler(() => state = state.copyWith(playing: false))
      ..setContinueHandler(() => state = state.copyWith(playing: true))
      ..setErrorHandler((_) => _next())
      ..setProgressHandler((text, start, end, word) {
        if (_stopping) return;
        state = state.copyWith(wordStart: start, wordEnd: end);
      });

    // The whole loop depends on this: without it `speak` returns straight
    // away and the completion handler is the only thing that advances, which
    // on some engines never fires for a queued utterance.
    //
    // Guarded because every call here crosses to the platform, and a device
    // with no speech engine at all — or a test, which has no platform — must
    // leave the Reader working rather than throwing out of a button tap.
    try {
      await engine.awaitSpeakCompletion(true);
    } on Object catch (_) {}
    return _tts = engine;
  }

  /// Whether the engine can read this article at all.
  ///
  /// Asked before anything is spoken, so an unsupported language is a stated
  /// reason rather than a button that does nothing.
  Future<bool> isSupported() async {
    try {
      final engine = await _engine();
      final available = await engine.isLanguageAvailable(language);
      if (available == true) return true;
      // Some engines only recognise the full tag, so a bare 'hi' is checked
      // against what they actually list.
      final languages =
          (await engine.getLanguages as List<dynamic>?) ?? const [];
      final tag = language.split('-').first.toLowerCase();
      return languages.any((l) => l.toString().toLowerCase().startsWith(tag));
    } on Object catch (_) {
      return false;
    }
  }

  /// Starts reading [html] from the top, or reports why it cannot.
  Future<void> start(String html, {String? unsupportedMessage}) async {
    final paragraphs = listenParagraphs(html);
    if (paragraphs.isEmpty) return;

    if (!await isSupported()) {
      state = state.copyWith(
        active: false,
        playing: false,
        unsupported: unsupportedMessage ?? 'no voice',
      );
      return;
    }

    _stopping = false;
    state = ListenState(paragraphs: paragraphs, active: true);
    await _applyPreferences();
    await _speakCurrent();
  }

  Future<void> _applyPreferences() async {
    final engine = await _engine();
    final settings = ref.read(settingsProvider);
    await engine.setLanguage(language);
    await engine.setSpeechRate(_engineRate(settings.speechRate));
    final voice = settings.voiceByLanguage[language.split('-').first];
    if (voice != null) {
      await engine.setVoice({'name': voice, 'locale': language});
    }
  }

  /// flutter_tts takes a platform rate, not a multiplier: on Android 0.5 is
  /// normal speech, so the reader's 1.0× has to land there.
  static double _engineRate(SpeechRate rate) =>
      (rate.multiplier * 0.5).clamp(0.0, 1.0);

  Future<void> _speakCurrent() async {
    final paragraph = state.current;
    if (paragraph == null) {
      await stop();
      return;
    }
    final engine = await _engine();
    state = state.copyWith(playing: true, wordStart: 0, wordEnd: 0);
    await engine.speak(paragraph.text);
  }

  void _next() {
    if (_stopping || !state.active) return;
    if (state.index + 1 >= state.paragraphs.length) {
      unawaited(stop());
      return;
    }
    state = state.copyWith(index: state.index + 1, wordStart: 0, wordEnd: 0);
    unawaited(_speakCurrent());
  }

  Future<void> pause() async {
    final engine = await _engine();
    state = state.copyWith(playing: false);
    // Not every engine implements pause; stopping mid-paragraph and
    // restarting it on resume is the fallback, and losing at most one
    // paragraph is better than a control that does nothing.
    final paused = await engine.pause();
    if (paused != 1) await engine.stop();
  }

  Future<void> resume() async {
    if (state.playing) return;
    await _applyPreferences();
    await _speakCurrent();
  }

  Future<void> stop() async {
    _stopping = true;
    await _tts?.stop();
    _stopping = false;
    state = state.copyWith(playing: false, active: false);
  }

  /// Silence, without touching state.
  ///
  /// What the Reader calls on its way out and when the app is backgrounded.
  /// Separate from [stop] because by then the widget is going and the
  /// provider may already have been disposed — writing `state` there throws,
  /// and the one thing that must still happen is the voice stopping.
  ///
  /// The engine keeps speaking on its own thread until it is told otherwise:
  /// dropping every reference to it does **not** stop it, which is why this
  /// is an explicit call rather than something left to `onDispose`.
  void shutdown() {
    _stopping = true;
    unawaited(_tts?.stop());
  }

  /// A rate or voice change while it is reading restarts the paragraph, which
  /// is the only way an engine will take the new setting mid-article.
  Future<void> reapply() async {
    if (!state.active) return;
    if (!state.playing) {
      await _applyPreferences();
      return;
    }
    await _tts?.stop();
    await _applyPreferences();
    await _speakCurrent();
  }

  void dismissUnsupported() => state = state.copyWith(clearUnsupported: true);
}

final listenProvider = NotifierProvider.autoDispose
    .family<ListenController, ListenState, String>(ListenController.new);

/// Whether the phone can read this language aloud, resolved in the
/// background.
///
/// Auto-dispose, like the controller it asks: a provider that outlives the
/// Reader would hold the [ListenController] alive with it, and with it the
/// speech engine.
///
/// Asking the engine is a round trip to the platform, so it is not done on
/// the tap that opens the overflow menu — a menu that waits for the speech
/// engine before it appears is a menu that feels broken. The answer arrives
/// on its own and the menu carries the reason the next time it opens; until
/// then Listen is offered and explains itself if it cannot run.
final listenSupportedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, language) => ref.watch(listenProvider(language).notifier).isSupported(),
);
