import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:headshorts/core/theme/hs_theme.dart';
import 'package:headshorts/core/tokens/accents.dart';
import 'package:headshorts/core/tokens/dimensions.dart';
import 'package:headshorts/core/tokens/palette.dart';
import 'package:headshorts/core/tokens/typography.dart';
import 'package:headshorts/core/util/open_in_web.dart';
import 'package:headshorts/data/prefs/settings.dart';
import 'package:headshorts/data/readability/article_cleaner.dart';
import 'package:headshorts/data/readability/extraction_service.dart';
import 'package:html/dom.dart' as dom;

/// Renders cleaned article HTML with every element mapped to a design token.
///
/// The cleaner has already reduced the markup to a small allowlist, so this
/// only has to give each of those tags its type from the spec — nothing here
/// guesses at unknown markup, because none reaches it.
class ArticleBody extends StatelessWidget {
  const new({
    required this.html,
    required this.articleUrl,
    required this.bodySize,
    required this.linkMode,
    super.key,
  });

  final String html;

  /// The article's own address: the base for any relative link that slipped
  /// through, and the `Referer` images are asked for with.
  final String articleUrl;

  /// The reader's chosen body size. Every style below is derived from it, so
  /// the "Aa" control scales headings, quotes and code along with the prose.
  final double bodySize;

  /// Where a tapped link goes — a Custom Tab, or the reader's own browser.
  final LinkOpenMode linkMode;

  @override
  Widget build(BuildContext context) {
    final palette = context.hs;
    final accent = AccentScope.of(context).resolve(isDark: palette.isDark);

    return HtmlWidget(
      html,
      textStyle: HsType.readerBody(bodySize)
          .copyWith(color: palette.textPrimary),
      onTapUrl: (url) => openInWeb(
        // A relative href that survived the cleaner is resolved here rather
        // than handed to the browser as-is.
        ArticleCleaner.absolutise(url, Uri.parse(articleUrl)) ?? url,
        mode: linkMode,
      ),
      customWidgetBuilder: (element) => _custom(context, element),
      customStylesBuilder: (element) =>
          _styles(element, palette, accent, bodySize),
    );
  }

  /// The heading scale, stepped off the body size so "Aa" moves everything.
  static const _headingScale = {
    'h1': 1.62,
    'h2': 1.35,
    'h3': 1.18,
    'h4': 1.06,
    'h5': 1.0,
    'h6': 0.94,
  };

  Map<String, String>? _styles(
    dom.Element element,
    HsPalette palette,
    Color accent,
    double body,
  ) {
    final tag = element.localName ?? '';
    final heading = _headingScale[tag];
    if (heading != null) {
      return {
        'font-family': HsType.serif,
        'font-size': '${(body * heading).roundToDouble()}px',
        'font-weight': '600',
        'line-height': '1.26',
        'color': _hex(palette.textPrimary),
        'margin': '${HsSpace.x5}px 0 ${HsSpace.x3}px',
      };
    }

    return switch (tag) {
      // Links carry the source accent, and are the only coloured text in the
      // body.
      'a' => {'color': _hex(accent), 'text-decoration': 'none'},
      'strong' || 'b' => {'font-weight': '600'},
      'em' || 'i' => {'font-style': 'italic'},
      'u' => {'text-decoration': 'underline'},
      's' => {'text-decoration': 'line-through'},
      'blockquote' => {
        'font-family': HsType.serif,
        'font-size': '${body}px',
        'font-style': 'italic',
        'color': _hex(palette.textSecondary),
        'margin': '${HsSpace.x5}px 0',
        'padding': '0 0 0 ${HsSpace.x4}px',
        'border-left': '${HsSize.accentBar}px solid ${_hex(accent)}',
      },
      'ul' || 'ol' => {'margin': '${HsSpace.x3}px 0 ${HsSpace.x3}px'},
      'li' => {'padding': '0 0 ${HsSpace.x2}px 0'},
      'pre' => {
        'font-family': 'monospace',
        'font-size': '${body - 2}px',
        'background': _hex(palette.surfaceVariant),
        'padding': '${HsSpace.x3}px',
        'margin': '${HsSpace.x4}px 0',
      },
      'code' => {
        'font-family': 'monospace',
        'font-size': '${body - 2}px',
        'color': _hex(palette.textPrimary),
      },
      'figcaption' => {
        'font-family': HsType.sans,
        'font-size': '${(body * 0.75).roundToDouble().clamp(11.0, 16.0)}px',
        'line-height': '1.4',
        'color': _hex(palette.textMuted),
        'margin': '${HsSpace.x2}px 0 ${HsSpace.x4}px',
      },
      'table' => {'font-size': '${body - 2}px'},
      'th' => {'font-weight': '600', 'text-align': 'left'},
      _ => null,
    };
  }

  Widget? _custom(BuildContext context, dom.Element element) =>
      switch (element.localName) {
        'img' => _image(context, element),
        'hr' => const _Rule(),
        _ => null,
      };

  /// An inline article image, collapsed entirely when the publisher will not
  /// serve it. A blank rectangle where a photograph should be is worse than
  /// no photograph.
  Widget? _image(BuildContext context, dom.Element element) {
    final src = element.attributes['src'];
    if (src == null || src.isEmpty || src.startsWith('data:')) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HsSpace.x2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: src,
          httpHeaders: ExtractionService.imageHeaders(articleUrl),
          // No explicit size: the image fits the column and keeps its shape.
          // Decoding is capped at the column's own width in device pixels, so
          // a long article does not hold a dozen full-resolution bitmaps.
          memCacheWidth:
              (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round(),
          placeholder: (_, _) => const SizedBox.shrink(),
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  static String _hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}

class _Rule extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: HsSpace.x5),
    child: Container(height: HsSize.hairline, color: context.hs.divider),
  );
}
