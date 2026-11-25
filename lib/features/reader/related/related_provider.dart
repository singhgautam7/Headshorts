import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/db/related_repository.dart';
import 'package:headshorts/features/reader/related/related_matcher.dart';

final relatedRepositoryProvider = Provider<RelatedRepository>(
  (ref) => RelatedRepository(ref.watch(databaseProvider)),
);

/// Other publishers' coverage of one article. Local only; empty on any miss.
final relatedProvider = FutureProvider.autoDispose
    .family<List<RelatedStory>, int>(
      (ref, articleId) =>
          ref.watch(relatedRepositoryProvider).related(articleId),
    );
