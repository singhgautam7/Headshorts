import 'dart:ui' show Color;

import 'package:headshorts/core/tokens/accents.dart';

/// A source in the shipped starter set: pure data, no code.
class StarterSource {
  const new({
    required this.title,
    required this.feedUrl,
    required this.siteUrl,
    required this.category,
    required this.accent,
  });

  final String title;
  final String feedUrl;
  final String siteUrl;
  final String category;
  final SourceAccent accent;
}

/// Small and static on purpose. Real sourcing is the reader pasting a site or
/// importing OPML; this exists so the first run has something to show.
///
/// The accents are the exact pairs specified in the design board.
const starterSet = <StarterSource>[
  StarterSource(
    title: 'The Hindu',
    feedUrl: 'https://www.thehindu.com/news/national/feeder/default.rss',
    siteUrl: 'https://www.thehindu.com',
    category: 'India',
    accent: SourceAccent(Color(0xFFE4A868), Color(0xFF8A5518)),
  ),
  StarterSource(
    title: 'The Indian Express',
    feedUrl: 'https://indianexpress.com/feed/',
    siteUrl: 'https://indianexpress.com',
    category: 'India',
    accent: SourceAccent(Color(0xFF9FC3A3), Color(0xFF37653F)),
  ),
  StarterSource(
    title: 'Scroll.in',
    feedUrl: 'https://feeds.feedburner.com/ScrollinArticles.rss',
    siteUrl: 'https://scroll.in',
    category: 'India',
    accent: SourceAccent(Color(0xFFC6BE7E), Color(0xFF6B6323)),
  ),
  StarterSource(
    title: 'BBC News',
    feedUrl: 'https://feeds.bbci.co.uk/news/world/rss.xml',
    siteUrl: 'https://www.bbc.co.uk/news',
    category: 'World',
    accent: SourceAccent(Color(0xFFE39191), Color(0xFF9C3A3C)),
  ),
  // The design board names Reuters here, but Reuters withdrew its public
  // feeds; shipping a dead address would be worse than substituting a live
  // publisher in the same slot, with the same accent.
  StarterSource(
    title: 'The Guardian',
    feedUrl: 'https://www.theguardian.com/world/rss',
    siteUrl: 'https://www.theguardian.com/world',
    category: 'World',
    accent: SourceAccent(Color(0xFF93B4DC), Color(0xFF2F567F)),
  ),
  StarterSource(
    title: 'Al Jazeera',
    feedUrl: 'https://www.aljazeera.com/xml/rss/all.xml',
    siteUrl: 'https://www.aljazeera.com',
    category: 'World',
    accent: SourceAccent(Color(0xFF86C0BC), Color(0xFF226663)),
  ),
  StarterSource(
    title: 'Ars Technica',
    feedUrl: 'https://feeds.arstechnica.com/arstechnica/index',
    siteUrl: 'https://arstechnica.com',
    category: 'Technology',
    accent: SourceAccent(Color(0xFFB6A6DE), Color(0xFF574289)),
  ),
  StarterSource(
    title: 'The Verge',
    feedUrl: 'https://www.theverge.com/rss/index.xml',
    siteUrl: 'https://www.theverge.com',
    category: 'Technology',
    accent: SourceAccent(Color(0xFFD8A2C4), Color(0xFF8A3C70)),
  ),
];
