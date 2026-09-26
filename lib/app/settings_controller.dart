import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/prefs/settings.dart';

/// Holds the reader's choices and writes them straight through.
class SettingsController extends Notifier<Settings> {
  @override
  Settings build() => ref.watch(settingsStoreProvider).read();

  Future<void> _save(Settings next) async {
    state = next;
    await ref.read(settingsStoreProvider).write(next);
  }

  Future<void> setFamily(String id) => _save(state.copyWith(familyId: id));

  Future<void> setThemeMode(ThemeMode mode) =>
      _save(state.copyWith(themeMode: mode));

  Future<void> setAmoled({required bool value}) =>
      _save(state.copyWith(amoled: value));

  Future<void> setBlurBehindNav({required bool enabled}) =>
      _save(state.copyWith(blurBehindNav: enabled));

  Future<void> setTextSize(TextSizeStep step) =>
      _save(state.copyWith(textSize: step));

  Future<void> completeOnboarding() => _save(state.copyWith(onboarded: true));

  Future<void> setLinkOpenMode(LinkOpenMode mode) =>
      _save(state.copyWith(linkOpenMode: mode));

  Future<void> setRefreshCadence(RefreshCadence cadence) =>
      _save(state.copyWith(refreshCadence: cadence));

  Future<void> setMaxConsecutivePerSource(int max) =>
      _save(state.copyWith(maxConsecutivePerSource: max));

  Future<void> setListSize(ListSize size) =>
      _save(state.copyWith(listSize: size));

  Future<void> setSpeechRate(SpeechRate rate) =>
      _save(state.copyWith(speechRate: rate));

  Future<void> setHighlightWords({required bool enabled}) =>
      _save(state.copyWith(highlightWords: enabled));

  Future<void> setSearchTheWeb({required bool enabled}) =>
      _save(state.copyWith(searchTheWeb: enabled));

  /// Remembers the voice for one language, leaving the others alone.
  Future<void> setVoice(String language, String voiceName) => _save(
    state.copyWith(
      voiceByLanguage: {...state.voiceByLanguage, language: voiceName},
    ),
  );
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);
