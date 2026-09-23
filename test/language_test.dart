import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/language.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/db/source_repository.dart';
import 'package:headshorts/data/sources/opml.dart';
import 'package:headshorts/data/sources/source_catalog.dart';

void main() {
  group('a language tag', () {
    test('names itself in its own script and in English', () {
      expect(HsLanguage.of('hi').endonym, 'हिन्दी');
      expect(HsLanguage.of('hi').englishName, 'Hindi');
      expect(HsLanguage.of('hi').code, 'HI');
    });

    test('is never null, even for a language we have not met', () {
      // Hiding an unknown language would hide the sources filed under it.
      final unknown = HsLanguage.of('xx');
      expect(unknown.code, 'XX');
      expect(unknown.endonym, isNotEmpty);
    });

    test('ignores a region suffix', () {
      expect(HsLanguage.of('en-GB').tag, 'en');
      expect(HsLanguage.of('HI-IN').code, 'HI');
    });
  });

  group('script detection', () {
    test('recognises the Indic scripts the catalog carries', () {
      for (final sample in [
        'दिल्ली मेट्रो', // Devanagari
        'தமிழ்', // Tamil
        'తెలుగు', // Telugu
        'বাংলা', // Bengali
        'ಕನ್ನಡ', // Kannada
        'മലയാളം', // Malayalam
        'ગુજરાતી', // Gujarati
      ]) {
        expect(isIndicText(sample), isTrue, reason: sample);
      }
    });

    test('leaves Latin alone', () {
      expect(isIndicText('Rail operators trial a fare cap'), isFalse);
      expect(isIndicText(''), isFalse);
    });

    test('a mixed headline counts as Indic', () {
      expect(isIndicText('BBC हिन्दी'), isTrue);
    });
  });

  group('the Indic type stack', () {
    test('opens the line up without changing the size', () {
      final latin = HsType.cardHeadline;
      final indic = HsType.indic(latin);
      expect(indic.fontSize, latin.fontSize);
      expect(indic.height, greaterThan(latin.height!));
      // 19 / 1.32 becomes 19 / 1.50, from the board's own type table.
      expect(indic.height, closeTo(1.5, 0.02));
    });

    test('drops the tracking, which breaks conjuncts', () {
      expect(HsType.indic(HsType.sourceLabel).letterSpacing, 0);
    });

    test('names a script fallback for every role', () {
      expect(
        HsType.cardHeadline.fontFamilyFallback,
        contains('NotoSerifDevanagari'),
      );
      expect(HsType.caption.fontFamilyFallback, contains('NotoSansDevanagari'));
    });

    test('the source label drops its caps in an Indic script', () {
      expect(HsType.sourceLabelText('BBC News'), 'BBC NEWS');
      expect(HsType.sourceLabelText('दैनिक जागरण'), 'दैनिक जागरण');
      expect(HsType.sourceLabelFor('दैनिक जागरण').letterSpacing, 0);
      expect(HsType.sourceLabelFor('BBC News').letterSpacing, isNonZero);
    });

    test('forText picks the stack from the text itself', () {
      // Checked on the words, not on the source's tag: an English-tagged
      // feed still carries the odd Devanagari headline.
      expect(
        HsType.forText(HsType.cardHeadline, 'मानसून की वापसी').height,
        greaterThan(HsType.cardHeadline.height!),
      );
    });
  });

  group('the catalog carries languages', () {
    late final catalog = SourceCatalog.parse(
      File(SourceCatalog.assetPath).readAsStringSync(),
    );

    test('every entry states a language', () {
      for (final source in catalog.sources) {
        expect(source.language.trim(), isNotEmpty, reason: source.title);
      }
    });

    test('ships more than English', () {
      expect(catalog.languages, contains('en'));
      expect(catalog.languages, contains('hi'));
      expect(
        catalog.languages.length,
        greaterThanOrEqualTo(5),
        reason: 'Hindi plus regional feeds',
      );
    });

    test('a Hindi publisher keeps its own name', () {
      final hindi = catalog.sources.where((s) => s.language == 'hi');
      expect(hindi, isNotEmpty);
      expect(hindi.any((s) => isIndicText(s.title)), isTrue);
    });
  });

  group('OPML round-trips the language', () {
    test('an omitted language is English, as every exporter leaves it', () {
      final entries = Opml.parse('''
<opml version="2.0"><body>
  <outline text="World">
    <outline type="rss" text="BBC" xmlUrl="https://b.example/rss"/>
  </outline>
</body></opml>''');
      expect(entries.single.language, 'en');
    });

    test('a stated language survives the read', () {
      final entries = Opml.parse('''
<opml version="2.0"><body>
  <outline text="India">
    <outline type="rss" text="BBC हिन्दी" xmlUrl="https://b.example/hi"
             language="HI"/>
  </outline>
</body></opml>''');
      expect(entries.single.language, 'hi');
    });

    test('an export carries it back out', () async {
      final db = HsDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final sources = SourceRepository(db);
      await sources.add(
        title: 'दैनिक जागरण',
        feedUrl: 'https://jagran.example/rss',
        category: 'India',
        language: 'hi',
      );

      final written = Opml.write(await sources.all());
      expect(Opml.parse(written).single.language, 'hi');
    });
  });

  group('language is a label on a source, like a category', () {
    late HsDatabase db;
    late SourceRepository sources;

    setUp(() {
      db = HsDatabase.forTesting(NativeDatabase.memory());
      sources = SourceRepository(db);
    });

    tearDown(() => db.close());

    test('defaults to English and can be changed', () async {
      final id = await sources.add(
        title: 'A publisher',
        feedUrl: 'https://a.example/rss',
        category: 'India',
      );
      expect((await sources.all()).single.language, 'en');

      await sources.setLanguage(id, 'hi');
      expect((await sources.all()).single.language, 'hi');
    });

    test('the filter offers only languages with an enabled source', () async {
      final hindi = await sources.add(
        title: 'BBC हिन्दी',
        feedUrl: 'https://b.example/hi',
        category: 'World',
        language: 'hi',
      );
      await sources.add(
        title: 'BBC News',
        feedUrl: 'https://b.example/en',
        category: 'World',
      );
      expect(
        await sources.watchLanguages().first,
        unorderedEquals(['en', 'hi']),
      );

      // Pausing the last Hindi source takes the option away with it, exactly
      // as a category tab disappears with its last source.
      await sources.setEnabled(hindi, enabled: false);
      expect(await sources.watchLanguages().first, ['en']);
    });
  });
}
