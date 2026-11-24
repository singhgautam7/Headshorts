import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Writes build/perf/results.json and a build-event count per widget type for
/// each `rebuilds_*` trace.
Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 25),
  responseDataCallback: (data) async {
    if (data == null) return;
    Directory('build/perf').createSync(recursive: true);
    const json = JsonEncoder.withIndent('  ');
    for (final e in data.entries) {
      if (e.key == 'results') {
        File('build/perf/results.json').writeAsStringSync(json.convert(e.value));
      } else if (e.key.startsWith('rebuilds_')) {
        final events = (e.value as Map<String, dynamic>)['traceEvents'] as List;
        final counts = <String, int>{};
        for (final ev in events.cast<Map<String, dynamic>>()) {
          if (ev['ph'] != 'B' && ev['ph'] != 'X') continue;
          final name = ev['name'] as String;
          counts[name] = (counts[name] ?? 0) + 1;
        }
        final top = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        File('build/perf/${e.key}.json').writeAsStringSync(
          json.convert({for (final t in top.take(80)) t.key: t.value}),
        );
      }
    }
  },
);
