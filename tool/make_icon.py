"""Renders the HeadShorts app mark to PNG, straight from the design board.

The mark is a column of headline rules fading down the page, closed by a short
accent rule where the feed stops. Pure stdlib: the shapes are stadiums, so a
signed-distance function gives clean antialiasing without a raster library.
"""
import struct
import sys
import zlib

# Proportions read off the 168px preview in the design board.
TILE = 168.0
MARK_W = 91.0
RULE_H = 6.0
GAP = 7.0
ACCENT_GAP = 11.2
WIDTHS = [1.00, 0.82, 0.93, 0.70, 0.86, 0.58, 0.76]
OPACITIES = [0.95, 0.82, 0.68, 0.55, 0.42, 0.30, 0.20]
ACCENT_W = 0.34

MARK_H = len(WIDTHS) * RULE_H + (len(WIDTHS) - 1) * GAP + ACCENT_GAP + RULE_H


def bars(size, mark_width_fraction):
    """Yields (x0, y0, x1, y1, index) in pixels for the given canvas size."""
    mark_w = size * mark_width_fraction
    scale = mark_w / MARK_W
    mark_h = MARK_H * scale
    left = (size - mark_w) / 2
    top = (size - mark_h) / 2

    y = top
    for i, width in enumerate(WIDTHS):
        yield (left, y, left + mark_w * width, y + RULE_H * scale, i)
        y += (RULE_H + GAP) * scale
    y += (ACCENT_GAP - GAP) * scale
    yield (left, y, left + mark_w * ACCENT_W, y + RULE_H * scale, -1)


def coverage(px, py, x0, y0, x1, y1):
    """Antialiased coverage of a stadium (fully rounded rectangle)."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2, (y1 - y0) / 2
    r = min(hx, hy)
    dx = max(abs(px - cx) - (hx - r), 0.0)
    dy = max(abs(py - cy) - (hy - r), 0.0)
    d = (dx * dx + dy * dy) ** 0.5 - r
    return min(max(0.5 - d, 0.0), 1.0)


def render(size, background, ink, accent, mark_width_fraction):
    """Returns RGBA rows. A None background leaves the canvas transparent."""
    bg = background or (0, 0, 0, 0)
    rows = [bytearray(bg * size) for _ in range(size)]

    for x0, y0, x1, y1, index in bars(size, mark_width_fraction):
        colour = accent if index < 0 else ink
        alpha = 1.0 if index < 0 else OPACITIES[index]
        for py in range(max(0, int(y0) - 2), min(size, int(y1) + 3)):
            row = rows[py]
            for px in range(max(0, int(x0) - 2), min(size, int(x1) + 3)):
                a = coverage(px + 0.5, py + 0.5, x0, y0, x1, y1) * alpha
                if a <= 0:
                    continue
                o = px * 4
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


GROUND = (10, 10, 11, 255)
INK = (239, 236, 230)
ACCENT = (228, 168, 104)
PAPER = (244, 241, 234, 255)
PAPER_INK = (23, 22, 20)
PAPER_ACCENT = (138, 85, 24)

if __name__ == '__main__':
    out = sys.argv[1].rstrip('/')
    size = 1024

    # Legacy / full-bleed icon: the mark at its preview proportion.
    write_png(
        f'{out}/icon.png',
        size,
        render(size, GROUND, INK, ACCENT, MARK_W / TILE),
    )

    # Adaptive foreground: the mark shrunk into the 66dp circular safe zone,
    # so no rule is clipped by a round, squircle or teardrop mask.
    safe = (66 / 108) * (MARK_W / TILE) * (TILE / 110)
    write_png(
        f'{out}/adaptive_foreground.png',
        size,
        render(size, None, INK, ACCENT, safe),
    )

    # Themed-icon slot: the accent rule flattens to ink.
    write_png(
        f'{out}/monochrome.png',
        size,
        render(size, None, INK, INK, safe),
    )

    # Paper variant, for the light theme's About screen.
    write_png(
        f'{out}/icon_paper.png',
        size,
        render(size, PAPER, PAPER_INK, PAPER_ACCENT, MARK_W / TILE),
    )
    print('wrote 4 icons')
