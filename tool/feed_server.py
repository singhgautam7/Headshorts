#!/usr/bin/env python3
"""Local feeds for the perf harness, so numbers do not depend on publishers.

    python3 tool/feed_server.py [--items 60] [--port 8791]

On the emulator it is http://10.0.2.2:8791.
  /feed/N.xml   RSS, `--items` items over the last `--days` days (N in 0..99)
  /slow/N.xml   answers after 60s (past the app's 15s ceiling)
  /error/N.xml  HTTP 500        /empty/N.xml  an empty body
  /bad/N.xml    malformed XML   /huge/N.xml   a 12 MB feed
  /img/N.jpg    a 1600x1000 JPEG
  /a/N/M        a long article page with pictures
"""
import argparse, datetime, email.utils, http.server, os, random, socketserver, subprocess, sys, tempfile, time

ap = argparse.ArgumentParser()
ap.add_argument('--items', type=int, default=60)
ap.add_argument('--days', type=float, default=3)
ap.add_argument('--port', type=int, default=8791)
A = ap.parse_args()
HOST = f'http://10.0.2.2:{A.port}'
W = ('river council budget monsoon railway strike harvest satellite court festival export cricket '
     'museum bridge election hospital garden tiger summit bakery copper island library solar orchestra '
     'glacier airport lantern fishery vaccine archive furnace canyon parade village laser forest '
     'treaty pension comet sculpture harbour engine border market school lake station mural').split()
V = 'opens delays wins rejects repairs studies expands closes debates funds protects launches'.split()

def title(r):
    return ' '.join([r.choice(W).title(), r.choice(W), r.choice(V), r.choice(W), 'as', r.choice(W), r.choice(W), r.choice(W)])

def prose(r, n):
    return ' '.join(' '.join(r.choice(W) for _ in range(14)).capitalize() + '.' for _ in range(n))

def jpeg():
    """One 1600x1000 JPEG: a BMP of noise bands, converted by macOS `sips`."""
    d = tempfile.mkdtemp(); bmp = os.path.join(d, 'a.bmp'); out = os.path.join(d, 'a.jpg')
    w, h = 1600, 1000; row = w * 3
    import struct
    with open(bmp, 'wb') as f:
        f.write(struct.pack('<2sIHHIIIIHHIIIIII', b'BM', 54 + row * h, 0, 0, 54, 40, w, h, 1, 24, 0, row * h, 2835, 2835, 0, 0))
        r = random.Random(1)
        for y in range(h):
            f.write(bytes((int(x * 255 / w) ^ (y * 255 // h)) if c else r.randrange(256) for x in range(w) for c in range(3)))
    subprocess.run(['sips', '-s', 'format', 'jpeg', bmp, '--out', out], check=True, stdout=subprocess.DEVNULL)
    return open(out, 'rb').read()

IMG = jpeg()

def feed(n, items):
    r = random.Random(n * 7919)
    now = datetime.datetime.now(datetime.timezone.utc)
    out = [f'<?xml version="1.0"?><rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/"><channel><title>Perf {n}</title><link>{HOST}</link>']
    for m in range(items):
        at = now - datetime.timedelta(days=A.days * m / items, minutes=n)
        body = ''
        if m % 8 == 0:
            body = '<content:encoded><![CDATA[' + ''.join(f'<p>{prose(r, 5)}</p>' for _ in range(40)) + ']]></content:encoded>'
        out.append(f'<item><title>{title(r)} {n}-{m}</title><link>{HOST}/a/{n}/{m}</link><guid>{HOST}/a/{n}/{m}</guid>'
                   f'<description>{prose(r, 2)}</description><pubDate>{email.utils.format_datetime(at)}</pubDate>'
                   f'<enclosure url="{HOST}/img/{n * 1000 + m}.jpg" type="image/jpeg" length="1"/>{body}</item>')
    out.append('</channel></rss>')
    return ''.join(out).encode()

def article(n, m):
    r = random.Random(n * 31 + m)
    ps = []
    for i in range(60):
        ps.append(f'<p>{prose(r, 5)} <a href="/a/{n}/{i}">linked words here</a></p>')
        if i % 6 == 2:
            ps.append(f'<figure><img src="{HOST}/img/{n * 1000 + i}.jpg" width="1600" height="1000"><figcaption>{prose(r, 1)}</figcaption></figure>')
    return (f'<html><head><title>{title(r)}</title></head><body><article itemprop="articleBody"><h1>{title(r)}</h1>' + ''.join(ps) + '</article></body></html>').encode()

class H(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *_): pass
    def send(self, code, body, kind):
        self.send_response(code); self.send_header('Content-Type', kind)
        self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        p = self.path.split('?')[0].strip('/').split('/')
        try:
            if p[0] == 'feed': self.send(200, feed(int(p[1].split('.')[0]), A.items), 'application/rss+xml')
            elif p[0] == 'img': self.send(200, IMG, 'image/jpeg')
            elif p[0] == 'a': self.send(200, article(int(p[1]), int(p[2])), 'text/html; charset=utf-8')
            elif p[0] == 'slow': time.sleep(60); self.send(200, feed(1, 5), 'application/rss+xml')
            elif p[0] == 'error': self.send(500, b'no', 'text/plain')
            elif p[0] == 'empty': self.send(200, b'', 'application/rss+xml')
            elif p[0] == 'bad': self.send(200, feed(1, 5)[:900], 'application/rss+xml')
            elif p[0] == 'huge': self.send(200, feed(1, 9000), 'application/rss+xml')
            else: self.send(404, b'no', 'text/plain')
        except (BrokenPipeError, ConnectionResetError): pass

class S(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

print('serving', HOST, file=sys.stderr)
S(('0.0.0.0', A.port), H).serve_forever()
