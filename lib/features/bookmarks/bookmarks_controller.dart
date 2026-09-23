import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/data/db/database.dart';

/// Everything saved, most recently saved first.
final bookmarksProvider = StreamProvider<List<BookmarkRow>>(
  (ref) => ref.watch(bookmarkRepositoryProvider).watchAll(),
);

/// How many are saved — the plain value on the More row.
///
/// A count on a settings row, not a badge: it answers "is there anything in
/// there" without ever reaching the nav or turning into something to clear.
final bookmarkCountProvider = StreamProvider<int>(
  (ref) => ref.watch(bookmarkRepositoryProvider).watchCount(),
);

/// Whether this article's address is saved. Keyed on the link, so the second
/// feed's copy of the same story reads as saved too.
final isBookmarkedProvider = StreamProvider.family<bool, String>(
  (ref, link) => ref.watch(bookmarkRepositoryProvider).watchIsSaved(link),
);
