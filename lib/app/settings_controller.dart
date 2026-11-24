import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/data/prefs/settings.dart';

/// Holds the reader's choices and writes them straight through.
class SettingsController extends Notifier<Settings> {
  @override
  Settings build() {
    final s = ref.watch(settingsStoreProvider).read();
    HsHaptics.enabled = s.haptics;
    return s;
  }

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

  Future<void> setMotionPreference(MotionPreference pref) =>
      _save(state.copyWith(motionPreference: pref));

  Future<void> setHaptics({required bool enabled}) {
    HsHaptics.enabled = enabled;
    return _save(state.copyWith(haptics: enabled));
  }

  /// The one-off device check behind Automatic motion: runs only while the
  /// class is unknown, and any failure counts as a normal phone.
  Future<void> checkDevice({Future<(int, bool)?> Function()? probe}) async {
    if (state.deviceClass != DeviceClass.unknown) return;
    var cls = DeviceClass.normal;
    try {
      final r = await (probe ?? _platformProbe)();
      if (r != null) cls = classifyDevice(ramMb: r.$1, lowRamFlag: r.$2);
    } on Object catch (_) {
      // No channel, a refusal, a bad reply: a normal phone.
    }
    if (!ref.mounted) return;
    await _save(state.copyWith(deviceClass: cls));
  }

  static Future<(int, bool)?> _platformProbe() async {
    final m = await const MethodChannel('headshorts/platform')
        .invokeMapMethod<String, Object?>('deviceMemory');
    final ram = m?['ramMb'];
    return ram is int ? (ram, m?['lowRam'] == true) : null;
  }

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
