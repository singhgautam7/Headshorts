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

---

## 2. Project facts

- **Application ID / namespace:** `com.grs.news` (Dart package: `headshorts`).
- **Flutter:** latest stable (3.47.x). Track it; do not pin backwards.
- **minSdk 24**, **compileSdk 37** (the adaptive monochrome icon needs 24;
  `flutter_secure_storage` needs to compile against 37).
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

## 4. Data model

- **sources** — id, title, siteUrl, feedUrl (unique), category, `accentDark` /
  `accentLight` (the accent's two tones), type, enabled, sortOrder, etag,
  lastModified, lastFetchedAt, addedAt, `failingSince`, `lastError`.
- **articles** — id, sourceId (FK, cascade), guid, title, summary,
  contentSnippet, `fullContentHtml` (nullable — only when a full-content feed
  or extraction supplied it), link, author, publishedAt, imageUrl, fetchedAt,
  `readInReel`, `readInFull`. Unique on `(sourceId, guid)`.
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

---

## 5. Fetch pipeline

`RefreshService.refreshAll()` fetches every enabled, non-abandoned source
concurrently and emits progress **in completion order** (`Stream.fromFutures`),
so one slow feed does not hold up the rest. Per source: conditional GET with
the stored ETag/Last-Modified → parse → upsert → record success or failure.

- A 304 costs a header exchange and nothing else.
- **Nothing here throws.** A dead feed is state recorded against the source
  (`failingSince`, `lastError`), stated in words on that source's own screen.
  It never becomes an error dialog or a red dot. Retries stop after 14 days.
- Launch behaviour: open to cache, refresh behind the content, show a quiet
  "updating…" and offer pull-to-refresh. **The only blocking loader in the app
  is the first-run fetch in onboarding.**

---

## 6. Design & behaviour guardrails

**Token-only styling.** No hardcoded colour, size, radius, duration or curve
outside `lib/core/tokens/`. Widgets read colour roles through `context.hs`
and per-source accent through `AccentScope.of(context)`.

**Two themes:** AMOLED black (default) and warm-paper White, plus System.
The accent rule: a source accent is a **label, a hairline bar, and — in Linger
only — a wash panel**. Never a saturated card fill. 15% over black, 7% over
paper.

**Motion** fires only from a gesture or a tap. Nothing loops, nothing is
ambient. Skeletons are flat fills with no shimmer sweep. The single exception
is the pull-to-refresh ring, which traces with the finger.

**No engagement mechanics, anywhere.** No like, save-count, reaction or
share-count. No badge on the nav, no red dot, no notification prompt. No
streak, goal, trophy or comparison in Stats. No ranking. No infinite scroll.
If a change would add a number a reader could fall behind on, it is wrong.

**Reader** is on-device extraction only (`html_readability`, a pure-Dart port
of Mozilla's Readability). No page is sent to a server. When extraction comes
back thin it keeps whatever the feed gave, says so plainly, and hands off to
the publisher in a Custom Tab — never a broken or empty page, never error
styling.

**The nav pill** is a floating, detached, content-hugging object: four tabs,
no FAB, opaque by default (blur is an off-by-default setting), only the
selected destination carries text, and inactive labels are not in the tree.

---

## 7. Dev commands

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
| HTTP | `dio` |
| Feed parsing | `dart_rss` |
| Extraction | `html_readability` |
| Article rendering | `flutter_widget_from_html_core` |
| Custom Tabs | `url_launcher` (`LaunchMode.inAppBrowserView`) |
| Images | `cached_network_image` |
| OPML / XML | `xml` |
| Models | `freezed` |
| Secure storage | `flutter_secure_storage` |
| Files | `file_selector` |
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
- Tests cover the fetch/parse/dedup pipeline, the `SourceAdapter` registry,
  OPML round-tripping, article-HTML normalisation, and the three widgets the
  design is most specific about: the nav pill, the Today card, the Linger card.
- Every failure state has a designed screen: offline (serve cache), broken
  feed, thin extraction, empty sources, and "You're caught up".
- No secrets in the repo. No analytics, no trackers, no server.

## 10. Out of scope (do not build)

- The **AI summariser** itself. The entry point and the secure key screen
  exist and store a key in the Android keystore; nothing summarises anything.
- Any **server-side** component.
- Republishing publisher body text beyond on-device reader-view parity.
- iOS release targeting.
