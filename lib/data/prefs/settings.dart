import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/tokens/theme_family.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where a link goes when the reader taps it.
enum LinkOpenMode {
  /// A Custom Tab over the app — the reader comes straight back.
  inApp,

  /// The reader's own browser, with their extensions and their session.
  browser;

  String get label => switch (this) {
    LinkOpenMode.inApp => 'In the app',
    LinkOpenMode.browser => 'In my browser',
  };
}

/// How often the app checks for new items on its own.
///
/// The app refreshes on launch and on a pull; this only decides how stale the
/// cache has to be before a launch bothers to fetch. There is no background
/// polling and no notification.
enum RefreshCadence {
  manual(null),
  hourly(Duration(hours: 1)),
  fourHourly(Duration(hours: 4)),
  daily(Duration(days: 1));

  new(this.interval);

  /// Null means "only when I ask".
  final Duration? interval;

  String get label => switch (this) {
    RefreshCadence.manual => 'Only when I ask',
    RefreshCadence.hourly => 'Every hour',
    RefreshCadence.fourHourly => 'Every four hours',
    RefreshCadence.daily => 'Once a day',
  };
}

/// Reader body size. The slider offsets the system setting rather than
/// overriding it, so a reader who has already enlarged text keeps that.
enum TextSizeStep {
  smallest(15),
  small(17),
  medium(19),
  large(22),
  largest(25);

  new(this.fontSize);

  final double fontSize;

  String get label => switch (this) {
    TextSizeStep.smallest => 'Smallest',
    TextSizeStep.small => 'Small',
    TextSizeStep.medium => 'Medium',
    TextSizeStep.large => 'Large',
    TextSizeStep.largest => 'Largest',
  };
}

/// How much of each item a list shows.
///
/// One setting, read by Headlines, Search and Bookmarks alike: a reader who
/// asks for Small has asked for Small everywhere. The button that changes it
/// lives only on Headlines.
enum ListSize {
  /// The v1 card, unchanged: standfirst and image, about three a screen.
  large,

  /// Headline and thumbnail, clamped to three lines. About seven.
  medium,

  /// Headline only, two lines, the source run in at the start. Twelve or more.
  small;

  String get label => switch (this) {
    ListSize.large => 'Large',
    ListSize.medium => 'Medium',
    ListSize.small => 'Small',
  };

  String get description => switch (this) {
    ListSize.large => 'Standfirst and image · about 3 a screen',
    ListSize.medium => 'Headline and thumbnail · about 7',
    ListSize.small => 'Headline only · 12 or more',
  };
}

/// Read-aloud speed. The board's five steps, not a slider: a rate is a thing
/// you pick once, and five values do not need continuous control.
enum SpeechRate {
  slowest(0.8),
  slow(1),
  medium(1.2),
  fast(1.5),
  fastest(2);

  new(this.multiplier);

  /// Relative to the engine's own normal rate.
  final double multiplier;

  String get label =>
      '${multiplier == multiplier.roundToDouble() ? multiplier.toStringAsFixed(1) : multiplier}×';

  /// Spoken in full, because "1.2 ×" is not a phrase.
  String get spokenLabel => '$multiplier times';
}

/// Everything the reader has chosen, in one immutable value.
@immutable
class Settings {
  const new({
    this.familyId = 'paper',
    this.themeMode = ThemeMode.dark,
    this.amoled = true,
    this.blurBehindNav = false,
    this.textSize = TextSizeStep.small,
    this.onboarded = false,
    this.linkOpenMode = LinkOpenMode.inApp,
    this.refreshCadence = RefreshCadence.hourly,
    this.maxConsecutivePerSource = 0,
    this.listSize = ListSize.large,
    this.speechRate = SpeechRate.slow,
    this.highlightWords = true,
    this.voiceByLanguage = const {},
  });

  /// Which [ThemeFamily] is in force; unknown ids fall back to the board's.
  final String familyId;
  final ThemeMode themeMode;

  /// True black while dark is in effect. A toggle, not a mode.
  final bool amoled;

  ThemeFamily get family => ThemeFamily.byId(familyId);

  /// Opaque by default — blur costs battery for no legibility gain.
  final bool blurBehindNav;
  final TextSizeStep textSize;
  final bool onboarded;

  final LinkOpenMode linkOpenMode;
  final RefreshCadence refreshCadence;

  /// At most this many items in a row from one source in a merged list.
  /// Zero leaves the order strictly chronological, which is the default.
  ///
  /// Fairness, not ranking: nothing is dropped or scored, an over-represented
  /// source is simply moved down a place.
  final int maxConsecutivePerSource;

  /// Shared by Headlines, Search and Bookmarks.
  final ListSize listSize;

  final SpeechRate speechRate;

  /// Following along as it reads. Never the only cue to position — the
  /// progress bar and the time are — so it can simply be switched off.
  final bool highlightWords;

  /// The chosen voice per language tag, by the engine's own voice name. Per
  /// language, because a voice picked for English says nothing about Hindi.
  final Map<String, String> voiceByLanguage;

  Settings copyWith({
    String? familyId,
    ThemeMode? themeMode,
    bool? amoled,
    bool? blurBehindNav,
    TextSizeStep? textSize,
    bool? onboarded,
    LinkOpenMode? linkOpenMode,
    RefreshCadence? refreshCadence,
    int? maxConsecutivePerSource,
    ListSize? listSize,
    SpeechRate? speechRate,
    bool? highlightWords,
    Map<String, String>? voiceByLanguage,
  }) => Settings(
    familyId: familyId ?? this.familyId,
    themeMode: themeMode ?? this.themeMode,
    amoled: amoled ?? this.amoled,
    blurBehindNav: blurBehindNav ?? this.blurBehindNav,
    textSize: textSize ?? this.textSize,
    onboarded: onboarded ?? this.onboarded,
    linkOpenMode: linkOpenMode ?? this.linkOpenMode,
    refreshCadence: refreshCadence ?? this.refreshCadence,
    maxConsecutivePerSource:
        maxConsecutivePerSource ?? this.maxConsecutivePerSource,
    listSize: listSize ?? this.listSize,
    speechRate: speechRate ?? this.speechRate,
    highlightWords: highlightWords ?? this.highlightWords,
    voiceByLanguage: voiceByLanguage ?? this.voiceByLanguage,
  );
}

/// Persists [Settings]. Small enough that key-value storage is the right tool.
class SettingsStore {
  const new(this._prefs);

  final SharedPreferences _prefs;

  static const _familyId = 'familyId';
  static const _themeMode = 'themeMode';
  static const _amoled = 'amoled';

  /// The pre-family setting: `amoled` / `white` / `system`. Read once so an
  /// existing install keeps its look, never written again.
  static const _legacyTheme = 'theme';
  static const _blur = 'blurBehindNav';
  static const _textSize = 'textSize';
  static const _onboarded = 'onboarded';
  static const _maxRun = 'maxConsecutivePerSource';
  static const _linkMode = 'linkOpenMode';
  static const _cadence = 'refreshCadence';
  static const _listSize = 'listSize';
  static const _speechRate = 'speechRate';
  static const _highlight = 'highlightWords';
  static const _voices = 'voiceByLanguage';

  Settings read() {
    const fallback = Settings();
    return Settings(
      familyId: _prefs.getString(_familyId) ?? fallback.familyId,
      themeMode:
          ThemeMode.values.asNameMap()[_prefs.getString(_themeMode)] ??
          switch (_prefs.getString(_legacyTheme)) {
            'white' => ThemeMode.light,
            'system' => ThemeMode.system,
            _ => fallback.themeMode,
          },
      amoled: _prefs.getBool(_amoled) ?? fallback.amoled,
      blurBehindNav: _prefs.getBool(_blur) ?? fallback.blurBehindNav,
      textSize:
          TextSizeStep.values.asNameMap()[_prefs.getString(_textSize)] ??
          fallback.textSize,
      onboarded: _prefs.getBool(_onboarded) ?? fallback.onboarded,
      linkOpenMode:
          LinkOpenMode.values.asNameMap()[_prefs.getString(_linkMode)] ??
          fallback.linkOpenMode,
      refreshCadence:
          RefreshCadence.values.asNameMap()[_prefs.getString(_cadence)] ??
          fallback.refreshCadence,
      maxConsecutivePerSource:
          _prefs.getInt(_maxRun) ?? fallback.maxConsecutivePerSource,
      listSize:
          ListSize.values.asNameMap()[_prefs.getString(_listSize)] ??
          fallback.listSize,
      speechRate:
          SpeechRate.values.asNameMap()[_prefs.getString(_speechRate)] ??
          fallback.speechRate,
      highlightWords: _prefs.getBool(_highlight) ?? fallback.highlightWords,
      // A flat "tag=voice" list rather than JSON: nothing else in the app
      // speaks JSON, and a map of a dozen entries does not start now.
      voiceByLanguage: {
        for (final pair in _prefs.getStringList(_voices) ?? const <String>[])
          if (pair.indexOf('=') > 0)
            pair.substring(0, pair.indexOf('=')): pair.substring(
              pair.indexOf('=') + 1,
            ),
      },
    );
  }

  Future<void> write(Settings s) async {
    await _prefs.setString(_familyId, s.familyId);
    await _prefs.setString(_themeMode, s.themeMode.name);
    await _prefs.setBool(_amoled, s.amoled);
    await _prefs.setBool(_blur, s.blurBehindNav);
    await _prefs.setString(_textSize, s.textSize.name);
    await _prefs.setBool(_onboarded, s.onboarded);
    await _prefs.setInt(_maxRun, s.maxConsecutivePerSource);
    await _prefs.setString(_linkMode, s.linkOpenMode.name);
    await _prefs.setString(_cadence, s.refreshCadence.name);
    await _prefs.setString(_listSize, s.listSize.name);
    await _prefs.setString(_speechRate, s.speechRate.name);
    await _prefs.setBool(_highlight, s.highlightWords);
    await _prefs.setStringList(_voices, [
      for (final entry in s.voiceByLanguage.entries)
        '${entry.key}=${entry.value}',
    ]);
  }
}
