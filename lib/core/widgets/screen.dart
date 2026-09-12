import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/motion.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/pull_to_refresh.dart';

/// A root destination: the serif screen title, an optional trailing control,
/// and the body beneath.
class HsScreen extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    this.trailing,
    this.titlePadding = const EdgeInsets.fromLTRB(
      HsSpace.x5,
      6,
      HsSpace.x5,
      HsSpace.x3,
    ),
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets titlePadding;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.hs.background,
    child: SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: titlePadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: HsType.screenTitle.copyWith(
                      color: context.hs.textPrimary,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

/// A pushed screen: a back arrow, a sans title, and the body.
class PushedScreen extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
    this.divider = true,
    this.footer,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool divider;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: divider
                    ? Border(bottom: BorderSide(color: palette.divider))
                    : null,
              ),
              child: SizedBox(
                height: HsSize.appBarHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      HsIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                        semanticLabel: 'Back',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: HsType.appBarTitle.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: child),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// The horizontal category sub-tabs above Today's list.
class SubTabs extends StatefulWidget {
  const new({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.counts,
    this.loadingCounts = false,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Map<String, int>? counts;
  final bool loadingCounts;

  @override
  State<SubTabs> createState() => _SubTabsState();
}

class _SubTabsState extends State<SubTabs> {
  final _scroll = ScrollController();
  final _keys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _syncKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(SubTabs old) {
    super.didUpdateWidget(old);
    if (old.labels.length != widget.labels.length) {
      _syncKeys();
    }
    if (old.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _syncKeys() {
    while (_keys.length < widget.labels.length) {
      _keys.add(GlobalKey());
    }
  }

  void _scrollToSelected() {
    if (!mounted ||
        widget.selectedIndex < 0 ||
        widget.selectedIndex >= _keys.length) {
      return;
    }
    final targetContext = _keys[widget.selectedIndex].currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.5,
        duration: HsMotion.tabSlide,
        curve: HsMotion.tabSlideCurve,
      );
    }
  }

  void _onTabTap(int index) {
    unawaited(HapticFeedback.selectionClick());
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    _syncKeys();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HsSpace.x5),
        child: Row(
          children: [
            for (var i = 0; i < widget.labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 22),
              _SubTab(
                key: _keys[i],
                label: widget.labels[i],
                count: widget.counts?[widget.labels[i]],
                loadingCount: widget.loadingCounts,
                selected: i == widget.selectedIndex,
                onTap: () => _onTabTap(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubTab extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.loadingCount = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final bool loadingCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;

    Widget? badge;
    if (loadingCount) {
      badge = SizedBox(
        width: 12,
        height: 12,
        child: FittedBox(
          child: HsPullRing(
            color: palette.textMuted,
            progress: 1,
            spinning: true,
          ),
        ),
      );
    } else if (count != null && count! > 0) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? palette.textPrimary.withValues(alpha: 0.14)
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count',
          style: HsType.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: selected ? palette.textPrimary : palette.textMuted,
          ),
        ),
      );
    }

    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: HsMotion.tabSlide,
        curve: HsMotion.tabSlideCurve,
        padding: const EdgeInsets.only(bottom: HsSpace.x3),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? palette.primary : const Color(0x00000000),
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: HsMotion.tabSlide,
              curve: HsMotion.tabSlideCurve,
              style: (selected ? HsType.subTabActive : HsType.subTab).copyWith(
                color: selected ? palette.textPrimary : palette.textMuted,
              ),
              child: Text(label),
            ),
            if (badge != null) ...[const SizedBox(width: 6), badge],
          ],
        ),
      ),
    );
  }
}
