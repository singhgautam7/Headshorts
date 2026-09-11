import 'package:flutter/widgets.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/controls.dart';

/// A low-emphasis "i" that opens an explainer.
///
/// Quiet by design: an outline and a serif italic i, at a full 44dp target.
class InfoButton extends StatelessWidget {
  const new({required this.semanticLabel, required this.onTap, super.key});

  /// What the button explains, read out as "About OPML" rather than "info".
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: HsSize.navItem,
        height: HsSize.navItem,
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: palette.textMuted,
                width: HsSize.glyphStroke,
              ),
            ),
            child: Text(
              'i',
              style: HsType.readerMeta.copyWith(
                fontFamily: HsType.serif,
                height: 1,
                color: palette.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
