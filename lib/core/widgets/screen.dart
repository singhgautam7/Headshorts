import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';

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
