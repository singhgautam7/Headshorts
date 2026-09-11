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

  Future<void> setTheme(HsThemeChoice theme) =>
      _save(state.copyWith(theme: theme));

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

  Future<void> setAiProvider(String provider) =>
      _save(state.copyWith(aiProvider: provider));

  Future<void> setAiOnRequestOnly({required bool enabled}) =>
      _save(state.copyWith(aiOnRequestOnly: enabled));

  Future<void> setAiFullTextOnly({required bool enabled}) =>
      _save(state.copyWith(aiFullTextOnly: enabled));
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);
