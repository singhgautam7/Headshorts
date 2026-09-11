# HeadShorts

A finite briefing. It ends, and then you are done with it.

HeadShorts is a calm RSS reader for Android. It reads the feeds you choose, in
the order they were published — no algorithm, no counts, no infinite scroll.
When you reach the bottom, that is the news.

- **Today** — a chronological briefing, grouped into your own categories, that
  ends in "You're caught up".
- **Linger** — one item per screen, moved by a deliberate swipe. Nothing
  advances on its own, and there is a hard stop.
- **Reader** — the full article in the app, extracted on the device, always
  attributed and always one tap from the publisher.
- **Sources** — paste a site address and the feed is found for you. OPML in
  and out. No unread counts.
- **Stats** — a mirror, not a scoreboard. No streaks, no goals, no badges.

Local-first: no account, no server, no analytics. Your subscriptions and
reading live in a database on your phone and leave when you uninstall.

## Building

```bash
flutter pub get
dart run build_runner build
flutter run -d <device>
```

See [CLAUDE.md](CLAUDE.md) for the architecture, the data model and the rules
this app is built to.
