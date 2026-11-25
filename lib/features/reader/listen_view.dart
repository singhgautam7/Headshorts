import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:headshorts/app/settings_controller.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/oklab.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/language.dart';
import 'package:headshorts/core/widgets/caught_up.dart';
import 'package:headshorts/core/widgets/controls.dart';
import 'package:headshorts/core/widgets/nav_pill.dart';
import 'package:headshorts/core/widgets/sheet.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/features/reader/listen_controller.dart';

/// The article as read-aloud sees it: plain-text paragraphs, with the
/// sentence being spoken washed in the source accent and the spoken word
/// solid inside it.
///
/// Plain text rather than the rendered body because the engine reports a word
/// as a character range in the string it was given — highlighting over rich
/// HTML would mean mapping those ranges back through the markup, which breaks
/// the moment a publisher puts a link in the middle of a sentence.
///
/// The rendered body comes straight back when listening stops.
class ListenView extends ConsumerWidget {
  const new({
    required this.language,
    required this.accent,
    required this.bodySize,
    required this.spokenKey,
    required this.highlightWords,
    super.key,
  });

  final String language;
  final Color accent;
  final double bodySize;

  /// Attached to the paragraph being spoken, so the page can keep it in view.
  final GlobalKey spokenKey;

  /// Following along word by word can be switched off. It is never the only
  /// cue to position — the progress bar and the time are.
  final bool highlightWords;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The paragraphs and which one is spoken: changes once a paragraph, not
    // once a word. The word highlight lives in [_Paragraph], which is the
    // only thing that rebuilds on it.
    final paragraphs = ref.watch(
      listenProvider(language).select((s) => s.paragraphs),
    );
    final spoken = ref.watch(listenProvider(language).select((s) => s.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < paragraphs.length; i++)
          _Paragraph(
            key: i == spoken ? spokenKey : null,
            language: language,
            index: i,
            text: paragraphs[i].text,
            spoken: i == spoken,
            accent: accent,
            bodySize: bodySize,
            highlightWords: highlightWords,
          ),
      ],
    );
  }
}

/// One paragraph. Only the spoken one watches the word range.
class _Paragraph extends ConsumerWidget {
  const new({
    required this.language,
    required this.index,
    required this.text,
    required this.spoken,
    required this.accent,
    required this.bodySize,
    required this.highlightWords,
    super.key,
  });

  final String language;
  final int index;
  final String text;
  final bool spoken;
  final Color accent;
  final double bodySize;
  final bool highlightWords;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    // Everything but the sentence in hand steps back, so the place is
    // obvious without anything having to flash.
    final style = HsType.forText(
      HsType.readerBody(bodySize),
      text,
    ).copyWith(color: spoken ? palette.textPrimary : palette.textSecondary);
    var span = TextSpan(text: text);
    if (spoken) {
      final range = ref.watch(
        listenProvider(language).select(
          (s) =>
              (s.wordStart, s.wordEnd, s.sentenceRange.$1, s.sentenceRange.$2),
        ),
      );
      // The accent at 32% under full ink, which keeps body contrast above 7:1
      // in both themes — mixed in oklab, as every wash in this app is.
      final wash = Oklab.mix(accent, palette.background, 0.32);
      span = _spans(
        text,
        wordStart: range.$1,
        wordEnd: range.$2,
        sentenceStart: range.$3,
        sentenceEnd: range.$4,
        wash: wash,
        palette: palette,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text.rich(span, style: style),
    );
  }

  TextSpan _spans(
    String text, {
    required int wordStart,
    required int wordEnd,
    required int sentenceStart,
    required int sentenceEnd,
    required Color wash,
    required HsPalette palette,
  }) {
    final start = sentenceStart.clamp(0, text.length);
    final end = sentenceEnd.clamp(start, text.length);
    final wStart = wordStart.clamp(start, end);
    final wEnd = wordEnd.clamp(wStart, end);

    return TextSpan(
      children: [
        if (start > 0) TextSpan(text: text.substring(0, start)),
        if (highlightWords && wEnd > wStart) ...[
          TextSpan(
            text: text.substring(start, wStart),
            style: TextStyle(backgroundColor: wash),
          ),
          TextSpan(
            text: text.substring(wStart, wEnd),
            style: TextStyle(
              backgroundColor: accent,
              color: palette.background,
            ),
          ),
          TextSpan(
            text: text.substring(wEnd, end),
            style: TextStyle(backgroundColor: wash),
          ),
        ] else
          TextSpan(
            text: text.substring(start, end),
            style: TextStyle(backgroundColor: wash),
          ),
        if (end < text.length) TextSpan(text: text.substring(end)),
      ],
    );
  }
}

/// The read-aloud transport, in the same pill dress as the action row it
/// replaces: play/pause, where it has got to, the speed, the voice, and stop.
///
/// It does **not** hide on scroll the way the action row does. Losing a row
/// of links while reading is nothing; losing the pause button while something
/// is talking is not the same thing at all.
class ListenBar extends ConsumerWidget {
  const new({required this.accent, required this.language, super.key});

  final Color accent;
  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final controller = ref.read(listenProvider(language).notifier);
    // Only what the buttons show. The time and the progress line tick with
    // every word and live in [_Meter], so the bar itself does not rebuild.
    final playing = ref.watch(
      listenProvider(language).select((s) => s.playing),
    );
    final rate = ref.watch(settingsProvider.select((s) => s.speechRate));

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.background.withValues(alpha: 0),
            palette.background.withValues(alpha: 0.9),
            palette.background,
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, HsSpace.x7, 20, 0),
          child: Semantics(
            container: true,
            label: 'Read aloud controls',
            child: NavPillSurface(
              child: SizedBox(
                height: 60,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Row(
                    children: [
                      Pressable(
                        kind: PressKind.iconButton,
                        onTap: () => unawaited(
                          playing ? controller.pause() : controller.resume(),
                        ),
                        semanticLabel: playing ? 'Pause' : 'Play',
                        restRadius: HsSize.navItem / 2,
                        pressedRadius: HsRadius.heldIcon,
                        builder: (context, radius, _) => Container(
                          width: HsSize.navItem,
                          height: HsSize.navItem,
                          decoration: BoxDecoration(
                            color: palette.primary,
                            borderRadius: BorderRadius.circular(radius),
                          ),
                          child: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                            color: palette.onPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _Meter(
                          language: language,
                          accent: accent,
                          playing: playing,
                          rate: rate,
                        ),
                      ),
                      Pressable(
                        kind: PressKind.iconButton,
                        onTap: () => showListenSettings(context, language),
                        semanticLabel: 'Speed ${rate.spokenLabel}',
                        restRadius: HsSize.navItem / 2,
                        pressedRadius: HsRadius.heldIcon,
                        builder: (context, radius, pressed) => Container(
                          height: HsSize.navItem,
                          constraints: const BoxConstraints(minWidth: 44),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.primaryContainer.withValues(
                              alpha: pressed.clamp(0.0, 1.0),
                            ),
                            borderRadius: BorderRadius.circular(radius),
                          ),
                          child: Text(
                            rate.label,
                            maxLines: 1,
                            style: HsType.buttonSmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      HsIconButton(
                        icon: Icons.record_voice_over_outlined,
                        glyphSize: 19,
                        filled: false,
                        size: HsSize.navItem,
                        tint: palette.textSecondary,
                        onPressed: () => showListenSettings(context, language),
                        semanticLabel: 'Voice',
                      ),
                      HsIconButton(
                        icon: Icons.close_rounded,
                        glyphSize: 18,
                        filled: false,
                        size: HsSize.navItem,
                        tint: palette.textSecondary,
                        onPressed: () => unawaited(controller.stop()),
                        semanticLabel: 'Stop listening',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where it has got to: the state, the clock and the progress line. The only
/// part of the bar that follows the voice word by word.
class _Meter extends ConsumerWidget {
  const new({
    required this.language,
    required this.accent,
    required this.playing,
    required this.rate,
  });

  final String language;
  final Color accent;
  final bool playing;
  final SpeechRate rate;

  /// Roughly how fast speech runs, in characters a second at 1.0×. Only ever
  /// used for the two times on the bar, which are an orientation rather than
  /// a measurement — no engine will tell us the real duration up front.
  static const _charsPerSecond = 15.0;

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.hs;
    final listen = ref.watch(listenProvider(language));
    final pace = _charsPerSecond * rate.multiplier;
    final total = Duration(seconds: (listen.totalChars / pace).round());
    final elapsed = Duration(seconds: (listen.spokenChars / pace).round());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  playing ? 'Listening' : 'Paused',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HsType.chipSelected.copyWith(
                    fontSize: 12,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              // Scales down rather than overflowing at a large font size.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${_clock(elapsed)} / ${_clock(total)}',
                    maxLines: 1,
                    style: HsType.timestamp.copyWith(color: palette.textMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _Progress(value: listen.progress, accent: accent),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const new({required this.value, required this.accent});

  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    child: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.hs.divider,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Speed, voice and whether words are highlighted.
///
/// Voices are the engine's own, filtered to the article's language and
/// carrying the names the engine gives them — renaming someone else's voices
/// would only make them harder to recognise. The choice is remembered per
/// language, because a voice picked for English says nothing about Hindi.
Future<void> showListenSettings(BuildContext context, String language) =>
    showHsSheet<void>(
      context,
      (context) => _ListenSettingsSheet(language: language),
    );

class _ListenSettingsSheet extends ConsumerStatefulWidget {
  const new({required this.language});

  final String language;

  @override
  ConsumerState<_ListenSettingsSheet> createState() =>
      _ListenSettingsSheetState();
}

class _ListenSettingsSheetState extends ConsumerState<_ListenSettingsSheet> {
  late final Future<List<Map<String, String>>> _voices = ref
      .read(listenProvider(widget.language).notifier)
      .voices();

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final listen = ref.read(listenProvider(widget.language).notifier);
    final chosen = settings.voiceByLanguage[widget.language.split('-').first];

    return HsSheet(
      title: 'Listen',
      subtitle: "Uses your phone's speech engine. Nothing leaves the device.",
      children: [
        const SectionLabel('Speed'),
        const SizedBox(height: HsSpace.x3),
        Container(
          padding: const EdgeInsets.all(HsSpace.x1),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: HsRadius.buttonBorder,
          ),
          child: Row(
            children: [
              for (final rate in SpeechRate.values)
                Expanded(
                  child: Semantics(
                    inMutuallyExclusiveGroup: true,
                    selected: rate == settings.speechRate,
                    label: rate.spokenLabel,
                    child: Pressable(
                      kind: PressKind.chip,
                      haptic: true,
                      onTap: () async {
                        await controller.setSpeechRate(rate);
                        await listen.reapply();
                      },
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rate == settings.speechRate
                              ? palette.navActive
                              : null,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          rate.label,
                          style:
                              (rate == settings.speechRate
                                      ? HsType.chipSelected
                                      : HsType.chip)
                                  .copyWith(
                                    color: rate == settings.speechRate
                                        ? palette.textPrimary
                                        : palette.textSecondary,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        FutureBuilder<List<Map<String, String>>>(
          future: _voices,
          builder: (context, snapshot) {
            final voices = snapshot.data ?? const [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(
                  'Voice · ${HsLanguage.of(widget.language).englishName}',
                ),
                const SizedBox(height: HsSpace.x2),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: HsSpace.x3),
                    child: SkeletonBar(widthFactor: 0.6),
                  )
                else if (voices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: HsSpace.x3),
                    child: Text(
                      'Your phone offers no separate voices for this '
                      'language; its default will read.',
                      style: HsType.note.copyWith(color: palette.textMuted),
                    ),
                  )
                else
                  for (final voice in voices.take(6))
                    _VoiceRow(
                      name: voice['name'] ?? '',
                      locale: voice['locale'] ?? '',
                      selected: voice['name'] == chosen,
                      onTap: () async {
                        await controller.setVoice(
                          widget.language.split('-').first,
                          voice['name'] ?? '',
                        );
                        await listen.reapply();
                      },
                    ),
              ],
            );
          },
        ),
        const SizedBox(height: HsSpace.x2),
        _HighlightRow(
          value: settings.highlightWords,
          onChanged: (value) => controller.setHighlightWords(enabled: value),
        ),
      ],
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const new({
    required this.name,
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: Pressable(
        kind: PressKind.row,
        haptic: true,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.divider)),
          ),
          child: SizedBox(
            height: 54,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HsType.row.copyWith(color: palette.textPrimary),
                      ),
                      const SizedBox(height: HsSpace.x1),
                      Text(
                        locale,
                        style: HsType.rowSub.copyWith(color: palette.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? palette.textPrimary : palette.stroke,
                      width: selected ? 6 : 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const new({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Highlight words',
                  style: HsType.row.copyWith(color: palette.textPrimary),
                ),
                const SizedBox(height: HsSpace.x1),
                Text(
                  'Follow along as it reads',
                  style: HsType.rowSub.copyWith(color: palette.textMuted),
                ),
              ],
            ),
          ),
          HsToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// No voice on this phone for the article's language.
///
/// Names the language, the reason and the one fix. No warning colour and no
/// apology: it is a missing voice pack, not an error.
class UnsupportedLanguageCard extends StatelessWidget {
  const new({required this.language, required this.onDismiss, super.key});

  final String language;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        border: Border.all(color: palette.stroke),
        borderRadius: HsRadius.cardBorder,
        boxShadow: [palette.navShadow],
      ),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Can't read this one aloud",
              style: HsType.title.copyWith(
                fontSize: 15,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: HsSpace.x2),
            Text(
              'This phone has no $language voice installed. You can add one '
              "in Android's text-to-speech settings, then try again.",
              style: HsType.note.copyWith(
                height: 1.6,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: HsSpace.x3),
            HsButton(
              'Not now',
              onPressed: onDismiss,
              kind: HsButtonKind.secondary,
              height: HsSize.buttonCompact,
            ),
          ],
        ),
      ),
    );
  }
}
