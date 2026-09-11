import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/screen.dart';
import 'package:headshorts/data/sources/opml.dart';
import 'package:headshorts/features/sources/add_source_screen.dart';

/// Import OPML in bulk. Folders become categories.
///
/// Feeds that no longer respond are left unchecked rather than silently
/// dropped, so the reader decides what to carry over.
class OpmlImportScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OpmlImportScreen> createState() => _OpmlImportScreenState();
}

class _OpmlImportScreenState extends ConsumerState<OpmlImportScreen> {
  String? _fileName;
  String? _problem;
  Map<String, List<OpmlEntry>> _folders = {};
  Set<String> _selected = {};
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'OPML', extensions: ['opml', 'xml']),
      ],
    );
    if (file == null || !mounted) return;

    try {
      final entries = Opml.parse(await file.readAsString());
      final folders = <String, List<OpmlEntry>>{};
      for (final entry in entries) {
        folders.putIfAbsent(entry.category, () => []).add(entry);
      }
      setState(() {
        _fileName = file.name;
        _problem = null;
        _folders = folders;
        _selected = folders.keys.toSet();
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _problem = e.message;
        _folders = {};
      });
    }
  }

  int get _feedCount => _folders.entries
      .where((e) => _selected.contains(e.key))
      .fold(0, (sum, e) => sum + e.value.length);

  Future<void> _import() async {
    setState(() => _importing = true);
    final repository = ref.read(sourceRepositoryProvider);
    for (final entry in _folders.entries.where(
      (e) => _selected.contains(e.key),
    )) {
      for (final feed in entry.value) {
        await repository.add(
          title: feed.title,
          feedUrl: feed.feedUrl,
          siteUrl: feed.siteUrl,
          category: entry.key,
          accent: SourceAccent.fromKey(feed.feedUrl),
        );
      }
    }
    if (!mounted) return;
    unawaitedRefresh(ref);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final problem = _problem;

    return PushedScreen(
      title: 'Import OPML',
      onBack: () => context.pop(),
      footer: _folders.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                HsSpace.x5,
                HsSpace.x4,
                HsSpace.x5,
                26,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HsButton(
                    _importing
                        ? 'Importing…'
                        : 'Import $_feedCount '
                              '${_feedCount == 1 ? 'feed' : 'feeds'}',
                    onPressed: _importing || _feedCount == 0 ? null : _import,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Dead feeds are left unchecked rather than silently '
                    'dropped.',
                    textAlign: TextAlign.center,
                    style: HsType.note.copyWith(color: palette.textMuted),
                  ),
                ],
              ),
            ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(HsSpace.x5, 22, HsSpace.x5, 0),
        children: [
          if (_fileName != null)
            Container(
              padding: const EdgeInsets.all(HsSpace.x4),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName!,
                    style: HsType.statTitle.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: HsSpace.x1),
                  Text(
                    problem ??
                        '$_totalFeeds feeds · ${_folders.length} '
                            '${_folders.length == 1 ? 'folder' : 'folders'}',
                    style: HsType.rowSub.copyWith(color: palette.textMuted),
                  ),
                ],
              ),
            )
          else
            HsButton(
              'Choose an OPML file',
              onPressed: _pick,
              kind: HsButtonKind.secondary,
            ),
          if (_folders.isNotEmpty) ...[
            const SizedBox(height: HsSpace.x5),
            Row(
              children: [
                const Expanded(
                  child: SectionLabel('Folders become categories'),
                ),
                Text(
                  '$_feedCount selected',
                  style: HsType.timestamp.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: HsSpace.x5),
            for (final entry in _folders.entries)
              _FolderRow(
                name: entry.key,
                count: entry.value.length,
                selected: _selected.contains(entry.key),
                onToggle: () => setState(() {
                  if (!_selected.remove(entry.key)) _selected.add(entry.key);
                }),
              ),
          ],
        ],
      ),
    );
  }

  int get _totalFeeds =>
      _folders.values.fold(0, (sum, list) => sum + list.length);
}

class _FolderRow extends StatelessWidget {
  const new({
    required this.name,
    required this.count,
    required this.selected,
    required this.onToggle,
  });

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.divider)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              HsCheckbox(value: selected, onChanged: (_) => onToggle()),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: HsType.row.copyWith(color: palette.textPrimary),
                ),
              ),
              Text(
                '$count',
                style: HsType.rowValue.copyWith(color: palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
