import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/widgets/screen.dart';

/// AI summaries — a placeholder, and nothing else.
///
/// The summariser is a later phase and deliberately not built. Rather than a
/// key field and toggles that do nothing, the screen says so in one line and
/// stops: nothing here looks half-enabled, and nothing is stored.
class AiSummariesScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return PushedScreen(
      title: 'AI summaries',
      onBack: () => context.pop(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HsSpace.x5,
            0,
            HsSpace.x5,
            HsSpace.navClearance,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 28,
                color: palette.textMuted,
              ),
              const SizedBox(height: 18),
              Text(
                'Coming soon',
                style: HsType.caughtUp.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  'Short summaries, on your own API key, run on request and '
                  'never in the background. Not in this release.',
                  textAlign: TextAlign.center,
                  style: HsType.caughtUpBody.copyWith(
                    color: palette.textSecondary,
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
