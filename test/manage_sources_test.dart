import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/sources/source_catalog.dart';
import 'package:headshorts/features/sources/sources_controller.dart';

/// Sources shows the same list the onboarding picker showed — the whole
/// catalog — with the reader's own additions folded in, so the place they
/// chose sources is the place they change them.
void main() {
  late HsDatabase db;
  late SourceRepository sources;
  late ProviderContainer container;
  late SourceCatalog catalog;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = HsDatabase.forTesting(NativeDatabase.memory());
    sources = SourceRepository(db);
    catalog = SourceCatalog.parse(
      File(SourceCatalog.assetPath).readAsStringSync(),
    );
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sourceCatalogProvider.overrideWith((ref) async => catalog),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() => db.close());

  /// Reads the merged list, holding listeners so the streams behind it emit.
  Future<Map<String, List<SourceEntry>>> listing() async {
    final subs = [
      container.listen(sourceCatalogProvider, (_, _) {}),
      container.listen(manageableSourcesProvider, (_, _) {}),
    ];
    await container.read(sourceCatalogProvider.future);
    // Let the subscription and unseen streams deliver.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final result = container.read(manageableSourcesProvider);
    for (final sub in subs) {
      sub.close();
    }
    return result;
  }

  int total(Map<String, List<SourceEntry>> grouped) =>
      grouped.values.fold(0, (sum, list) => sum + list.length);

  test('lists the whole catalog before anything is subscribed', () async {
    final grouped = await listing();

    expect(total(grouped), catalog.sources.length);
    expect(
      grouped.values.expand((e) => e).every((e) => !e.isSubscribed),
      isTrue,
    );
  });

  test('a subscribed source shows its state, and is not duplicated', () async {
    final entry = catalog.sources.firstWhere((s) => s.title == 'The Hindu');
    await sources.add(
      title: entry.title,
      feedUrl: entry.feedUrl,
      category: entry.category,
      accent: entry.accent,
    );

    final grouped = await listing();
    final rows = grouped.values
        .expand((e) => e)
        .where((e) => e.title == 'The Hindu')
        .toList();

    expect(rows, hasLength(1), reason: 'catalog and subscription are one row');
    expect(rows.single.isSubscribed, isTrue);
    expect(rows.single.isOn, isTrue);
    expect(rows.single.state, 'caught up');
    expect(total(grouped), catalog.sources.length);
  });

  test('a paused source says so and stays in the list', () async {
    final entry = catalog.sources.first;
    final id = await sources.add(
      title: entry.title,
      feedUrl: entry.feedUrl,
      category: entry.category,
      accent: entry.accent,
    );
    await sources.setEnabled(id, enabled: false);

    final row = (await listing()).values
        .expand((e) => e)
        .firstWhere((e) => e.feedUrl == entry.feedUrl);

    expect(row.isSubscribed, isTrue);
    expect(row.isOn, isFalse);
    expect(row.state, 'paused');
  });

  test(
    'a source the reader added themselves appears in its category',
    () async {
      await sources.add(
        title: 'A Personal Blog',
        feedUrl: 'https://example.com/blog/feed',
        category: 'Culture',
      );

      final grouped = await listing();

      expect(total(grouped), catalog.sources.length + 1);
      expect(
        grouped['Culture']!.map((e) => e.title),
        contains('A Personal Blog'),
      );
    },
  );

  test(
    'recategorising a catalog source moves it, not its catalog entry',
    () async {
      final entry = catalog.sources.firstWhere((s) => s.category == 'India');
      final id = await sources.add(
        title: entry.title,
        feedUrl: entry.feedUrl,
        category: entry.category,
        accent: entry.accent,
      );
      await sources.setCategory(id, 'Home');

      final grouped = await listing();

      expect(grouped['Home']!.map((e) => e.title), contains(entry.title));
      expect(
        grouped['India']?.map((e) => e.title) ?? const <String>[],
        isNot(contains(entry.title)),
      );
      expect(total(grouped), catalog.sources.length);
    },
  );

  group('search', () {
    test('narrows by name', () async {
      container.read(sourcesQueryProvider.notifier).set('guardian');
      final grouped = await listing();

      expect(
        grouped.values.expand((e) => e).map((e) => e.title),
        contains('The Guardian'),
      );
      expect(total(grouped), lessThan(catalog.sources.length));
    });

    test('narrows by category', () async {
      container.read(sourcesQueryProvider.notifier).set('science');
      final grouped = await listing();

      expect(grouped.keys, ['Science']);
    });

    test(
      'an unmatched query leaves the list empty, for the fallback',
      () async {
        container.read(sourcesQueryProvider.notifier).set('zzzz nothing');
        expect(await listing(), isEmpty);
      },
    );
  });
}
