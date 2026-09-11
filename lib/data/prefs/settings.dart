import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme choice, as offered on the More screen.
enum HsThemeChoice { amoled, white, system }

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

/// Everything the reader has chosen, in one immutable value.
@immutable
class Settings {
  const new({
    this.theme = HsThemeChoice.amoled,
    this.blurBehindNav = false,
    this.textSize = TextSizeStep.small,
    this.onboarded = false,
    this.aiProvider = 'Anthropic',
    this.aiOnRequestOnly = true,
    this.aiFullTextOnly = true,
  });

  final HsThemeChoice theme;

  /// Opaque by default — blur costs battery for no legibility gain.
  final bool blurBehindNav;
  final TextSizeStep textSize;
  final bool onboarded;

  /// Later-phase AI settings. The summariser itself is not built.
  final String aiProvider;
  final bool aiOnRequestOnly;
  final bool aiFullTextOnly;

  Settings copyWith({
    HsThemeChoice? theme,
    bool? blurBehindNav,
    TextSizeStep? textSize,
    bool? onboarded,
    String? aiProvider,
    bool? aiOnRequestOnly,
    bool? aiFullTextOnly,
  }) => Settings(
    theme: theme ?? this.theme,
    blurBehindNav: blurBehindNav ?? this.blurBehindNav,
    textSize: textSize ?? this.textSize,
    onboarded: onboarded ?? this.onboarded,
    aiProvider: aiProvider ?? this.aiProvider,
    aiOnRequestOnly: aiOnRequestOnly ?? this.aiOnRequestOnly,
    aiFullTextOnly: aiFullTextOnly ?? this.aiFullTextOnly,
  );
}

/// Persists [Settings]. Small enough that key-value storage is the right tool.
class SettingsStore {
  const new(this._prefs);

  final SharedPreferences _prefs;

  static const _theme = 'theme';
  static const _blur = 'blurBehindNav';
  static const _textSize = 'textSize';
  static const _onboarded = 'onboarded';
  static const _aiProvider = 'aiProvider';
  static const _aiOnRequest = 'aiOnRequestOnly';
  static const _aiFullText = 'aiFullTextOnly';

  Settings read() {
    const fallback = Settings();
    return Settings(
      theme:
          HsThemeChoice.values.asNameMap()[_prefs.getString(_theme)] ??
          fallback.theme,
      blurBehindNav: _prefs.getBool(_blur) ?? fallback.blurBehindNav,
      textSize:
          TextSizeStep.values.asNameMap()[_prefs.getString(_textSize)] ??
          fallback.textSize,
      onboarded: _prefs.getBool(_onboarded) ?? fallback.onboarded,
      aiProvider: _prefs.getString(_aiProvider) ?? fallback.aiProvider,
      aiOnRequestOnly: _prefs.getBool(_aiOnRequest) ?? fallback.aiOnRequestOnly,
      aiFullTextOnly: _prefs.getBool(_aiFullText) ?? fallback.aiFullTextOnly,
    );
  }

  Future<void> write(Settings s) async {
    await _prefs.setString(_theme, s.theme.name);
    await _prefs.setBool(_blur, s.blurBehindNav);
    await _prefs.setString(_textSize, s.textSize.name);
    await _prefs.setBool(_onboarded, s.onboarded);
    await _prefs.setString(_aiProvider, s.aiProvider);
    await _prefs.setBool(_aiOnRequest, s.aiOnRequestOnly);
    await _prefs.setBool(_aiFullText, s.aiFullTextOnly);
  }
}
