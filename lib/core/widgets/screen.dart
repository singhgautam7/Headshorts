import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/widgets/app_header.dart';

/// A root destination: the serif screen title in the floating header, an
/// optional trailing control, and the body beneath.
///
/// The body scrolls under the header. A body that starts with
/// [HeaderPage.gap] (or [HeaderPage.sliverGap]) sets [underHeader] and gets
/// the full effect; any other body is simply laid out below the header at
/// rest, which is correct but leaves nothing to scroll beneath the pill.
class HsScreen extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    this.trailing,
    this.underHeader = false,
    this.scrollAway = false,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  /// The body begins with the header's gap and scrolls under the pill.
  final bool underHeader;

  /// The header scrolls away and a [HeaderSearchBar] in the body becomes the
  /// pill (the Search tab).
  final bool scrollAway;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.hs.background,
    child: HeaderPage(
      scrollAway: scrollAway,
      header: AppHeader(title: title, root: true, actions: [?trailing]),
      body: underHeader ? child : _BelowHeader(child: child),
    ),
  );
}

/// Lays a body that knows nothing about the header out beneath it.
class _BelowHeader extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Builder(
    builder: (context) => Padding(
      padding: EdgeInsets.only(top: HeaderPage.insetOf(context)),
      child: child,
    ),
  );
}

/// A pushed screen: a back arrow (a close mark for a [form]), a sans title,
/// and the body.
///
/// The body starts with [HeaderPage.gap] or [HeaderPage.sliverGap] so it
/// scrolls under the floating header.
class PushedScreen extends StatelessWidget {
  const new({
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
    this.footer,
    this.form = false,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? footer;

  /// A form closes rather than goes back: an x labelled "Close".
  final bool form;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.hs.background,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: HeaderPage(
            header: AppHeader(
              title: title,
              onBack: onBack ?? () => Navigator.of(context).maybePop(),
              backIcon: form ? Icons.close_rounded : Icons.arrow_back_rounded,
              backLabel: form ? 'Close' : 'Back',
              actions: [?trailing],
            ),
            body: child,
          ),
        ),
        if (footer != null)
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            child: footer,
          ),
      ],
    ),
  );
}

/// The scroll padding a pushed list wants beneath the header's gap.
const pushedListPadding = EdgeInsets.fromLTRB(
  HsSpace.x4,
  HsSpace.x3,
  HsSpace.x4,
  HsSpace.x7,
);
