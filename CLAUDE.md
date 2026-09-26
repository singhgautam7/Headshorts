# HeadShorts

A calm, finite RSS news reader for Android. Flutter, phone-first, local-first,
no server and no account.

> **A briefing that ends.** HeadShorts reads the feeds you choose, in the order
> they were published. No algorithm, no counts, no infinite scroll. When you
> reach the bottom, that is the news.

The whole product is an argument against doomscrolling: every list terminates,
nothing autoplays, nothing is ranked, and there is no number anywhere that a
reader could feel behind on.

---

## 1. Prime directive

**The design specification at `specs/design/` is law.** Read it before touching
any UI code and match it exactly — layout, spacing, colour, typography,
components, motion, screen behaviour. If anything in this file appears to
conflict with the spec, the spec wins.

`specs/` is **gitignored**; the handoff bundle is not committed. The primary
documents are `specs/design/headshorts/project/HeadShorts Design Board.dc.html`
(v1) and `HeadShorts v2 Design Board.dc.html` beside it (Search, languages,
bookmarks, Listen, list size), with `HS Nav Pill v2.dc.html` as the five-item
pill — Claude Design handoffs, HTML/CSS prototypes rather than production
code. `HeadShorts Store Assets.dc.html` is the Play listing (feature graphic
and five screenshots, exported under `project/exports/`). Recreate the
*visual output*, not the DOM structure.

**Deviations from the spec, and why** — keep this list current:

| Spec says | We ship | Why |
|---|---|---|
| Reuters in the starter set | The Guardian, in Reuters' slot and accent | Reuters withdrew its public feeds; the address 404s. Shipping a dead feed is worse than substituting a live publisher. |
| Scroll.in at `scroll.in/feed` | `feeds.feedburner.com/ScrollinArticles.rss` | The site path returns an empty document. |
| A phone status bar in each mock | The real system status bar (`SafeArea`) | The mock frames draw "9:41"; on a device that is the OS's. |
| The nav pill 22 above the frame edge | 8 above the safe area | The mock measures from the frame; a phone puts the system gesture inset there first, and the pill ends up floating in the bottom margin. |
| More is the settings screen | More is one grouped list: settings rows and hub rows side by side, Appearance as its own page | Stats, AI summaries, About and Privacy are not settings, but a second "Settings" page under More was one tap of indirection for four rows. Grouped headings do the sorting instead. |
| A "Top" sub-tab & category tab strip | Single "Latest" list + "Filter" sheet; no category tabs | Headlines is a single, chronological Latest list. Category selection moves into the Filter sheet (bifurcated by category + enabled sources). Navigation is tap-only (no horizontal tab/category swipe). Stories are deferred to a later phase (design spec stays on file). |
| Fixed India / World / Tech tabs | Categories derive reactively from sources and power the Filter | The mock shows one reader's set. Dynamic category logic is preserved under the hood to populate the Filter sheet options live. |
| Two themes: AMOLED and White | Five families × Light / Dark / System, with AMOLED as a true-black toggle under dark | Perch's appearance model, by request. The board's own palette is the `paper` family and the default; the other four are Perch's, derived in OKLCh. |
| Its own motion tokens (300ms page, 420ms spring nav morph, …) | Perch's M3 Expressive set: 150–260ms, `easeOutBack` for anything the finger caused, `easeOutCubic` for anything the system did | One motion vocabulary across the two apps. The board's curves were replaced wholesale rather than mixed, so nothing runs on two clocks. |
| Linger on the page ground | Linger on pure black / pure white (`HsPalette.lingerBackground`) | Maximum contrast under the one card being read. The card keeps its designed colour; only the ground behind it changes. |
| The Reader's text-size card sits inline under the bar, with a plain slider and "Follows the system setting" | A popover over the prose, with a tick at each of the five steps and the step in effect named where the note was | Inline it never went away and the prose reflowed under it; a slider with no marks read as continuous when it only ever had five values. Tap outside or start a scroll and it is gone. |
| An AI summaries row under More | No row | Nothing to open until the summariser exists; a "Coming soon" screen was one more tap to nowhere. The row returns with the feature. |
| Bundle a Noto face per Indic script | Devanagari bundled; the rest named as fallbacks | Nine more variable fonts is several megabytes for feeds most readers never take up. Android ships the Noto families, so `fontFamilyFallback` resolves them by name; Devanagari is bundled because it is the catalog's second script and must look designed rather than found. |
| Listen's unsupported card offers "Speech settings" | One action, "Not now", and the copy names where to go | Opening Android's text-to-speech settings needs a platform intent, and neither `url_launcher` nor anything else already here can raise one. A button that does nothing is worse than a sentence that does. |
| The v2 no-results screen lists both levers unconditionally | "Search everything cached" appears only when a range is set | Offering to widen a range that is already unbounded is a control that cannot do anything. Under the past-week default it now appears by default, which is where it earns its place. |
| Search's date filter offers "Any time", and opens on it | The longest option is "Everything cached", and Search opens on **Past week** | Both were the same lie in two places: "any time" over a cache holding a few days of feed implies an archive the app has never had. A week is about as deep as a cache search usefully reaches for a daily publisher, so the default states the scope rather than hiding it. The option is kept, not removed — a low-volume feed genuinely has 90 days cached, and that is reachable without the reader constructing a custom range. |

---

## 2. Project facts

- **Application ID / namespace:** `com.grs.news` (Dart package: `headshorts`).
- **Flutter:** latest stable (3.47.x). Track it; do not pin backwards.
- **minSdk 24**, **compileSdk 37** (the adaptive monochrome icon needs 24).
- Android only. iOS scaffolding exists but is not a target.

---

## 3. Architecture

Feature-first, layered. UI ← controllers/providers ← repositories ← data
sources. **No business logic in widgets.**

```
lib/
  app/          entry, router, shell, Riverpod providers, settings & refresh controllers
  core/
    tokens/     palette, accents, typography, dimensions, motion  ← the only place a raw value appears
    theme/      ThemeData wiring + `context.hs`
    widgets/    nav pill, controls, glyphs, sheet, screen chrome, pull-to-refresh, caught-up
    util/       relative time, open-in-web
  data/
    db/         drift database, tables, repositories
                (source / article / bookmark / stats)
    sources/    SourceAdapter + RssSourceAdapter + registry, OPML, starter set
    feed/       http client, feed parser, discovery, refresh pipeline
    readability/on-device article extraction
    prefs/      settings store (shared_preferences)
  features/     search · today · linger · reader · sources · bookmarks ·
                more · stats · onboarding
                more/ is the hub; more/settings_screen.dart is one page in it
```

### Extension point: adding a source

Two levels, both deliberately cheap:

1. **A new *feed* is pure data — zero code.** A source is a row in `sources`
   (`feedUrl` + metadata). Readers add one by pasting a *site* address:
   `FeedDiscovery` fetches the page, reads its
   `<link rel="alternate" type="application/rss+xml|atom+xml">` declarations,
   falls back to a short list of conventional paths, and reports what each
   feed actually contains. OPML import handles bulk; `starter_set.dart` ships
   a tiny static curated list.

2. **A new *source kind* is one class plus one line.** Implement
   `SourceAdapter` (`lib/data/sources/source_adapter.dart`):

   ```dart
   abstract interface class SourceAdapter {
     bool canHandle(SourceType type);
     Future<FetchResult> fetch(SourceRef ref);
   }
   ```

   Add a value to `SourceType`, write the adapter, and register it in
   `adapterRegistryProvider` in `lib/app/providers.dart`. **Nothing else
   changes** — not the pipeline, not the database, not the UI.

---

### The category model

A **category is a label on a source** (`sources.category`) — open-ended, and
the reader's to edit. Nothing else defines it:

- **Latest** is not a category. It is every enabled source merged, minus the
  ones muted there (`sources.mutedInLatest`), deduped, newest first.
- **Categories populate the Filter sheet** reactively for each category with at
  least one *enabled* source, and disappear when the last one leaves.
  Recategorising a feed updates the options live via `categoriesProvider`.
- **Everything downstream reads `activeCategoryProvider`, not the reader's
  raw selection.** A selection left pointing at a category that has since lost
  its last source falls back to Latest. Without that, pausing one feed leaves
  the query filtering on a name nothing is filed under and Today goes blank
  for no visible reason.
- **Headlines is a single Latest list; category browsing lives in Filter.**
  There is no top category tab strip and no horizontal swipe navigation.
  Tapping "Filter" opens the sheet bifurcated by category + enabled sources.
  Applying or clearing the filter displays a skeleton while loading before
  revealing results (Apply/Clear → skeleton → results). Navigation is tap-only.
- **OPML seeds it and stops there.** A feed's nearest ancestor outline becomes
  its category on import; from then on it is just a label like any other.
- **Rename is the whole of category management.** Renaming onto a new name
  creates it; onto an existing name merges the two; a per-source assign moves
  one feed. `SourceRepository.renameCategory` is the only operation needed.
- **The feed's own `<category>` tags are ignored** for structure. They may
  later drive filtering *within* a category; they never define one.

### The bundled catalog

`assets/feeds/starter_feeds.opml` ships ~58 verified feeds across nine
categories and eight languages, parsed once per launch into `SourceCatalog`
(`sourceCatalogProvider`). It is a **directory to search, not a starting
state** — nothing in it is subscribed until the reader says so.

- **An OPML asset rather than a Dart list**, because that is the format the app
  already imports and exports: a curated set is edited the same way a reader's
  own subscriptions are, and the parser is exercised by the app's own data on
  every launch.
- Accents travel in `hsAccentDark` / `hsAccentLight`, our own OPML extension,
  so the design board's eight survive the round trip byte-for-byte (asserted by
  test). Anyone else's OPML omits them and the app derives a tone instead.
  `language` is the same kind of extension, and an omitted one reads English.
- The Indic feeds carry no baked accent: `accentFor` derives a stable tone
  per feed address, which is the same path anything the reader pastes takes.
- **Every URL in the file was fetched and checked before shipping.** Eight
  candidates were dropped for 403/404/empty responses in v1, and more in v2 —
  Jagran, Navbharat Times, Bhaskar, Aaj Tak, Dinamani, Mathrubhumi and
  Livehindustan all answer 404, 500 or 503 at the addresses they publish.
  Re-verify before adding more — a dead feed in the catalog is worse than a
  short catalog.
- `search(query)` matches case-insensitively on name *and* category, and every
  whitespace-separated term must match, so a second word narrows. An empty
  query browses everything. `grouped(query)` returns the same results grouped
  by category in catalog order.

The catalog is the only source list: `starter_set.dart` is gone, and the
onboarding picker and the Sources screen both read from `SourceCatalog`.

`accentFor` is **idempotent** — the catalog bakes derived accents into the file
and the app resolves them again at read time, so those two must agree. Getting
there needed a loop: squeezing a colour back into 8-bit sRGB moves it, so one
pass does not always land inside the band, and a single pass would shift a
channel on every launch. It iterates to a fixed point instead.

### Search looks through the cache, not the web

Search is the fourth tab, where the board's pill draws it. It is the same
argument as every other list here:
finite, date-ordered, and **never ranked**. FTS5 will happily sort by bm25
relevance; it does not, because a list whose order you cannot predict is a
list you have to keep checking.

- **The index is SQLite FTS5 in external-content mode** (`articles_fts`, built
  in `HsDatabase._createSearchIndex`). It stores the terms, not a second copy
  of the text, and reads the columns back out of `articles` by rowid. Three
  triggers keep it in step, because an external-content table is not
  maintained by SQLite on its own — insert, update and delete each have one,
  and a fresh index over an existing table is told to `rebuild`.
- **The tokeniser is `unicode61 remove_diacritics 2`.** Without it a whole
  Devanagari or Tamil headline tokenises as one term and a Hindi search
  matches nothing. This is not a nicety; it is what makes §2's languages
  searchable at all.
- **The query is quoted and starred** (`ftsQuery`): every term becomes
  `"term"*`, so `heat wav` finds "heatwave warning" while a stray quote,
  hyphen or the word `AND` is a word rather than syntax that throws. A query
  of punctuation alone is not a query and returns nothing.
- **`searchArticleIds` returns ids**, and the join back through `sources` is a
  normal drift query — nothing downstream has to read prefixed result columns.
- Results are deduped by the same `dedupeStories` as every other list, and
  capped at `searchResultLimit` (200). The list ends in a plain count, never
  a "load more". **There is no pagination and there should not be**: the cap
  is what makes the list finite, and `ListView.builder` over the flattened
  rows already builds only what is on screen. The range opens at **past
  week** (`SearchDateRange.initial`), never unbounded.

**What Search must not be rebuilt by.** It covers a *set of sources*, so it
watches `sourceEntriesProvider` — the catalog and subscriptions **without**
the unseen counts. Those counts stream out of `articles` and tick on every
refresh and every article opened; watching the counted list meant **opening
an article fired a fresh Google News request**, which was measured with a
probe before the split and after it. `allSourceEntriesProvider` layers the
counts back on for the Sources screen, and nothing that only needs the set of
sources should watch it.

**A feed fetched for a search is remembered for five minutes**
(`_fetchedFeedsProvider`). A source in scope with nothing cached is fetched
on every search, and refining a query runs several — so an unfollowed source
added to the scope was re-downloaded on each one, for identical items. In
memory only: a search must never quietly subscribe anybody to anything.

**Settings are read before the first `await`.** `ref.watch` past an await
registers a dependency on a provider that may already have moved on, and
Riverpod is entitled to throw for it.

**Scope is a lens, exactly like Filter.** `searchScopeProvider` holds feed
addresses, and **null means "whatever I follow and have switched on"** rather
than a snapshot of it — a source enabled tomorrow is in scope tomorrow
without the reader coming back to add it. Adding an unfollowed source
searches it once: it does not subscribe, does not fetch on a schedule and
does not appear in the briefing. An **empty** scope finds nothing, because
saying so beats quietly falling back to everything.

A **paused source is still searchable.** The scope decides what is in, not
the subscription — the cache still holds what that source published, and
refusing to look in it would be a second, invisible filter.

**A source with nothing cached is fetched on the spot** (`_searchLive`): one
request, filtered in memory, **nothing written to the database**. That is the
honest shape of "search a source I do not follow". It also means the date
range reaches back exactly as far as that publisher's current feed does and
no further, which the end of the results says in words — an RSS feed is not
an archive, and implying one would be a lie the reader only discovers later.

**The trigger is an empty cache, not an absent subscription.** These are not
the same thing, and conflating them is what shipped in the first v2 build:
the rule was `!isSubscribed`, so a source added a minute ago, one the prune
had emptied, or one paused long enough to lose its items was skipped — it was
subscribed, so it "had" a cache, and searching it returned nothing while
looking like it had looked. `ArticleRepository.sourcesWithCache` answers the
real question, and `search_live_test` pins both halves.

### Google News is the wider net, and it is labelled

A feed carries only its most recent items, so a cache-only search cannot
answer "has anyone written about *this person*". Measured on a real install:
six sources, one fetch, 369 articles spanning six days — and the word the
reader searched for appeared in none of them, nor in any article body. No
amount of re-fetching the same feeds changes that. Searching *beyond* the
feeds needs a different source of results.

`GoogleNewsSearch` asks `news.google.com/rss/search`, parses the RSS, and
returns `WebResult`s — a **separate type** from `ParsedArticle`, so nothing
from the web can drift into the briefing by accident. Nothing is stored.

- **Its own group, always labelled.** Results land in `SearchOutcome.webHits`,
  never mixed into the day headings above, under a "From Google News" heading.
  The reader's own publishers are the answer; this is the net under it.
- **The heading is the label and nothing else.** It carried a paragraph
  explaining the group and the privacy position, which is both the wrong
  moment — the term has already been sent by the time it is read — and a wall
  of small print between the count and the first result. That copy now sits on
  the **empty state**, where it is a heads-up before the reader types.
- **A story the reader already has is dropped**, matched on the headline
  fingerprint — a Google News link is a redirect and shares no address with
  the publisher's own, so `canonicalUrl` cannot catch it. A headline too
  short to fingerprint is kept, as everywhere else: a false merge is worse
  than a duplicate.
- **The publisher comes from the `<source>` element**, and Google's trailing
  " - Publisher" is stripped from the title, because the card already prints
  the publisher above the headline. Only the *trailing* occurrence, and only
  when it matches the publisher — real headlines are full of dashes.
- Its accent is derived per publisher, the way a pasted feed's is. Nothing
  here is subscribed, so there is no accent of the reader's to use.
- `when:1d`/`7d`/`1m` narrows at Google's end so a "past week" search does
  not drag a year back to throw most of it away; the range is applied again
  to what returns.
- **Failure is ordinary.** No contract is published for this endpoint. A
  timeout or a parse failure returns nothing and the reader's own results
  stand alone — the group simply does not appear.
- Header count and footer total both count the web group. Two different
  totals on one screen read as a bug, and did.
- **When the reader's own sources found nothing, the count line says so**
  ("Nothing from your 6 sources.") and the group's divider is dropped.
  Without it there is a stretch of empty screen between the count and the
  heading, and the heading becomes the first hint that the cache came up
  empty — which reads as a rendering fault rather than an answer.
- **A result opens through the reader's own "Open links" choice.** Search
  used to pass nothing and so forced a Custom Tab on somebody who had asked
  for their own browser.

**A Google News link cannot be opened in the Reader**, and this was measured
rather than assumed. The `<link>` is an opaque token
(`/rss/articles/CBMi…`), which decodes to `AU_yqL…` and not to a URL; the
page it serves is 590KB of Google with no destination in it, resolved
client-side; and not one of a hundred items carried a direct publisher link.
The only way through is Google's private `batchexecute` RPC — a second
undocumented dependency that would break without notice and leave a tap
doing nothing. So these hand off to the browser, and the group says so.

**The query leaves the device, and that is the only thing that does.** It is
the single exception to "nothing is ever sent anywhere", so it is stated in
three places: on Search's own empty state **before** anything is typed, on the
Privacy screen, and as a setting (More → Search the web) that turns it off.
The empty-state line is shown only while the setting is on, and says the same
three things the heading used to: the feeds are shallow, so Google News is
searched as well; the search term is sent and nothing else is; those results
open in the browser. `search_loader_test` pins all three and pins that the
heading no longer repeats them. On by default, because a search
that cannot see past the last few days of six feeds is the thing readers
report as broken.

**Search does not refresh what is already cached.** A source with items is
read, never re-fetched, so a search costs nothing and works on a plane. The
consequence is worth stating plainly, because it surprises people: for a
reader whose sources are all subscribed and populated — which is everyone,
by default — **Search never touches the network**. It searches what the last
refresh brought in. Anything a feed dropped before that refresh was never
cached and cannot be found, and re-fetching would not find it either: a feed
carries its most recent items and nothing else. Searching *beyond* the feed
needs a different source of results, not a fresher fetch of the same one.

The date range is by **publication** date, never by when an item was fetched:
a feed that arrives late is still the day's news.

### Why the cache misses what Google finds from the same publisher

The most confusing thing about Search, and the one readers report as a bug:
Google News returns results from The Hindu, the Times of India and Livemint —
all of them subscribed, enabled and refreshing — while the reader's own copy
of those publishers finds nothing. Nothing is broken. The two are searching
different corpora, for three compounding reasons:

1. **A feed is not an archive.** It carries a publisher's most recent items,
   usually a few dozen. The cache is what those feeds handed over since the
   reader subscribed; Google indexes the publisher's whole site, months back.
   Measured on a real install: six sources, 369 articles, **six days** of
   span.
2. **The prune caps 200 items per source.** For a publisher running hundreds
   of stories a day that is well under a day of depth, whatever the date
   range says.
3. **Only headlines and summaries are indexed** — `articles_fts` covers
   `title`, `summary` and `content_snippet`, which is what a feed provides.
   Google matches full article text, so a person named halfway down a story
   matches there and not here. This is **not** worth fixing by indexing
   `full_content_html`: it is null for almost every row, because a body is
   only fetched when the reader opens that article. There is no body text to
   index.

So the same story is often *in* the cache and simply not matching, and just as
often was never in the feed window at all. Neither is a fetch away — which is
why the lever is Google News rather than a fresher refresh, and why the
explainer says so instead of the app quietly widening the query.

**"See why?" is the answer, offered where the question is asked.** An
underlined link **beside** "Nothing from your 6 sources.", in a `Wrap` so it
drops to its own line rather than overflowing the sentence, opening
`showCacheExplainer` — one `InfoSheet` (`features/search/cache_explainer.dart`),
no new design. Its shape is a one-line summary, the two reasons as a numbered
list, and the caveat as the muted note: three dense paragraphs said the same
thing and filled the screen, which is a sheet a reader closes rather than
reads. The **third** reason — headlines and summaries are indexed, not bodies
— is left to this file; it is the rarest case and the one least worth a
screenful. It sits there rather than in More because that line, with the
same mastheads listed directly below it, is the exact moment the reader
concludes the app is broken.

### Where subscription lives

Everything that changes *what the app fetches* is in Sources or Settings, and
every one of those changes flows through the reactive store, so Today and
Linger reflect it without anything being told to reload:

| Screen | Does |
|---|---|
| **Search** | The fourth tab. A query over the cache, scoped to the sources the reader picks, in a date range. Two sheets: scope and date |
| **More** | Grouped rows in Perch's settings dress — Saved (Bookmarks) · General (Appearance, Open links, Text size, List size, Read aloud, Reading fairness, Check for new) · Your data (Stats, Data, Permissions) · About HeadShorts (Privacy, About) — the real version line and "Made with ❤️ in India" at the foot. Every one-of-N row opens `showOptionSheet`; nothing cycles in place |
| Bookmarks | One pushed page under More: saved articles newest-saved first, swipe or long-press to remove with Undo, and an empty state that names where the control is |
| About | Kuber's arrangement in HeadShorts' dress (`about_screen.dart`): a note from the maker on the settings card, four tiles for what the app stands for, what it is in a paragraph, the version, and a developer group linking the portfolio (singhgautam.com), the other apps on Play, and the listing. Plain hyphens only; no em dashes in the copy |
| Data | One page inside More: Export OPML (through the system share sheet — Android's save dialog is not available to `file_selector`), Import OPML, Clear cached articles |
| **Sources** | The **whole catalog** plus the reader's own additions, searchable, grouped by category, one toggle per source. Also renames a category, and opens a source |
| Sources → Add | Feed discovery from a pasted site address, for anything the catalog does not have |
| Source detail | Category, accent, Mute in Latest, Unsubscribe |
| Appearance | One page *inside* More, in Perch's arrangement: Light / Dark / System, a true-black toggle while dark is in effect, five families drawn as miniatures, and the blur-behind-nav toggle. No dynamic colour — that needs a native wallpaper-seed channel the app does not have |

**Sources shows the same list the onboarding picker showed.** The place a
reader chose their sources is the place they change them, so there is no
separate "browse the catalog" screen to go and find — `manageableSourcesProvider`
merges the catalog with `sources`, matching on `feedUrl`, so a subscribed
publisher is one row carrying its live state rather than two.

The toggle means **"in my briefing or not"**:

- Off → on, not yet subscribed: subscribe, then refresh, so the reader gets
  items rather than an empty category.
- Off → on, already subscribed: re-enable. The cached items come straight
  back.
- On → off: **pause**, never unsubscribe. The subscription and its items
  survive, so turning it back on is instant.

Unsubscribing is destructive — it takes the source's articles with it — so it
stays a deliberate act on the source's own screen, not a toggle.

Two settings do real work rather than being stored and ignored:

- **Open links** picks the `LaunchMode` — a Custom Tab, or the reader's own
  browser. Threaded through to `ArticleBody` so in-article links honour it too.
- **Check for new** gates `refreshIfDue`, which is what launch and tab-return
  call. An explicit pull or tap on the refresh mark calls `refresh` and always
  fetches: an ask is never quietly ignored.

**Clear cached articles** deletes articles *and* read events, and keeps
subscriptions. Read state goes with the rows that carried it — leaving "read"
markers pointing at nothing would be worse.

### Language is a label, like a category

`sources.language` is a BCP-47 tag and nothing more. It filters; it never
changes what is fetched, and there is no such thing as a paused language.

- **The catalog states every tag** (`language=` on each OPML outline, our own
  convention — OPML has none). Anyone else's export omits it and the app
  reads English, which is what every other reader assumes anyway.
- **A filter offers only languages that have a source behind it**, and hides
  itself entirely when there is one — a control with a single option is
  furniture. Headlines' Filter puts language above Category; the onboarding
  picker, Sources and Search's scope sheet each carry `LanguageChips`. Each
  language names itself **in its own script**.
- **The language filter is a scrolling chip row, not a segmented control.**
  The board draws three segments because that reader follows two languages;
  the catalog offers eight, and eight equal-width segments wrap every label
  into a broken stack — which is exactly what the emulator showed. A row that
  scrolls holds any number and keeps each name whole.
- **Where the reader is browsing the catalog** — onboarding and Sources — the
  filter offers every language the catalog carries, not only the ones already
  followed. The point of the first run is to find publishers you do not have.
- Language narrows a list rather than greying it out: with English chosen,
  the Hindi sources drop out of the Filter's chips altogether, because a chip
  you cannot usefully turn on is noise.
- On Headlines it folds into the muted set (`offLanguageSourcesProvider`).
  To the briefing query, "hidden by language" and "hidden by the filter" are
  the same thing, so nothing downstream needed a second parameter.
- **The row tag is spoken in full.** "Hindi", never "H I" — a screen reader
  spelling a code out is worse than no label.

**Indic type is a stack, not a second design.** Source Serif 4 and Archivo
carry no Indic glyphs, so every role names a fallback (`HsType.serifFallback`
/ `sansFallback`). Fallback is per-glyph, so a headline mixing Latin and
Devanagari sets each run in the right family without anything detecting a
script. Noto Devanagari **ships with the app** in both voices; the other
scripts name Android's own Noto families.

The metrics change with the script, from the board's type table: the line
opens up (19/1.32 becomes 19/1.50, 17/1.72 becomes 17/1.85) and
letter-spacing goes to zero, because tracking pulls a conjunct apart into its
halants. The **size never changes** — a Devanagari headline is the same
headline. `HsType.forText` decides from the text itself rather than the
source's tag, because an English-tagged feed still carries the odd
Devanagari headline; `sourceLabelFor`/`sourceLabelText` additionally drop the
caps, since there is no case to raise.

### Saved articles outlive the cache

A bookmark is a **copy, not a pointer**. The `bookmarks` table holds
everything needed to render the article — title, source, accent, author,
date, link, image and the extracted body — and references `articles` only
through a plain nullable `articleId` that is deliberately **not** a foreign
key.

That is the whole design, and it follows from what would otherwise happen to
a saved article:

| | What would take it | What actually happens |
|---|---|---|
| `pruneToRetention` | Newest 200 per source, 90-day window | Both `DELETE`s carry `AND link NOT IN (SELECT link FROM bookmarks)` |
| `clearCache` | Everything | Same exemption |
| Unsubscribing | The FK cascade from `sources` | No FK, so the bookmark stays; the article row does go |

The article row is spared as well as the bookmark, so `/reader/:id` keeps
working. When it has gone anyway — the source was unsubscribed — Bookmarks
opens `/bookmark/:id` and the **same** Reader renders the snapshot:
`ReaderDoc` resolves from either store (`readerDocProvider`,
`readerBodyProvider`), so "open a saved article offline" is not a second
screen that drifts.

Saving is keyed on the **link**, not the row id, so the second feed's copy of
a story reads as saved and saving it twice updates one row. A bookmark made
before extraction finished is saved at once with whatever body has arrived
and the text **catches up** when it lands (`attachBody`) — the confirmation
is immediate and the promise still holds.

Removing is a swipe, a long-press menu **and** a TalkBack custom action: a
swipe is never the only way to do anything. Undo holds for five seconds and
puts the row back exactly as it was.

### Listen is the phone's own voice

Read-aloud is `flutter_tts` over the engine already on the device. Nothing
leaves the phone — it is the same engine TalkBack uses, handed a string.

- **It reads `FeedParser.blockText`, not `plainText`.** The latter collapses
  *all* whitespace, which is right for a title and wrong for a body: the
  whole article becomes one line, so it would be one utterance with one
  "current paragraph", and "…a 45-minute clash." would meet "Star Indian
  weightlifter…" with no space between them. `blockText` splits on block
  closers and gives the paragraphs back. The extracted snippet uses it too.
- **It reads plain text, and shows plain text.** The engine reports a word as
  a character range in the string it was given, so the string it was given
  has to be the string on screen. `ListenView` stands in for the rendered
  body while it reads and the rich rendering comes straight back after.
  Mapping ranges back through markup breaks the moment a publisher puts a
  link in the middle of a sentence.
- **One utterance per paragraph.** Offsets are utterance-relative, so a whole
  article as one utterance puts every offset thousands of characters out.
  A paragraph is also the natural unit to scroll to.
- The sentence in hand takes the source accent at 32% under full ink; the
  spoken word is solid accent on the page ground; everything else steps back
  to secondary. Highlighting can be switched off and is **never the only cue
  to position** — the progress bar and the time are.
- **The voice stops when the Reader does.** `ListenController.shutdown()` is
  called from the Reader's `deactivate`, its `dispose` and on any lifecycle
  state but `resumed`. It silences the engine **without touching `state`**,
  because by then the provider may already be disposed and writing to it
  would throw — and the one thing that must still happen is the voice
  stopping. Dropping every reference to the engine does *not* stop it: it
  speaks on its own thread until told otherwise, which is why this is an
  explicit call rather than something left to `onDispose`. Backgrounding
  stops rather than pauses: a voice that starts talking again when the
  reader comes back to check the time is worse than losing the place.
  `listenSupportedProvider` is auto-dispose for the same reason — a provider
  that outlived the Reader would hold the controller, and the engine, alive
  with it.
- **Support is checked before anything is spoken**, in the background
  (`listenSupportedProvider`). The overflow menu never waits on the speech
  engine to open: when the answer is already in hand and negative, Listen
  carries the reason as a sub-line, in secondary ink rather than greyed out,
  and still opens the card that explains. An option that disappears leaves
  the reader wondering what they did wrong.
- **Every platform call is guarded.** A phone with no speech engine at all —
  or a test, which has no platform — must leave the Reader working rather
  than throwing out of a button tap.
- The listen bar takes the action row's place in the same pill dress and
  **does not hide on scroll**: losing a row of links while reading is
  nothing, losing the pause button while something is talking is not. The
  page follows the reading; a manual drag stops it following and offers
  "Back to reading" rather than fighting the thumb.
- Speed is five steps, not a slider, and the voice is remembered **per
  language** — a voice picked for English says nothing about Hindi. Both
  restart the current paragraph when changed mid-article, which is the only
  way an engine will take a new setting.
- The times on the bar are estimated from characters at the chosen rate. No
  engine reports a duration up front; the bar says so by being an
  orientation rather than a measurement.

### List size is one setting, three lists

`ListSize` is read by Headlines, Search and Bookmarks alike: a reader who
picks Small gets Small everywhere. The button lives only on Headlines, **beside
Filter and in Filter's dress** — both narrow what this list shows, so they
belong to each other rather than to the title — and opens an **anchored menu
rather than a sheet**, so the list stays visible behind the choice. It is
icon-only, so it names itself on a long press. More carries the same setting
as a row.

`HeadlineCard` takes an `ArticleView` — built from a cached article, a
bookmark snapshot or a live search hit — so one card serves three row types
and a fix to it is a fix everywhere. Large is the v1 card unchanged. Medium
drops the standfirst, sets the headline a step down, clamps it to three lines
and shrinks the thumbnail. Small is headline only: two lines, the source run
in at the start in its accent, the time right-aligned, hairlines doing the
separating instead of rules and images — and still a 44dp target.

### Filter is not selection

Two controls look alike on screen and must never be confused:

| | Home's "All sources" | Sources / Settings |
|---|---|---|
| What it is | A **view filter** — `mutedSourcesProvider`, in memory | **Subscription**, a row in `sources` |
| Scope | The list in front of the reader, right now | The whole app, until changed |
| Survives a restart | No | Yes |
| Changes what is fetched | Never | Yes |
| Changes the category tabs | Never | Yes |

Conflating them would quietly unsubscribe people, so `filter_vs_selection_test`
holds the line: hiding a source in Home leaves it subscribed, enabled, fetched
and still owning its category tab.

Category tabs derive from **subscribed** sources' categories, so adding a Tech
source makes that tab appear and unsubscribing the last one removes it. That is
end-to-end tested from `SourceCatalog` through `SourceRepository` to
`watchCategories` and `watchBriefing`.

### De-duplication

The same story reaches the app twice — a publisher's feed and an aggregator's,
a national and a regional edition — and it is one thing to read.

- **Within a feed:** `(sourceId, guid)`, falling back to the link.
- **Across feeds:** `articles.canonicalUrl` — the link with tracking
  parameters stripped, `www`/`m`/`amp` hosts and trailing slashes normalised,
  and aggregator redirects unwrapped when the real address is in a query
  parameter. Then `articles.titleKey`, a stemmed, sorted fingerprint of the
  headline, for the same story filed under two different titles.
- Both keys are computed at upsert and stored, so dedup and read-state
  propagation are both indexed lookups rather than scans.
- **A false merge is worse than a duplicate.** An item with neither key is
  always kept, and a headline too short to fingerprint gets no title key.
- Google News wraps the publisher's URL in a redirect. `canonicalUrl` unwraps
  it when the address is in the query string; a redirect that only resolves
  over the network is not followed, so an overlap can survive. Prefer
  subscribing to the publisher or the aggregator, not both.

### Seen and read are two different things

Two independent flags on the article row. Conflating them is what makes a
reader feel they have "used up" an article by glancing at it.

| | Set by | Effect |
|---|---|---|
| `seenInLinger` | A Linger card settling as the active card, after a 500ms dwell | Keeps it from coming round again **in Linger**. Nothing else. |
| `readFull` | Opening the full article, from Today **or** Linger | The only thing that counts as reading. Removes it from Linger; subtly de-emphasises it in Today. |

The rules that follow from that, and that the tests pin:

- **Linger sets `seenInLinger` only.** It never sets `readFull`, and never
  affects Today.
- **Opening the full article is the only thing that sets `readFull`.**
- **Today marks nothing.** Scrolling past an item in Today changes no state at
  all. `readFull` de-emphasises an item there; it never hides it.
- The dwell matters: a fast flick through the stack must not consume the queue.
- Both flags propagate across **every copy of the story** (rows sharing a
  `canonicalUrl`). Without that, the second feed's copy of an article you have
  already dealt with comes straight back, because de-duplication only collapses
  copies that are all still in the result set.

**Net effect:** an item seen in Linger disappears from Linger and still shows
normally in Today. Opening its full article marks it read, which removes it
from Linger and de-emphasises it in Today.

### Linger has one Filter button

`LingerFilter` is a category plus, optionally, the set of sources to keep —
held for the session in `lingerFilterProvider` and the only thing that decides
what `buildLingerQueue` is asked for. The sheet reuses Today's filter-sheet
pattern: category chips, then the in-scope sources as selectable tags.

It is a **filter**, and the same line holds here as on Today: only subscribed,
enabled sources appear, and nothing in the sheet adds, removes or pauses one.
The draft is edited in the sheet and committed on Apply, so a half-made choice
never rebuilds the queue under the reader; Apply and Clear both close the
sheet, and the queue shows its skeleton while the new one is built.

Two details the tests pin: a null source set means "all of them" (so a source
added later is included without being re-picked) while an **empty** set means
nothing — saying so beats quietly ignoring the reader's own filter — and
changing category clears the source picks, because a pick from another
category would leave a filter matching nothing.

### Linger's queue is a snapshot

The unseen-and-unread filter is applied **when the queue is built**, never
live. Marking the card in front of the reader as seen must not pull it out
from under them — filtered items simply do not return next time.
`LingerQueueController` owns the queue and the reader's position in it.

When a refresh finishes, newly arrived unseen-and-unread items are **merged**
into the queue at their chronological place and the index is re-anchored to
the card the reader was on, so refreshing Today brings the latest news into
Linger without moving anyone.

### Today paginates

Keyset pagination over `(publishedAt DESC, id DESC)` — the id breaks the ties
that feeds create by stamping several items with the same minute. The window
is bounded by the cursor of the last loaded item, never by an offset, so a
refresh that prepends new items cannot make the list skip or repeat one under
the reader. `todayPageSize` is 25; the next page loads as the reader comes
within a screen of the end.

`atEnd` is never latched on an empty cache. Nothing below a window that has
not been opened yet is an empty cache, not the end of a list — latching there
is what stopped Today ever paging again after a first run that arrived before
its items did.

The line above the list says when the briefing was last fetched, not how long
it is — the category tab already carries the count, and a second number here
(the loaded page against the whole category) read as a bug.

It stays finite: when the cache is exhausted the list ends in "You're caught
up". Nothing is ever fetched from the network by scrolling, and nothing says
"caught up" until a refresh has actually finished
(`awaitingFirstFetchProvider`).

### Firehose control

Strict chronological order plus dedup is the default, and the only default.
Two opt-in controls exist, and neither ranks anything:

- **Mute in Latest**, per source — keeps a firehose out of the merged list
  while leaving it in its own category.
- **Cap items in a row from one source** (`maxConsecutivePerSource`, off by
  default) — an item that would exceed the run is held back until something
  from elsewhere breaks it. Nothing is dropped or scored. It is labelled
  fairness, because that is what it is.

## 4. Data model

- **sources** — id, title, siteUrl, feedUrl (unique), category, `language`
  (BCP-47, default `en`), `accentDark` / `accentLight` (the accent's two
  tones), type, enabled, `mutedInLatest`, sortOrder, etag, lastModified,
  lastFetchedAt, addedAt, `failingSince`, `lastError`.
- **articles** — id, sourceId (FK, cascade), guid, title, summary,
  contentSnippet, `fullContentHtml` (nullable — only when a full-content feed
  or extraction supplied it), link, `canonicalUrl`, `titleKey`, author,
  publishedAt, imageUrl, fetchedAt, `seenInLinger`, `readFull`. Unique on
  `(sourceId, guid)`.
- **read_events** — articleId, mode, at, dwellMs. Reading time comes from here,
  not from a column on `articles`.
- **bookmarks** — id, `articleId` (nullable, **not** a foreign key), link
  (unique), canonicalUrl, title, summary, `contentHtml`, author, imageUrl,
  sourceTitle, language, `accentDark` / `accentLight`, publishedAt, savedAt.
  A snapshot: see "Saved articles outlive the cache".
- **articles_fts** — an FTS5 virtual table in external-content mode over
  `articles(title, summary, content_snippet)`, kept in step by three
  triggers. It holds terms, not text.
- **caught_up_days** — one row per day the reader reached the end of Today.

Rules:

- **Dedup on `(sourceId, guid)`**, falling back to the link when a feed omits
  the guid.
- **Cache-first.** The database is the source of truth the UI watches; the
  network only refreshes it. Every screen opens instantly from cache.
- **Finite.** Every query is bounded. There is no cursor and no "load more".
  Lists end in "You're caught up"; swiping past it settles back.
- **Retention.** `pruneToRetention()` keeps the newest 200 items per source
  after each refresh, and drops anything past the 90-day window. **A
  bookmarked link is exempt from both**, and from `clearCache()`.
- Updating an article never erases a `fullContentHtml` the feed has stopped
  sending.
- **Schema version 4.** Adding or renaming a column means bumping
  `schemaVersion` and adding a step to `MigrationStrategy.onUpgrade` in
  `database.dart`. v2 added the de-duplication keys and `mutedInLatest`; v3
  renamed `read_in_reel`/`read_in_full` to `seenInLinger`/`readFull`, which
  carry over as-is because the old flags meant exactly those two things; v4
  added `sources.language` and the `bookmarks` table. The search index is
  created in `beforeOpen` rather than in a migration step, so a database
  whose index was dropped rebuilds itself on the next launch.

---

## 5. Fetch pipeline

**Onboarding and a refresh are the same code.** `RefreshService.refreshAll()`
is the only path that fetches anything, and it is what the first run, the
launch check, a pull and the refresh mark all call. There is no first-run
special case and no date window: a feed is fetched for whatever it currently
contains, whenever it was published. Nothing anywhere filters on install time,
and `pipeline_test`/`fetch_pipeline_test` pin that — an item dated two years
before the subscription existed still reaches Today.

Per source: conditional GET with the stored ETag/Last-Modified → parse →
upsert → record success or failure.

- **At most `RefreshService.concurrency` (6) feeds are in flight**, through a
  fixed-width pool. Starting all forty-five at once is not faster on a phone:
  it exhausts the connection pool and times out feeds that would otherwise
  have answered. Outcomes are still emitted in completion order, so one slow
  feed never holds up the bars for the rest.
- **Every feed has a `perFeedTimeout` (15s) ceiling** on the whole attempt,
  retry included, so a feed that stalls between bytes cannot hold the run.
- **Parsing runs on a background isolate** (`compute(FeedParser.parse, body)`).
  A 300KB feed costs hundreds of milliseconds to parse; a run of them on the
  UI thread is what made the first briefing look frozen — the bars were
  filling, the frames were not.
- **`_refreshOne` never throws.** It used to be able to: a malformed document
  that a parser choked on threw past the adapter's `FormatException` catch,
  `Stream.fromFutures` carried the error, the whole run stopped, the remaining
  feeds were dropped, and the reader arrived at an empty briefing that claimed
  to be caught up. Every failure is now recorded against its own source.
- **Items are stored before the validators that would 304 them.** Writing the
  ETag first means the next refresh answers 304 for content that was never
  saved: the feed goes quiet and nothing says why.
- A 304 costs a header exchange and nothing else.
- A dead feed is state recorded against the source (`failingSince`,
  `lastError`), stated in words on that source's own screen. It never becomes
  an error dialog or a red dot. Retries stop after 14 days.

**Requests carry a browser user agent**, feeds included — the same string the
Reader sends for article pages. Publishers refuse an unknown client outright:
Business Standard answered `HeadShorts/1.0` with a 403 and a browser string
with the feed.

**The client speaks HTTP/2 wherever the server offers it** (`_Http2WhenOffered`
in `http_client.dart`: `dio_http2_adapter` over `https`, Dart's own client
for `http` and for hosts whose ALPN does not name `h2`). Dart's `HttpClient`
is HTTP/1.1 only, and NDTV's Akamai edge answers an HTTP/1.1 article request
with 403 whatever headers it carries — that, not the page, was why NDTV
articles came back "did not return the page". The h2 adapter hands back wire
bytes, so the wrapper inflates gzip itself; `br` is offered only at `q=0.1`
and there is no brotli decoder (add `package:brotli` if a server ever insists).

**Article pages are asked for the way a browser navigates**
(`ExtractionService.pageHeaders`): `Accept`, `Accept-Language`,
`Accept-Encoding` naming `br`, and the four `Sec-Fetch-*` headers. Each was
bisected against NDTV's edge; drop any one and the answer is 403 again.

**The reader is never told "caught up" over a cache that is still filling.**
`RefreshProgress.finished` marks a run that reached the end; until the first
one does, an empty briefing renders as the skeleton rather than the empty
state. `RefreshController.refresh()` **joins** a run already in flight rather
than returning immediately, so onboarding's await actually waits.

Launch behaviour: open to cache, refresh behind the content, show a quiet
"updating…" and offer pull-to-refresh. **The only blocking loader in the app
is the first-run fetch in onboarding**, and it reports one bar per feed,
filling as each returns.

### Text fields are decoded; bodies are not

Feeds escape their plain-text fields, and a fair number escape them twice
(`&amp;amp;`). `FeedParser.plainText` strips markup and decodes entities until
the text stops changing, at most `_maxDecodes` (2) times — on top of the one
pass the XML layer has already done, which is three levels deep and further
than any real feed goes. Title, summary, snippet, author and OPML category all
run through it.

`fullContentHtml` deliberately does not: the Reader's pipeline parses that as
markup, and decoding it here would destroy the document.

## 6. Design & behaviour guardrails

**Token-only styling.** No hardcoded colour, size, radius, duration or curve
outside `lib/core/tokens/`. Widgets read colour roles through `context.hs`
and per-source accent through `AccentScope.of(context)`.

**One theme system.** `HsPalette` is the only colour source, and
`ThemeFamily.colors(tone)` is the only thing that makes one. The `paper`
family returns the board's three hand-set constants (`light`, `dark`,
`amoled` — the board draws the two extremes; `dark` is the step between);
the four Perch families derive theirs in OKLCh exactly as Perch does and map
the result onto the board's roles, so nothing downstream knows which it got.
`hsThemeOf(family, tone)` caches one `ThemeData` per pair and `buildHsTheme`
maps every Material role onto the palette — a full `ColorScheme` plus card,
app bar, sheet, popup-menu, switch and selection themes — so a stray Material
widget cannot introduce an off-spec colour. `HsPalette.lerp` (in oklab) is
what the theme cross-fade plays. There is no second role map: an earlier pass
carried Perch's `PerchColors` in beside `HsPalette` and bridged the two with
lossy converters, which is what made colours drift. One struct, one engine.

**Primary is a role, not ink.** `primary`/`onPrimary` and
`primaryContainer`/`onPrimaryContainer` are what the primary button, a toggle
that is on, a selected chip, the sub-tab underline, the active nav item and a
picker's selected row use. In the board's family they *are* ink and the nav's
active well, so the design is unchanged; in a Perch family they carry the
accent. Nothing else in the app takes the family accent — the per-source
accent rule below is untouched by the theme.

**Themes:** five families × Light / Dark / System, and a true-black toggle
that applies only while dark is in effect. Default: Paper, dark, true black —
which is the board's AMOLED.
The accent rule: a source accent is a **label, a hairline bar, and — in Linger
only — a wash panel**. Never a saturated card fill. 15% over black, 7% over
paper.

**Colour arithmetic is done in oklab, never sRGB.** The design board writes
its mixes as `color-mix(in oklab, …)` and the difference is not cosmetic: 15%
of a light accent over black comes out `#221616` in sRGB and `#090303` in
oklab — three times brighter, which is the difference between a coloured card
and a whisper of hue. `Oklab.mix` in `core/tokens/oklab.dart` is the only
correct way to blend two colours here; `Color.lerp` and `Color.alphaBlend` are
not. Light-theme mixes happen to land in the same place either way, which is
why only AMOLED looked wrong.

**A raw colour never reaches the UI.** Everything goes through
`accentFor(Brightness, Color)`. The design board's own nine accents pass
through untouched — that is asserted by a test — and anything else (a
publisher's brand red, a hue derived from a feed address) is desaturated to
the board's chroma ceiling and moved into its lightness band, keeping the hue
and dropping the shout. The bounds are measured from the board's own accents,
not invented.

**`AsyncValue.when`'s `error` branch does not run.** In this Riverpod
version a `FutureProvider` whose future rejects does not leave the loading
state: it stays `isLoading: true` and merely *carries* the error, so `when`
picks `loading` for ever — `skipError: true` does not change it either, and
both were checked against the package. A screen that maps `error` to its own
view through `when` therefore shows its skeleton until the reader gives up.
Ask `hasError` directly instead (`_resultsFor` in `search_screen.dart`).
Today is unaffected only because it maps `loading` and `error` to the same
skeleton; anywhere the two differ, do not use `when`.

**A failed provider is retried on a backoff timer**, which is Riverpod's
default and wanted here — a search that failed on a flaky connection tries
again on its own. In a widget test it is a pending timer the binding objects
to, so those containers pass `retry: (_, _) => null`.

**Every wait shows a skeleton**, and every skeleton is a flat fill: Today's
first load and category swipe, Linger's queue build, the Reader's body, the
Sources list while the catalog asset is read, Search's results while a query
runs, and the Bookmarks list on the way in. A wait that draws nothing reads
as a freeze, which is what the first-run fetch used to be.

Performance is a set of habits rather than a pass: parse off the main isolate,
bound the fetch pool, `ListView.builder` for anything list-shaped (the Sources
screen flattens its headers and rows into one lazy list), `memCacheWidth` on
every `CachedNetworkImage` so a publisher's 2000px hero is not decoded behind
a 76dp thumbnail, a debounced search field, and `select` on any provider that
emits more often than the widget needs — `refreshProvider` fires once per
feed, and Today has no business rebuilding forty-five times for a word that
changes twice.

**Nothing is parsed in a `build`.** Measured at 8.9ms for one 26,000-character
article, which is half a frame budget every time the widget rebuilds — and
the Reader rebuilds several times a second while reading aloud, as the word
highlight advances. The Reader derives its standfirst, its lead-image check
and whether the body has any text at all from **one** parse held in
`_derive`, re-run only when the document or the extraction changes; the
Linger card memoises its extract on the article's id, because a drag rebuilds
it on every frame. The same rule is why the Reader watches
`settingsProvider.select((s) => s.textSize)` rather than the whole object: a
rebuild for an unrelated setting would have paid that cost too.

**Motion** fires only from a gesture or a tap. Nothing loops, nothing is
ambient. Skeletons are flat fills with no shimmer sweep. The single exception
is the pull-to-refresh ring, which traces with the finger.

`HsMotion` is Perch's M3 Expressive set and the only one: two curves —
`spring` (`easeOutBack`) for what the finger caused, `decelerate`
(`easeOutCubic`) for what the system did — and durations from 150 to 260ms.
Tab cross-fade, route push *and* pop, and the shell's ground colour all run on
`page`; the pill's hide on `navHide`; the active label on `navMorph`. Every
shared transition goes through `HsMotion.of`/`curveOf`, which collapse to a
90ms linear fade under the OS's reduced-motion setting.

**Loading is one primitive.** `SkeletonBar` (`core/widgets/caught_up.dart`)
is every placeholder in the app; Today, Linger, the Reader body and a source
row compose it and add nothing of their own.

**An icon-only control names itself on a long press.** Flutter's `Tooltip`,
dressed once in `tooltipTheme` so it is the same object everywhere, as the
overflow menu is. The list-size button on Headlines is the first of them.

**A one-of-N setting is `showOptionSheet`** — the shared sheet with the
option, what it means, and a tick on the one in effect. Open links, text size,
reading fairness and refresh cadence all go through it; nothing cycles a value
in place on tap.

**Top-bar actions are `HsIconButton`** — Perch's circular filled button on
the surface-variant tone, 40 visual inside a 48 target — for back, share,
overflow and "Aa" alike. **Overflow menus are `showHsMenu`**: the menu's dress
comes from `popupMenuTheme`, so it is the same object on every screen; pass
`above: true` for a control at the foot of the screen.

**No engagement mechanics, anywhere.** No like, save-count, reaction or
share-count. No badge on the nav, no red dot, no notification prompt. No
streak, goal, trophy or comparison in Stats. No ranking. No infinite scroll.
If a change would add a number a reader could fall behind on, it is wrong.

**Reader** is on-device extraction only (`html_readability`, a pure-Dart port
of Mozilla's Readability). No page is sent to a server. When extraction comes
back thin it keeps whatever the feed gave, says so plainly, and hands off to
the publisher in a Custom Tab — never a broken or empty page, never error
styling.

### The Reader pipeline

One path, whatever came in: **normalise → clean → allowlist → render.**

1. **Normalise.** A full-content feed body and on-device extraction both
   arrive as one HTML string. Extraction uses `html_readability`'s
   `htmlContent`, never `textContent` — plain text throws away every heading,
   list and link. A feed carrying Markdown is converted first
   (`normaliseToHtml`), so there is one pipeline rather than a second that
   drifts.

   **A declared body beats the heuristic.** `ExtractionService.extractPage`
   tries `[itemprop="articleBody"]` first and keeps it if it assesses as a
   whole article — at a 40-word floor rather than the heuristic's 120,
   because a declared body that is a 70-word brief is complete, and the thin
   card would send the reader to the page for a "rest" that does not exist;
   only then does readability run. Readability is fooled by
   NDTV: its story wrapper is classed `js-ad-section`, Mozilla's
   unlikely-candidate rule matches `-ad-` and strips the whole story before
   scoring, and the page footer wins. The publisher's own schema.org mark is
   the more reliable signal when it exists. Neither parse runs on the UI
   isolate — an 850KB page costs hundreds of milliseconds twice over — the
   whole step goes through `compute`.

   **Collapsed is not hidden.** NDTV folds the story behind a "Show full
   article" toggle by CSS class alone; every paragraph is in the initial
   HTML and reaches the Reader. Readability's dropping of `display:none`
   nodes is left as it is — that is what removes the hidden AI-summary box —
   so a body that is genuinely injected by JavaScript is still out of reach.
   A page like that falls through to the thin card and "Open in web"; a
   WebView render is the only way further and is deliberately not built.

2. **Clean** (`ArticleCleaner.clean`), in this order, because each step
   depends on what the last one left:
   - *Comments* — removed first. Serialising writes a comment's text out as
     text and unwrapping reparents it, so `<!--MIDTABOOLA-->` was landing in
     the article as the word "MIDTABOOLA".
   - *Images* — absolutise and de-lazy against the article URL. Author
     avatars and Indian Express's `default-ie.jpg` theme placeholder count
     as spacers.
   - *Captions* — an element whose class names a caption (`img_cptn`,
     `wp-caption-text`, `custom-caption`, …) becomes a `<figcaption>`, so
     the Reader can set it small and muted instead of unwrapping it into
     prose. When that element is the wrapper *holding* the picture — Indian
     Express puts image and text in one `span.custom-caption` — the picture
     is kept in a `<figure>` beside its caption; replacing the wrapper with
     its text alone lost every photograph on the site.
   - *Boilerplate containers* — matched on `class`, `id` and `data-*` against
     the rules registry, then the always-dropped tags (`aside`, `iframe`,
     `script`, `style`, `noscript`, `form`, `button`, `nav`, `video`, …).
     A matching container with several real paragraphs is kept whatever its
     class says: NDTV's story sits in `js-ad-section`, and Indian Express
     gates the second half of a story, figures included, in
     `paywall container-wall-exclusive`.
   - *Skip links, aria junk and labels* — `a[href^="#"]` whose text starts
     with "skip", `[aria-hidden="true"]`, and elements whose **entire** text
     is a known label: `exactText` for fixed strings, `textPatterns` for the
     ones that carry a number or a variable tail ("3 min read", "Story
     continues below this ad", "Catch the latest World News…", "Tags:"),
     both guarded by a label length so a paragraph never matches. The
     **container** goes, not just the text: removing only the text is what
     leaves an "after newsletter promotion" caption stranded in the middle
     of an article.
   - *Links* — absolutised, tracking parameters stripped, `javascript:` and
     bare fragments dropped.
   - *Allowlist* — this is what kills junk nobody has seen yet. Only the tags
     in `allowedTags` survive; anything else is **unwrapped** (its prose is
     usually wanted) and `class`, `style`, `id`, `data-*` and every `on*`
     handler are stripped. `href` on `a` and `src`/`alt` on `img` are kept.
   - *Stitch* — `html_readability` wraps each bare text node in a `<p>` but
     leaves the inline elements beside it as siblings, so `Prefix <a>link</a>
     suffix` inside a div with blocks arrives as
     `<p>Prefix </p><a>link</a><p> suffix</p>` and the link rendered on a
     line of its own. `_stitchInlineNodes` puts that run back into one
     paragraph, joining neighbours only when the punctuation and case say
     the sentence continues.
   - *Prune* — empty elements, `<br>` runs, leading and trailing blanks, and
     a `<figcaption>` with no picture beside it (TOI's lead video leaves one
     at the top of every story once the embed is dropped).

   Boilerplate removal must run **before** sanitising: the rules read the very
   attributes the allowlist throws away.

3. **Render** (`features/reader/article_body.dart`) — every surviving tag is
   mapped to a design token: the heading scale is derived from the body size,
   so the "Aa" control scales headings, quotes and code along with the prose;
   `blockquote` takes an accent rule; `pre`/`code` sit on a surface tint;
   links are accent-toned and open in a Custom Tab, absolutising a relative
   href at tap time as a safety net.

**The cleaning registry is data** (`cleaning_rules.dart`): global rules plus
`perDomainCleaningRules`, keyed on the article's host. A new publisher quirk is
one entry — the pipeline never changes. Same extension shape as
`SourceAdapter`. `ndtv.com` is the largest entry: the "Ask NDTV" and AI
"Quick Read" widgets, the expand toggle, share bars and the SEO footer.
`indianexpress.com` names the byline strip, ad-slot labels and author box;
`timesofindia.indiatimes.com` the lead video embed.

**On pulling a body a publisher gates behind ads.** The Reader shows what the
publisher's own page already sent — nothing is fetched that a browser would
not, and nothing is rendered that reader view in that browser would not. That
is the same line as everywhere else in the app (§10: reader-view parity, no
republishing). If Play review pushes on it, the lever is `perDomainCleaningRules`
and the declared-body step, not a new setting.

Two traps that cost real time, both now covered by tests:

- **A fragment's own top-level children report a null parent** in
  `package:html`. Using `parent == null` as an "already removed" guard
  silently skips every root element — which is most of an extracted article,
  so the cleaner appears to do nothing. Use `ArticleCleaner._attached`.
- `querySelector('img')` searches descendants only, so an `<img>` must also be
  checked for by name, or an article that opens or closes with a photograph
  loses it.

**Every picture in the Reader is one `ArticleImage`** — the lead above the
title and each figure in the body alike: full column width, its own shape,
but never taller than the column is wide (a portrait is cropped to a square
rather than taking the whole screen), so a run of pictures reads as one
column. The renderer's default `figure` margin is zeroed for the same reason.
`Accept` on image requests names webp and png but **not avif** — Flutter has
no AVIF decoder, and a CDN that is offered it sends it, which collapsed those
images to nothing.

**The lead is shown only when the body has no copy of it.** Publishers
repeat the feed's picture as the first figure, usually with a caption; the
figure keeps its caption and its place in the story, and a second copy at
the top would not. When the body has no copy but the *page* does — The
Hindu's top picture sits outside its declared `articleBody` — `extractPage`
finds the page's copy by identity (`src`, lazy attributes, `srcset`, a
`<picture>`'s `<source>`), takes the caption beside it (a `figcaption` or
caption-classed element within four ancestors, else the `alt`), and puts a
`<figure>` with the feed's picture and that caption at the head of the body.
The caption then rides the normal figure path and survives the cache with
the rest of the body; no column, no second field.

**The standfirst is the feed's summary.** Publishers' deks — The Hindu's
`sub-title`, NDTV's `sp-descp` — are what they put in the feed's
`description`, so the Reader sets `article.summary` under the headline in
`HsType.readerStandfirst` (serif, a step under the body, `textSecondary`)
rather than parsing the page for it. It is skipped when the body opens with
the same words (feeds whose description is the first paragraph), and the
thin card no longer repeats it. `ArticleBody.isSameImage` sees through the size a
publisher writes into the address (`_625x300`, `/400x225/`, `?width=445`),
Hindustan Times's watermarked `/logo/` variant, and TOI's `msid`; it
compares file names when the name is more than a number, and the whole path
when it is not (the Guardian names every file by its width).

*Images* still need all three of:

1. The de-lazying above: promote `data-src`/`data-original`/`srcset` into
   `src`, unwrap `<picture>` to its decodable `<img>` fallback, upgrade `http`
   to `https` (Android blocks cleartext), and **remove spacer images** — a 1×1
   GIF stretched to full column width leaves a screen-high hole.
2. A `Referer` from the article and a desktop `User-Agent`
   (`ExtractionService.imageHeaders`) on every image request.
3. `html_readability` does **not** reliably carry a publisher's `<figure>`
   images into the extracted body — BBC and the Guardian lose all of them, The
   Hindu keeps them. So the Reader shows the feed's own `imageUrl` as a lead
   image whenever the body has no picture of its own. That is the dependable
   path; the first two are for publishers whose figures survive.

Any image that will not load collapses to nothing. A blank rectangle where a
photograph should be is worse than no photograph.

**The shell owns the ground.** `AppShell` paints the page colour under every
branch and animates it on `page`; Linger paints nothing of its own, so its
pure black / pure white ground (`HsPalette.lingerBackground`) fades in with
the tab rather than snapping. A branch that paints an opaque ground of its
own would cover that fade.

**`NavPillSurface` is the pill's dress** — nav tone, hairline, the one soft
shadow, optional blur — on its own so the Reader's three floating actions
(Open in web · Share · More) are separate objects wearing exactly it, with air
between them, rather than a second style of floating control.

**The nav pill** is a floating, detached, content-hugging object: five tabs —
Headlines · Linger · Sources · Search · More — no FAB, opaque by default
(blur is an off-by-default setting), only the selected destination carries
text, and inactive labels are not in the tree.

**Only the selected item takes free space** — `Flexible(flex: 1)` for it,
`flex: 0` for the other four, which are 44 square and must stay that way.
Making all five flexible splits the free space five ways and clips the one
label to a third of itself ("Hea"), which is what shipped until the emulator
showed it. The wrapper is always present, never swapped in and out: a child
that changes shape between builds loses its element and the label's morph
snaps instead of animating.

It rests `HsSize.navPillInset` (8) above the bottom **safe area**, not the 22
the board draws. The mock's inset is measured from the frame's edge; on a real
phone that lands on top of the system's own gesture inset and the pill floats
in the middle of the bottom margin — most visibly in Linger, where the card
has to clear it. The SafeArea already provides the distance the mock drew.

It **auto-hides on Today only**, driven by `navVisibilityProvider`: scrolling
down slides it past the bottom inset, scrolling up brings it back. Because it
is detached, that is a translation and nothing reflows. It always returns at
the top of a list, when a list does not scroll at all, and on a tab change,
and a 24px threshold stops a resting thumb making it flicker. Linger keeps its
chrome, per the design board.

**Back from any tab but Headlines goes to Headlines**, as in Perch.
`AppShell` wraps the shell in a `PopScope` with `canPop: index ==
AppShell.homeIndex`; go_router asks the root navigator first, and a pushed
screen or a sheet is above the shell there, so those pop before the tab does.
On Headlines the disposition is the platform's and the app exits.
`back_button_test` pins all the cases. Neither app enables predictive back in
the manifest, so this is the whole story.

**The Reader's text-size popover** is a card over the prose beneath the bar,
sliding down from under it on `tabSlide` and back up on the way out, with an
opaque barrier under it: a tap, or the start of a drag, anywhere
outside closes it, and so does any scroll notification. It is mounted only
while open. The slider is discrete — five ticks, the knob only ever on one,
a drag snapping to the nearest — and carries slider semantics.

**Onboarding steps arrive like pushed pages.** Welcome, the picker and the
first fetch are one screen switching its body; an `AnimatedSwitcher` keyed
on the step plays the router's slide-and-fade on `page`, so the walkthrough
runs on the same clock as everything after it.

**Bottom sheets are presented on the root navigator** (`showHsSheet` sets
`useRootNavigator`). Presented on a branch navigator they render *beneath* the
shell's floating pill, which then covers the sheet's own actions.

**`HsSheet`'s content scrolls, and only when it has to.** The view sizes
itself to its content, so a three-row option sheet still hugs the bottom of
the screen — but a sheet taller than the screen used to overflow its column
and clip the actions at the foot, which are the part that must always be
reachable. Any long explainer hit it, and so would every sheet in the app at
a large system font size.

**Tab switches slide directionally in `AppShell`, ported from Perch.**
`StatefulShellRoute.indexedStack` hosts the branches while `AppShell` animates
the incoming tab using `FractionalTranslation` on `HsMotion.page` (240ms,
`Curves.easeOutCubic`). The translation stays in the tree at rest (offset
zero) rather than being wrapped on for the animation: swapping the wrapper
re-parents every branch's subtree at the start and end of each switch, which
is what made the slide to Sources stutter. The `RepaintBoundary` sits
*inside* the translation, so the page is rasterised once and only moved from
frame to frame.

**Bottom-nav tabs support horizontal swipe gestures.** Decisive horizontal flings
(`velocity.abs() >= 240` via `GestureDetector(behavior: HitTestBehavior.translucent, onHorizontalDragEnd: ...)`)
move across destinations (Headlines ↔ Linger ↔ Sources ↔ Search ↔ More) without interfering
with vertical drags (Linger's vertical card swipe, pull-to-refresh, list scrolls). The count
comes from the shell's own branches, not a constant. Category switching is
handled via the Filter sheet rather than tab gestures.

**Filter sheets close on success.** Behind a scrim, an action that leaves the
sheet open looks like it did nothing — which is exactly how "Show all" read
before it popped.

**`InfoSheet` is the one explainer surface.** Title, paragraphs, an optional
numbered step list, an optional muted note, and up to two actions — all from
the token layer, so it needs no new design. The OPML explainer
(`features/sources/opml_explainer.dart`) is one call with different text;
AMOLED and AI summaries should be the same. A low-emphasis `InfoButton` sits
beside every "Import OPML" affordance, labelled "About OPML" for TalkBack, at
a full 44dp target. Its primary action opens the file picker directly rather
than sending the reader back to hunt for the button they were standing next
to. `showNotice` states the outcome afterwards and leaves — no badge, no
celebration.

---

## 7. Dev commands

A note on test data: the de-duplicator collapses near-identical headlines, so
fixture articles need genuinely distinct titles. Several tests "failed" during
development purely because their sample headlines all fingerprinted alike —
which was the fingerprint working, not a bug.

```bash
flutter pub get
dart run build_runner build          # drift + freezed codegen
dart run build_runner watch          # while editing tables or models
flutter analyze                      # must be clean
dart format lib test
flutter test
flutter run -d <device>
flutter build apk --profile --target-platform android-arm64   # small enough to install on a full emulator
dart run flutter_launcher_icons      # after changing assets/icon/
dart run flutter_native_splash:create
```

The launcher icon is generated from the design board's mark by
`tool/make_icon.py` (pure stdlib, no image library) into `assets/icon/`: a
paper ground carrying a slate-teal headline card with two ghost cards behind
it, every shape a rotated rounded box under a signed-distance function. The
adaptive background is the paper (`#F4F1EA`), the foreground the whole stack
inside the safe zone, the monochrome layer the front card's silhouette with
its lines knocked out. The splash is `splash.png` on both Android
generations: a paper disc carrying the stack on the AMOLED ground. Android
12 shows only the inner two thirds of the drawable through its circular
mask, over `icon_background_color` in the same paper, so the seam is
invisible; the stack is drawn small enough (0.36 of the disc) to clear that
crop. The foreground alone over a black disc, which is what it was, showed
only the card.

---

## 8. Packages

| Concern | Package |
|---|---|
| State | `flutter_riverpod` (Riverpod 3) |
| Routing | `go_router` (`StatefulShellRoute` for the four tabs) |
| Database | `drift` + `drift_flutter` |
| HTTP | `dio` + `dio_http2_adapter` (h2 where offered; see §5) + `brotli` (pure-Dart decoder for what h2 returns) |
| Feed parsing | `dart_rss` |
| Extraction | `html_readability` |
| Article rendering | `flutter_widget_from_html_core` |
| Custom Tabs | `url_launcher` (`LaunchMode.inAppBrowserView`) |
| Read aloud | `flutter_tts` — the phone's own engine; nothing leaves the device. **Vendored and patched**, see below |
| Full-text search | SQLite FTS5 through `drift` — no package; see §Search |
| Web search | Google News' public RSS endpoint, read with `xml` — no package, no key |
| Images | `cached_network_image` |
| OPML / XML | `xml` |
| Models | `freezed` |
| Files | `file_selector` (import only — export goes through `share_plus`) |
| Version | `package_info_plus` — the About row and the foot of More read the installed version, never a string |
| Colour | `Oklab` — ours; no package matches CSS `color-mix(in oklab, …)` |
| Markdown | `markdown`, for the rare feed that carries it |
| Lints | `very_good_analysis` |
| Tests | `flutter_test`, `mocktail` |

**Swaps and omissions, with reasons:**

- `flutter_widget_from_html` → **`flutter_widget_from_html_core`**. The full
  package pulls in `webview_flutter`, `video_player` and `wakelock_plus`. None
  of them are wanted in a reader that must stay light.
- **`reader_mode` fallback: not added.** `html_readability` is already a
  faithful port of the same Mozilla heuristics a browser reader view uses; a
  second implementation of the same algorithm is not a fallback. The real
  fallback is the graceful degrade path — keep the feed's summary, say the
  extraction fell short, offer the publisher.
- **`json_serializable`: unused.** Nothing in the app speaks JSON — feeds and
  OPML are XML. It stays in `dev_dependencies` only because `freezed` lists it.
- **`riverpod_lint` / `custom_lint`: not added.** They cannot resolve against
  Riverpod 3 + Freezed 3 in this version set.
- **`opml` package: not used.** OPML is XML plus one convention; a ~120-line
  reader/writer over `xml` beats a dependency.
- **Fonts are bundled**, not fetched at runtime — Source Serif 4 and Archivo
  as variable TTFs, with `wght` set through `fontVariations` in `HsType`,
  plus Noto Serif and Noto Sans Devanagari as the Indic fallback. The other
  Indic scripts are named in `fontFamilyFallback` and resolved from Android's
  own Noto families; see §2's type note.
- **A search package: not added.** SQLite already has FTS5, and
  `drift_flutter` already ships a build with it enabled. An in-memory index
  would be a second copy of every article that the prune could not reach.
- **`flutter_tts` is vendored under `third_party/`**, with exactly one change:
  its Android build no longer applies the Kotlin Gradle Plugin. Upstream 4.2.5
  — the latest release — still does, which Flutter warns about on every build
  and will refuse outright in a future version. The patch follows Flutter's
  own migration guide for plugin authors, and the app's
  `android/gradle.properties` turns **on** `android.builtInKotlin` so AGP 9
  compiles the plugin's Kotlin instead. Measured: no APK size cost (50.44MB
  profile either way). The plugin's 815-line `FlutterTtsPlugin.kt` and all of
  its Dart are untouched; `third_party/flutter_tts/README.md` says what to
  delete when upstream ships a migrated release. `third_party/**` is excluded
  from `analyze`: it is not our code to lint.
- **`android_intent_plus`: not added.** The only thing wanting it is a jump to
  Android's text-to-speech settings from the Listen card, which the copy can
  name instead. One dependency for one button is not a trade worth making.

---

## 9. Quality bar

- `flutter analyze` clean under `very_good_analysis`. No warnings.
- Tests cover full-text search (query, prefix, every-term-narrows, FTS syntax
  that must not throw, a Devanagari query, scope including a paused source,
  an empty scope, the date range at both ends, and the index keeping up with
  an insert, a correction and a prune), a bookmark surviving a prune, the
  90-day window, a cache clear and its source being unsubscribed, language as
  a label (the tag, script detection, the Indic type metrics, the catalog's
  own tags, OPML round-tripping and the filter losing an option with its last
  source), the fetch/parse/dedup pipeline, the fetch pool's concurrency
  ceiling and per-feed timeout, a feed that throws not taking the run with it,
  onboarding-and-refresh parity, entity decoding (including double-encoded
  fields), reactive category derivation and the fallback when a tab vanishes,
  the Linger filter query, the `SourceAdapter` registry,
  OPML round-tripping, the Reader cleaning pipeline (including an NDTV page
  with its collapsed body and ad slots, through both the cleaner and the
  service's declared-body path), Android back from every tab and over a
  pushed screen and a sheet, the Reader's text-size popover dismissing and
  snapping, canonical-URL and headline de-duplication, the fairness cap, category derivation and renaming,
  the seen/read model, the scroll-direction nav controller, the oklab colour
  maths against the design board's stated values, and the three widgets the
  design is most specific about: the nav pill (now five destinations), the
  Today card, the Linger card.
- `test/fixtures/` holds **real saved article HTML**, not hand-written
  samples: a Guardian article with the newsletter block, one with headings and
  lists, one with inline links, and a whole NDTV page as a browser receives
  it (script, style and SVG bodies trimmed; structure intact — the CDN
  refuses anything that is not a browser, so it was saved through one). Hand-written HTML is too tidy to catch what
  publishers actually ship. `article_cleaner_test.dart` asserts the fixture
  still contains the boilerplate before asserting it is gone, so the test
  cannot quietly stop testing anything. The caption, label, prose-guard and
  inline-stitch cases in it are each a real publisher's markup, reduced.
- Two of those are guard rails rather than coverage: `accent_test.dart`
  asserts the board's nine accents survive `accentFor` byte-for-byte, and
  pins `Oklab.mix` to the board's own `color-mix` results. Breaking either is
  a design regression, not a failing unit.
- Every failure state has a designed screen: offline (serve cache), broken
  feed, thin extraction, empty sources, and "You're caught up".
- No secrets in the repo. No analytics, no trackers, no server.

## 10. Out of scope (do not build)

- The **AI summariser** itself. There is no row, screen or key for it until
  it exists.
- A **WebView render** for pages that inject their body with JavaScript. The
  thin card and "Open in web" are the fallback.
- Any **server-side** component.
- Republishing publisher body text beyond on-device reader-view parity.
- **A server-side search index.** Search reads the cache on the device; a
  source with nothing cached is fetched once, for that search, and stored
  nowhere. Google News is asked directly from the device, with the reader's
  search term and nothing else.
- **Storing anything Google News returns.** Its results are shown and
  forgotten. They are not the reader's sources, they never enter the
  briefing, and they open in the browser rather than the Reader.
- **A cloud voice for Listen.** The phone's engine or nothing, said plainly.
- iOS release targeting.
