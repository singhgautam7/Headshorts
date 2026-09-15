"""Renders the HeadShorts app icon to PNG, straight from the design board.

One icon, no alternates: a paper ground carrying a deep slate-teal headline
card with two more waiting behind it. The top line is the source accent, the
two below are paper — the same relationship the cards have in Linger. Flat
fill, no gradient, no glyph, no letterform.

Pure stdlib: every shape is a rounded rectangle or a stadium, so a signed-
distance function in the card's own rotated frame gives clean antialiasing
without a raster library.
"""
import math
import struct
import sys
import zlib

# Everything below is read off the 168px tile in the design board and scaled.
TILE = 168.0
MARK_W, MARK_H = 91.0, 74.6
CARD_RADIUS = 11.8
CARD_PAD = 11.8
LINE_H = 7.7
LINE_GAP = 8.6
# (width fraction of the card's inner column, colour role, opacity)
LINES = [(0.54, 'accent', 1.0), (1.00, 'paper', 0.92), (0.78, 'paper', 0.78)]
# Ghost cards behind the front one: (dx, dy, rotation°, opacity). Their fill
# is the card ink at 28%, then the layer opacity on top of that.
GHOSTS = [(8.2, -6.8, 9.0, 0.45), (4.1, -3.2, 4.5, 0.75)]
GHOST_FILL_ALPHA = 0.28
FRONT_ROTATION = -4.5
SHADOW_DY, SHADOW_BLUR, SHADOW_ALPHA = 2.7, 8.2, 0.28

PAPER = (244, 241, 234)
CARD = (18, 48, 56)
ACCENT = (233, 177, 104)
BLACK = (0, 0, 0)


def rounded_box(px, py, cx, cy, hw, hh, radius, angle):
    """Signed distance to a rounded box rotated by `angle` about its centre."""
    a = math.radians(angle)
    dx, dy = px - cx, py - cy
    lx = dx * math.cos(a) + dy * math.sin(a)
    ly = -dx * math.sin(a) + dy * math.cos(a)
    qx = max(abs(lx) - (hw - radius), 0.0)
    qy = max(abs(ly) - (hh - radius), 0.0)
    return math.hypot(qx, qy) - radius


def coverage(d):
    return min(max(0.5 - d, 0.0), 1.0)


def shapes(size, mark_fraction):
    """Yields (kind, params) back to front for a canvas of `size` pixels."""
    s = size * mark_fraction / MARK_W
    w, h = MARK_W * s, MARK_H * s
    cx, cy = size / 2, size / 2
    for dx, dy, rot, opacity in GHOSTS:
        # CSS offsets the box before rotating it about its own centre.
        yield 'fill', (cx + dx * s, cy + dy * s, w / 2, h / 2, CARD_RADIUS * s,
                       rot, CARD, GHOST_FILL_ALPHA * opacity)
    yield 'shadow', (cx, cy + SHADOW_DY * s, w / 2, h / 2, CARD_RADIUS * s,
                     FRONT_ROTATION, BLACK, SHADOW_ALPHA, SHADOW_BLUR * s)
    yield 'fill', (cx, cy, w / 2, h / 2, CARD_RADIUS * s, FRONT_ROTATION,
                   CARD, 1.0)
    # The lines sit in the card's own frame: offsets are rotated with it.
    inner_w = (MARK_W - 2 * CARD_PAD) * s
    column_h = (len(LINES) * LINE_H + (len(LINES) - 1) * LINE_GAP) * s
    top = -column_h / 2
    a = math.radians(FRONT_ROTATION)
    for i, (fraction, role, opacity) in enumerate(LINES):
        lw, lh = inner_w * fraction, LINE_H * s
        # Line centre in the card frame, left-aligned inside the padding.
        ox = -inner_w / 2 + lw / 2
        oy = top + i * (LINE_H + LINE_GAP) * s + lh / 2
        lx = cx + ox * math.cos(a) - oy * math.sin(a)
        ly = cy + ox * math.sin(a) + oy * math.cos(a)
        colour = ACCENT if role == 'accent' else PAPER
        yield 'fill', (lx, ly, lw / 2, lh / 2, lh / 2, FRONT_ROTATION,
                       colour, opacity)


def render(size, background, mark_fraction, monochrome=False, disc=False):
    """Returns RGBA rows. A None background leaves the canvas transparent;
    `disc` paints it only inside the inscribed circle."""
    bg = (background + (255,)) if background else (0, 0, 0, 0)
    rows = [bytearray(bg * size) for _ in range(size)]
    if disc and background:
        c, r = size / 2, size / 2
        for py in range(size):
            row = rows[py]
            for px in range(size):
                a = coverage(math.hypot(px + 0.5 - c, py + 0.5 - c) - r)
                row[px * 4 + 3] = round(255 * a)

    for kind, params in shapes(size, mark_fraction):
        cx, cy, hw, hh, radius, angle, colour, alpha = params[:8]
        knockout = False
        if monochrome:
            # The themed-icon slot takes the card silhouette alone, in the
            # launcher's own ink: no ghosts, no shadow, the lines knocked out.
            if kind == 'shadow' or (colour == CARD and alpha < 1.0):
                continue
            knockout = colour != CARD
            colour, alpha = (255, 255, 255), 1.0
        blur = params[8] if kind == 'shadow' else 0.0
        reach = int(math.hypot(hw, hh) + blur + 2)
        for py in range(max(0, int(cy) - reach), min(size, int(cy) + reach + 1)):
            row = rows[py]
            for px in range(max(0, int(cx) - reach), min(size, int(cx) + reach + 1)):
                d = rounded_box(px + 0.5, py + 0.5, cx, cy, hw, hh, radius, angle)
                if blur:
                    a = alpha * min(max(0.5 - d / blur, 0.0), 1.0) ** 2
                else:
                    a = alpha * coverage(d)
                if a <= 0:
                    continue
                o = px * 4
                if knockout:
                    row[o + 3] = round(row[o + 3] * (1 - a))
                    continue
                for c in range(3):
                    row[o + c] = round(row[o + c] * (1 - a) + colour[c] * a)
                row[o + 3] = round(row[o + 3] + (255 - row[o + 3]) * a)
    return rows


def write_png(path, size, rows):
    raw = b''.join(b'\x00' + bytes(row) for row in rows)

    def chunk(tag, data):
        body = tag + data
        return (
            struct.pack('>I', len(data))
            + body
            + struct.pack('>I', zlib.crc32(body) & 0xFFFFFFFF)
        )

    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)))
        f.write(chunk(b'IDAT', zlib.compress(raw, 9)))
        f.write(chunk(b'IEND', b''))


if __name__ == '__main__':
    out = sys.argv[1].rstrip('/')
    size = 1024

    # Legacy / full-bleed icon: the paper tile at its preview proportion.
    write_png(f'{out}/icon.png', size, render(size, PAPER, MARK_W / TILE))

    # Adaptive foreground: a 108dp layer with the whole stack — ghost cards
    # included — inside the 66dp circular safe zone, so no corner is clipped
    # by a round, squircle or teardrop mask. The board draws it 72 wide.
    write_png(
        f'{out}/adaptive_foreground.png',
        size,
        render(size, None, 72.0 / 108.0),
    )

    # Splash: a paper disc with the stack, used on every Android. Android 12
    # shows only the inner two thirds of the drawable through its circular
    # mask, over a disc of the same paper, so the seam is invisible and the
    # stack lands at about the launcher's proportion once cropped.
    write_png(f'{out}/splash.png', size, render(size, PAPER, 0.36, disc=True))

    # Themed-icon slot: the front card's silhouette alone, in the launcher's
    # own ink.
    write_png(
        f'{out}/monochrome.png',
        size,
        render(size, None, 72.0 / 108.0, monochrome=True),
    )
