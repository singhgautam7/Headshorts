# Headshorts — app icon

**Final variant:** B (`variants/headshorts_b.svg`)

## Construction
- Grid: 108 × 108 dp adaptive canvas, 72 dp visible viewport, 66 dp safe zone.
- Stroke: **9 dp on 108 dp = 0.0833 of the canvas** (42.7 px on the 512 px Play icon). Round caps, round joins. Same for every icon in the family.
- Glyph: H plus a full RSS mark. The right stem's top cap is the feed dot; two feed arcs (radius 13.5 and 27 dp) radiate from it, up and to the right. Dark: left stem and both arcs. Mid: crossbar (starting on top of the left stem, the fold) and right stem.
- Accent: Two RSS arcs, dark tone, same 9 dp stroke.
- Glyph box: 54.0 × 56.0 dp. Furthest ink from centre: 31.8 dp (safe-zone limit 33 dp). Ink coverage: 10.8% of the canvas.
- Draw order: dark stroke(s) first, mid stroke(s) on top. No gradients, shadows or outlines.

## Colours
| Role | Value |
|---|---|
| Dark (base stroke) | #791A18 |
| Mid (overlapping stroke) | #D3453D |
| Background (pale tint) | #FFDDD9 |
| Splash background, light | #FFDDD9 |
| Splash background, dark | #291412 |
| Splash glyph, dark mode (base / top) | #E15249 / #FBB7AF |

OKLCH hue: 27.

## Files
- `ic_launcher_foreground.svg` — glyph, 108 dp, transparent
- `ic_launcher_background.svg` — solid pale tint, 108 dp
- `ic_launcher_monochrome.svg` — single-colour glyph for Android 13+ themed icons (system tints it)
- `ic_launcher_preview.svg` — composited 72 dp viewport, for previews only
- `splash_icon.svg` / `splash_icon_night.svg` — 288 dp canvas; glyph sits inside the 192 dp circle (max radius 84.8 dp of 96)
- `play_store_512.png` (+ `play_store_source.svg`) — full 108 dp canvas at 512 px, same framing as the existing Kuber / PostPurush / Unfurl Play icons
- `ic_stat_notification.svg` / `ic_stat_notification_96.png` — white silhouette, 24 dp, glyph scaled to 0.4 (stroke 3.6 dp)
- `variants/` — variant sources

To import: Android Studio → New → Vector Asset for each SVG, then reference them from `mipmap-anydpi-v26/ic_launcher.xml` (`<foreground>`, `<background>`, `<monochrome>`).

## Variants
- **B** — H + RSS mark. Final. The composition is centred on the feed dot, so in a circle mask everything is an even distance from the edge (furthest ink 31.8 dp of 33). (54.0×56.0 dp, ink 10.8%)
