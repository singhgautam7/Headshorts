import 'dart:async';

import 'package:flutter/material.dart'
    show DismissDirection, Dismissible, Icons;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/open_in_web.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/glyphs.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/db/database.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/bookmarks/bookmarks_controller.dart';
import 'package:headshorts/features/today/headline_card.dart';
import 'package:share_plus/share_plus.dart';

/// Bookmarks — what the reader kept, newest saved first.
///
/// A pushed screen under More, so the nav pill is not shown. Each row is a
/// snapshot rather than a pointer into the cache, which is why a saved
/// article still opens months later and offline. Removing is a swipe, a
/// long-press menu **and** a TalkBack action, because a swipe must never be
/// the only way to do anything.
class BookmarksScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final saved = ref.watch(bookmarksProvider).value;
    final size = ref.watch(settingsProvider.select((s) => s.listSize));

    return PushedScreen(
      title: '',
      divider: false,
      child: saved == null
          ? const _Skeleton()
          : saved.isEmpty
          ? const _Empty()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HsSpace.x5,
                    0,
                    HsSpace.x5,
                    6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bookmarks',
                        style: HsType.screenTitle.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${saved.length} saved · most recently saved first',
                        style: HsType.timestamp.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      HsSpace.x5,
                      HsSpace.x2,
                      HsSpace.x5,
                      HsSpace.x5,
                    ),
                    itemCount: saved.length,
                    itemBuilder: (context, index) => _BookmarkRow(
                      row: saved[index],
                      size: size,
                      isLast: index == saved.length - 1,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BookmarkRow extends ConsumerWidget {
  const new({required this.row, required this.size, required this.isLast});

  final BookmarkRow row;
  final ListSize size;
  final bool isLast;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    await ref.read(bookmarkRepositoryProvider).removeById(row.id);
    if (!context.mounted) return;
    showUndoNotice(
      context,
      'Removed from Bookmarks',
      onUndo: () =>
          unawaited(ref.read(bookmarkRepositoryProvider).restore(row)),
    );
  }

  void _open(BuildContext context) {
    // The article row while the cache still has it, the snapshot when it does
    // not. Either way the Reader opens; nothing here is ever a dead end.
    final articleId = row.articleId;
    if (articleId != null) {
      unawaited(context.push('/reader/$articleId'));
    } else {
      unawaited(context.push('/bookmark/${row.id}'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = Padding(
      padding: EdgeInsets.only(
        top: size == ListSize.small ? 0 : 18,
        bottom: size == ListSize.small ? 0 : 18,
      ),
      child: Builder(
        builder: (rowContext) => HeadlineCard(
          ArticleView.fromBookmark(row),
          size: size,
          onTap: () => _open(context),
          onLongPress: () => _showRowMenu(
            context: context,
            anchorContext: rowContext,
            ref: ref,
            row: row,
          ),
        ),
      ),
    );

    return Semantics(
      customSemanticsActions: {
        // Never the only way: the swipe has a menu and the menu has this.
        const CustomSemanticsAction(label: 'Remove from Bookmarks'): () =>
            unawaited(_remove(context, ref)),
      },
      child: Dismissible(
        key: ValueKey(row.id),
        direction: DismissDirection.endToStart,
        dismissThresholds: const {DismissDirection.endToStart: 0.4},
        onDismissed: (_) => unawaited(_remove(context, ref)),
        background: _RemoveBackground(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.hs.background,
            border: size == ListSize.small || isLast
                ? null
                : Border(bottom: BorderSide(color: context.hs.divider)),
          ),
          child: card,
        ),
      ),
    );
  }
}

Future<void> _showRowMenu({
  required BuildContext context,
  required BuildContext anchorContext,
  required WidgetRef ref,
  required BookmarkRow row,
}) async {
  final selected = await showHsMenu<String>(
    context: context,
    anchorContext: anchorContext,
    entries: const [
      HsMenuEntry(
        value: 'remove',
        label: 'Remove',
        icon: Icons.delete_outline_rounded,
      ),
      HsMenuEntry(value: 'share', label: 'Share', icon: Icons.share_rounded),
      HsMenuEntry(
        value: 'web',
        label: 'Open in web',
        icon: Icons.open_in_new_rounded,
      ),
    ],
  );

  switch (selected) {
    case 'remove':
      await ref.read(bookmarkRepositoryProvider).removeById(row.id);
      if (context.mounted) {
        showUndoNotice(
          context,
          'Removed from Bookmarks',
          onUndo: () =>
              unawaited(ref.read(bookmarkRepositoryProvider).restore(row)),
        );
      }
    case 'share':
      await SharePlus.instance.share(
        ShareParams(text: '${row.title}\n\n${row.link}', subject: row.title),
      );
    case 'web':
      await openInWeb(row.link);
  }
}

/// What sits behind the row as it follows the finger.
class _RemoveBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return ColoredBox(
      color: palette.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.only(right: HsSpace.x5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: palette.textPrimary,
            ),
            const SizedBox(width: HsSpace.x2),
            Text(
              'Remove',
              style: HsType.buttonSmall.copyWith(color: palette.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// States where the control is, and stops. No button to go and find something
/// to save — that would be sending the reader somewhere to do homework.
class _Empty extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Padding(
      // A little clear of the true centre, so the block sits where the eye
      // looks rather than where the arithmetic lands.
      padding: const EdgeInsets.fromLTRB(HsSpace.x5, 0, HsSpace.x5, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bookmarks',
            style: HsType.screenTitle.copyWith(color: palette.textPrimary),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HsGlyph.bookmark(palette.textMuted),
                const SizedBox(height: 14),
                Text(
                  'Nothing saved yet',
                  style: HsType.stepTitle.copyWith(
                    fontSize: 20,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'In the Reader, tap the bookmark beside Share to keep an '
                  'article here. Saved articles stay on this phone.',
                  style: HsType.caughtUpBody.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      HsSpace.x5,
      HsSpace.x5,
      HsSpace.x5,
      HsSpace.x5,
    ),
    children: const [
      HeadlineSkeleton(widths: [0.8, 0.5], withThumbnail: true),
      SizedBox(height: 30),
      HeadlineSkeleton(widths: [0.7, 0.44], withThumbnail: true),
      SizedBox(height: 30),
      HeadlineSkeleton(widths: [0.86, 0.4]),
    ],
  );
}

/// The standard notice with one action on the end.
///
/// Two uses, and only two: Undo on a removal the reader may not have meant,
/// and View on a save. It holds for five seconds rather than waiting to be
/// dismissed, and there is nothing to celebrate either way.
void showActionNotice(
  BuildContext context,
  String message, {
  required String actionLabel,
  required VoidCallback onAction,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  var removed = false;
  void close() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _ActionNotice(
      message: message,
      actionLabel: actionLabel,
      onAction: () {
        onAction();
        close();
      },
      onDone: close,
    ),
  );
  overlay.insert(entry);
}

/// Removing a bookmark, with Undo. The one call both this screen and the
/// Reader make.
void showUndoNotice(
  BuildContext context,
  String message, {
  required VoidCallback onUndo,
}) => showActionNotice(context, message, actionLabel: 'Undo', onAction: onUndo);

class _ActionNotice extends StatefulWidget {
  const new({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onDone,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDone;

  @override
  State<_ActionNotice> createState() => _ActionNoticeState();
}

class _ActionNoticeState extends State<_ActionNotice> {
  static const _visibleFor = Duration(seconds: 5);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_visibleFor, widget.onDone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    return Positioned(
      left: 20,
      right: 20,
      bottom: 26,
      child: Semantics(
        liveRegion: true,
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 18, right: HsSpace.x2),
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: HsRadius.pillBorder,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.message,
                  style: HsType.buttonSmall.copyWith(color: palette.onPrimary),
                ),
              ),
              Pressable(
                onTap: widget.onAction,
                semanticLabel: widget.actionLabel,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  child: Text(
                    widget.actionLabel,
                    style: HsType.buttonSmall.copyWith(
                      color: palette.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
