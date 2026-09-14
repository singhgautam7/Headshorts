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
document is `specs/design/waiting-on-deliverable-details/project/HeadShorts
Design Board.dc.html` — a Claude Design handoff, HTML/CSS prototypes rather
than production code. Recreate the *visual output*, not the DOM structure.

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
| An AI summaries key screen | A "Coming soon" screen | A key field and toggles that did nothing looked half-enabled. Nothing is stored until something can use it. |

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
    db/         drift database, tables, repositories (source / article / stats)
    sources/    SourceAdapter + RssSourceAdapter + registry, OPML, starter set
    feed/       http client, feed parser, discovery, refresh pipeline
    readability/on-device article extraction
    prefs/      settings store (shared_preferences)
  features/     today · linger · reader · sources · more · stats · onboarding
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

`assets/feeds/starter_feeds.opml` ships ~45 verified feeds across eight
categories, parsed once per launch into `SourceCatalog`
(`sourceCatalogProvider`). It is a **directory to search, not a starting
state** — nothing in it is subscribed until the reader says so.

- **An OPML asset rather than a Dart list**, because that is the format the app
  already imports and exports: a curated set is edited the same way a reader's
  own subscriptions are, and the parser is exercised by the app's own data on
  every launch.
- Accents travel in `hsAccentDark` / `hsAccentLight`, our own OPML extension,
  so the design board's eight survive the round trip byte-for-byte (asserted by
  test). Anyone else's OPML omits them and the app derives a tone instead.
- **Every URL in the file was fetched and checked before shipping.** Eight
  candidates were dropped for 403/404/empty responses. Re-verify before adding
  more — a dead feed in the catalog is worse than a short catalog.
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

### Where subscription lives

Everything that changes *what the app fetches* is in Sources or Settings, and
every one of those changes flows through the reactive store, so Today and
Linger reflect it without anything being told to reload:

| Screen | Does |
|---|---|
| **More** | Grouped rows in Perch's settings dress — General (Appearance, Open links, Text size, Reading fairness, Check for new) · Your data (Stats, Data, Permissions) · About HeadShorts (Privacy, AI summaries, About) — the real version line and "Made with ❤️ in India" at the foot. Every one-of-N row opens `showOptionSheet`; nothing cycles in place |
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

- **sources** — id, title, siteUrl, feedUrl (unique), category, `accentDark` /
  `accentLight` (the accent's two tones), type, enabled, `mutedInLatest`,
  sortOrder, etag, lastModified, lastFetchedAt, addedAt, `failingSince`,
  `lastError`.
- **articles** — id, sourceId (FK, cascade), guid, title, summary,
  contentSnippet, `fullContentHtml` (nullable — only when a full-content feed
  or extraction supplied it), link, `canonicalUrl`, `titleKey`, author,
  publishedAt, imageUrl, fetchedAt, `seenInLinger`, `readFull`. Unique on
  `(sourceId, guid)`.
- **read_events** — articleId, mode, at, dwellMs. Reading time comes from here,
  not from a column on `articles`.
- **caught_up_days** — one row per day the reader reached the end of Today.

Rules:

- **Dedup on `(sourceId, guid)`**, falling back to the link when a feed omits
  the guid.
- **Cache-first.** The database is the source of truth the UI watches; the
  network only refreshes it. Every screen opens instantly from cache.
- **Finite.** Every query is bounded. There is no cursor and no "load more".
  Lists end in "You're caught up"; swiping past it settles back.
- **Retention.** `pruneToRetention()` keeps the newest 200 items per source
  after each refresh.
- Updating an article never erases a `fullContentHtml` the feed has stopped
  sending.
- **Schema version 3.** Adding or renaming a column means bumping
  `schemaVersion` and adding a step to `MigrationStrategy.onUpgrade` in
  `database.dart`. v2 added the de-duplication keys and `mutedInLatest`; v3
  renamed `read_in_reel`/`read_in_full` to `seenInLinger`/`readFull`, which
  carry over as-is because the old flags meant exactly those two things.

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

**Every wait shows a skeleton**, and every skeleton is a flat fill: Today's
first load and category swipe, Linger's queue build, the Reader's body, the
Sources list while the catalog asset is read. A wait that draws nothing reads
as a freeze, which is what the first-run fetch used to be.

Performance is a set of habits rather than a pass: parse off the main isolate,
bound the fetch pool, `ListView.builder` for anything list-shaped (the Sources
screen flattens its headers and rows into one lazy list), `memCacheWidth` on
every `CachedNetworkImage` so a publisher's 2000px hero is not decoded behind
a 76dp thumbnail, a debounced search field, and `select` on any provider that
emits more often than the widget needs — `refreshProvider` fires once per
feed, and Today has no business rebuilding forty-five times for a word that
changes twice.

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
   - *Images* — absolutise and de-lazy against the article URL.
   - *Boilerplate containers* — matched on `class`, `id` and `data-*` against
     the rules registry, then the always-dropped tags (`aside`, `iframe`,
     `script`, `style`, `noscript`, `form`, `button`, `nav`, `video`, …).
     A matching container that holds most of the document's text is kept:
     it is the article wearing an ad-ish class, not an ad.
   - *Skip links, aria junk and orphan captions* — `a[href^="#"]` whose text
     starts with "skip", `[aria-hidden="true"]`, and elements whose **entire**
     text is a known label. The **container** goes, not just the text:
     removing only the text is what leaves an "after newsletter promotion"
     caption stranded in the middle of an article.
   - *Links* — absolutised, tracking parameters stripped, `javascript:` and
     bare fragments dropped.
   - *Allowlist* — this is what kills junk nobody has seen yet. Only the tags
     in `allowedTags` survive; anything else is **unwrapped** (its prose is
     usually wanted) and `class`, `style`, `id`, `data-*` and every `on*`
     handler are stripped. `href` on `a` and `src`/`alt` on `img` are kept.
   - *Prune* — empty elements, `<br>` runs, leading and trailing blanks.

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

**The nav pill** is a floating, detached, content-hugging object: four tabs,
no FAB, opaque by default (blur is an off-by-default setting), only the
selected destination carries text, and inactive labels are not in the tree.

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

**Back from any tab but Today goes to Today**, as in Perch. `AppShell` wraps
the shell in a `PopScope` with `canPop: index == 0`; go_router asks the root
navigator first, and a pushed screen or a sheet is above the shell there, so
those pop before the tab does. On Today the disposition is the platform's and
the app exits. `back_button_test` pins all four cases. Neither app enables
predictive back in the manifest, so this is the whole story.

**The Reader's text-size popover** is a card over the prose beneath the bar,
sliding down from under it on `tabSlide` and back up on the way out, with an
opaque barrier under it: a tap, or the start of a drag, anywhere
outside closes it, and so does any scroll notification. It is mounted only
while open. The slider is discrete — five ticks, the knob only ever on one,
a drag snapping to the nearest — and carries slider semantics.

**Bottom sheets are presented on the root navigator** (`showHsSheet` sets
`useRootNavigator`). Presented on a branch navigator they render *beneath* the
shell's floating pill, which then covers the sheet's own actions.

**Tab switches slide directionally in `AppShell`, ported from Perch.**
`StatefulShellRoute.indexedStack` hosts the branches while `AppShell` animates
the incoming tab using `FractionalTranslation` with `RepaintBoundary` on `HsMotion.page`
(240ms, `Curves.easeOutCubic`). Switching branches (via tap or swipe) triggers a forward
or backward slide matching the navigation direction without layout cost or repaint jitter.

**Bottom-nav tabs support horizontal swipe gestures.** Decisive horizontal flings
(`velocity.abs() >= 240` via `GestureDetector(behavior: HitTestBehavior.translucent, onHorizontalDragEnd: ...)`)
move across destinations (Today ↔ Linger ↔ Sources ↔ More) without interfering with vertical
drags (Linger's vertical card swipe, pull-to-refresh, list scrolls). Category switching is
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
`tool/make_icon.py` (pure stdlib, no image library) into `assets/icon/`.

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
  as variable TTFs, with `wght` set through `fontVariations` in `HsType`.

---

## 9. Quality bar

- `flutter analyze` clean under `very_good_analysis`. No warnings.
- Tests cover the fetch/parse/dedup pipeline, the fetch pool's concurrency
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
  design is most specific about: the nav pill, the Today card, the Linger card.
- `test/fixtures/` holds **real saved article HTML**, not hand-written
  samples: a Guardian article with the newsletter block, one with headings and
  lists, one with inline links, and a whole NDTV page as a browser receives
  it (script, style and SVG bodies trimmed; structure intact — the CDN
  refuses anything that is not a browser, so it was saved through one). Hand-written HTML is too tidy to catch what
  publishers actually ship. `article_cleaner_test.dart` asserts the fixture
  still contains the boilerplate before asserting it is gone, so the test
  cannot quietly stop testing anything.
- Two of those are guard rails rather than coverage: `accent_test.dart`
  asserts the board's nine accents survive `accentFor` byte-for-byte, and
  pins `Oklab.mix` to the board's own `color-mix` results. Breaking either is
  a design regression, not a failing unit.
- Every failure state has a designed screen: offline (serve cache), broken
  feed, thin extraction, empty sources, and "You're caught up".
- No secrets in the repo. No analytics, no trackers, no server.

## 10. Out of scope (do not build)

- The **AI summariser** itself. The More row leads to a "Coming soon" screen
  and nothing else; no key is collected or stored until there is something to
  use it.
- A **WebView render** for pages that inject their body with JavaScript. The
  thin card and "Open in web" are the fallback.
- Any **server-side** component.
- Republishing publisher body text beyond on-device reader-view parity.
- iOS release targeting.
