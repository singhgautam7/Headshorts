import 'package:flutter/material.dart' show InputDecoration, TextField;
import 'package:flutter/services.dart' show TextCapitalization;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/providers.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/features/today/today_controller.dart';

/// Renames a category, across every source in it.
///
/// A category is only ever a label on a source, so this is the whole model:
/// renaming onto a name that already exists merges the two, and typing a name
/// that does not exist creates it. There is nothing else to manage.
Future<void> showRenameCategorySheet(BuildContext context, String category) =>
    showHsSheet<void>(
      context,
      (context) => _RenameCategorySheet(category: category),
    );

class _RenameCategorySheet extends ConsumerStatefulWidget {
  const new({required this.category});

  final String category;

  @override
  ConsumerState<_RenameCategorySheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends ConsumerState<_RenameCategorySheet> {
  late final _name = TextEditingController(text: widget.category);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _rename() async {
    final to = _name.text.trim();
    if (to.isEmpty || to == widget.category) {
      Navigator.of(context).pop();
      return;
    }
    await ref
        .read(sourceRepositoryProvider)
        .renameCategory(widget.category, to);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final existing = (ref.watch(categoriesProvider).value ?? const <String>[])
        .where((c) => c != latestScope && c != widget.category)
        .toList();
    final target = _name.text.trim();
    final merging = existing.contains(target);

    return HsSheet(
      title: 'Rename ${widget.category}',
      subtitle: 'Every source in this category moves with it.',
      children: [
        Container(
          height: HsSize.buttonLarge,
          padding: const EdgeInsets.symmetric(horizontal: HsSpace.x4),
          decoration: BoxDecoration(
            color: palette.background,
            border: Border.all(color: palette.stroke),
            borderRadius: HsRadius.buttonBorder,
          ),
          child: TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _rename(),
            cursorColor: palette.textPrimary,
            style: HsType.buttonLarge.copyWith(color: palette.textPrimary),
            decoration: const InputDecoration.collapsed(hintText: ''),
          ),
        ),
        const SizedBox(height: HsSpace.x3),
        Text(
          merging
              ? 'There is already a "$target". The two will be merged.'
              : 'Renaming to something new simply creates it.',
          style: HsType.note.copyWith(color: palette.textMuted),
        ),
        if (existing.isNotEmpty) ...[
          const SizedBox(height: HsSpace.x4),
          Wrap(
            spacing: HsSpace.x2,
            runSpacing: HsSpace.x2,
            children: [
              for (final category in existing)
                HsChip(
                  category,
                  onTap: () => setState(() {
                    _name.text = category;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: HsSpace.x5),
        HsButton(merging ? 'Merge into $target' : 'Rename', onPressed: _rename),
      ],
    );
  }
}
