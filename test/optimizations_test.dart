import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/widgets/nav_pill.dart';
import 'package:headshorts/core/widgets/pull_to_refresh.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/db/database.dart';

import 'support/harness.dart';

void main() {
  group('Database Indexes', () {
    test(
      'creates required performance indexes on articles and sources',
      () async {
        final db = HsDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        // Trigger beforeOpen by executing a simple query
        await db.customSelect('SELECT 1').get();

        final articleIndexes = await db
            .customSelect("PRAGMA index_list('articles')")
            .get();
        final indexNames = articleIndexes
            .map((row) => row.read<String>('name'))
            .toSet();

        expect(indexNames, contains('idx_articles_published_id'));
        expect(indexNames, contains('idx_articles_canonical_url'));
        expect(indexNames, contains('idx_articles_title_key'));
        expect(indexNames, contains('idx_articles_source_id'));

        final sourceIndexes = await db
            .customSelect("PRAGMA index_list('sources')")
            .get();
        final sourceIndexNames = sourceIndexes
            .map((row) => row.read<String>('name'))
            .toSet();
        expect(sourceIndexNames, contains('idx_sources_category_enabled'));
      },
    );
  });

  group('PullToRefresh.builder', () {
    testWidgets('lazily builds only visible items', (tester) async {
      var builtCount = 0;
      await pumpThemed(
        tester,
        PullToRefresh.builder(
          onRefresh: () async {},
          itemCount: 100,
          itemBuilder: (context, index) {
            builtCount++;
            return SizedBox(height: 100, child: Text('Item $index'));
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      // With viewport height ~780, only ~8-12 items should be built, not 100
      expect(builtCount, lessThan(20));
      expect(find.text('Item 99'), findsNothing);
    });
  });

  group('SubTabs interaction & auto-scroll', () {
    testWidgets('renders labels and supports selection', (tester) async {
      final selected = <int>[];
      await pumpThemed(
        tester,
        SubTabs(
          labels: const ['Latest', 'India', 'World', 'Tech', 'Business'],
          selectedIndex: 0,
          onSelected: selected.add,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Tech'), findsOneWidget);

      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();

      expect(selected, [3]);
    });
  });

  group('NavPill blur', () {
    testWidgets('includes BackdropFilter when blur is true', (tester) async {
      await pumpThemed(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: NavPill(
            destinations: NavPill.destinationsForApp,
            selectedIndex: 0,
            blur: true,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('omits BackdropFilter when blur is false', (tester) async {
      await pumpThemed(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: NavPill(
            destinations: NavPill.destinationsForApp,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
