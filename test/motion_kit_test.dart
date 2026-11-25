import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/motion/haptics.dart';
import 'package:headshorts/core/motion/motion_level.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('resolveMotionLevel', () {
    test('Expressive on a normal or unknown phone', () {
      for (final d in [DeviceClass.normal, DeviceClass.unknown]) {
        expect(resolveMotionLevel(d), MotionLevel.expressive);
      }
    });

    test('Subtle on a low-RAM phone', () {
      expect(resolveMotionLevel(DeviceClass.low), MotionLevel.subtle);
    });

    test('the phone removing animations wins over everything', () {
      for (final d in DeviceClass.values) {
        expect(resolveMotionLevel(d, systemOff: true), MotionLevel.off);
      }
    });
  });

  group('classifyDevice', () {
    test('under 3.5 GB or the low-RAM flag is low', () {
      expect(classifyDevice(ramMb: 2800), DeviceClass.low);
      expect(classifyDevice(ramMb: 3700), DeviceClass.normal);
      expect(classifyDevice(ramMb: 8000, lowRamFlag: true), DeviceClass.low);
      expect(classifyDevice(ramMb: null), DeviceClass.normal);
    });
  });

  group('SettingsController', () {
    Future<ProviderContainer> make() async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(
            SettingsStore(await SharedPreferences.getInstance()),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('checkDevice classifies once and then stays put', () async {
      final c = await make();
      var calls = 0;
      Future<(int, bool)?> probe() async {
        calls++;
        return (2800, false);
      }

      await c.read(settingsProvider.notifier).checkDevice(probe: probe);
      expect(c.read(settingsProvider).deviceClass, DeviceClass.low);
      expect(c.read(settingsProvider).motionLevel, MotionLevel.subtle);
      await c.read(settingsProvider.notifier).checkDevice(probe: probe);
      expect(calls, 1);
    });

    test('a failing probe is a normal phone, not a crash', () async {
      final c = await make();
      await c
          .read(settingsProvider.notifier)
          .checkDevice(probe: () async => throw StateError('no channel'));
      expect(c.read(settingsProvider).deviceClass, DeviceClass.normal);
    });

    test('haptics mirrors the setting', () async {
      final c = await make();
      await c.read(settingsProvider.notifier).setHaptics(enabled: false);
      expect(HsHaptics.enabled, isFalse);
      await c.read(settingsProvider.notifier).setHaptics(enabled: true);
      expect(HsHaptics.enabled, isTrue);
    });
  });
}
