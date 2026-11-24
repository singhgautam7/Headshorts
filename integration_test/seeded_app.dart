// The real app over the perf seed, for walking through by hand:
//   flutter build apk --profile --target-platform android-arm64 -t integration_test/seeded_app.dart
// AWAY_DAYS=30 starts it as if it had not been opened for that long.
import 'package:flutter/widgets.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_seed.dart';

// Zero without the define.
const _away = int.fromEnvironment('AWAY_DAYS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getInt('perfSeed') != _away + 1) {
    final db = HsDatabase();
    final at = DateTime.now().subtract(const Duration());
    await seedPerf(db, newest: at, fetchedAt: at);
    await db.close();
    await prefs.setBool('onboarded', true);
    await prefs.setInt('perfSeed', _away + 1);
  }
  await app.main();
}
