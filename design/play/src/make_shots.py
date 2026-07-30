#!/usr/bin/env python3
"""Compose Play Store screenshots: caption + framed device screenshot.

Renders one 1080x1920 CSS layout per shot through headless Chrome at three
device scale factors, giving the phone, 7-inch and 10-inch tablet sizes Play
asks for. Every output is exactly 9:16.
"""
import base64
import pathlib
import subprocess
import sys

SP = pathlib.Path(__file__).parent
OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else SP / 'out'

# (source screenshot, slug, headline, subline, accent role, zoom)
SHOTS = [
    ('01-today.png', 'today', 'Your next workout,\none tap away',
     'It remembers where you left off', 'accent', 1),
    ('05-live-rest.png', 'live-session', 'Tap a set.\nThat’s the log.',
     'Plate maths per side. Rest timer. No typing.', 'good', 1),
    ('04-warmup.png', 'warm-up', 'Warm-up sets,\nworked out for you',
     'Ramped to the working load — adjust or skip', 'accent', 1),
    ('11-progress.png', 'progress', 'Watch the load\nclimb',
     'Every top set, exercise by exercise', 'gold', 1),
    ('07-session-detail.png', 'history', 'Every session,\nkept on the phone',
     'Duration, sets, and every load you lifted', 'good', 1),
    ('21-theme-custom.png', 'themes', 'Every colour\nis yours',
     'Start from one of eight themes, then repaint it', 'accent', 1),
    ('22-accessibility.png', 'accessibility', 'Readable\nat any size',
     'Four text sizes, and two themes checked to WCAG AAA', 'gold', 1),
    ('16-qr.png', 'share-qr', 'Send it to your\ngym buddy',
     'They scan the QR — the whole routine lands on their phone',
     'accent', 1),
]

# The three Play slots: (directory name, scale factor). 1080x1920 * factor.
SLOTS = [('phone', 1), ('tablet-7', 4 / 3), ('tablet-10', 1.5)]

CSS = """
:root{
  --ground:#0F1218; --surface:#171B24; --surface2:#1F2530; --line:#2A313D;
  --text:#EAEEF5; --muted:#8B95A7; --faint:#5A6474;
  --accent:#FF6A3D; --good:#3ED598; --gold:#FFC24B;
  --sans:"Inter Display","Inter",sans-serif;
  --mono:"JetBrainsMono NF","JetBrains Mono",monospace;
}
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:1080px;height:1920px}
body{background:var(--ground);font-family:var(--sans);color:var(--text);overflow:hidden}
.stage{position:relative;width:1080px;height:1920px;overflow:hidden}
.grid{position:absolute;inset:0;
  background-image:linear-gradient(var(--line) 1px,transparent 1px),
                   linear-gradient(90deg,var(--line) 1px,transparent 1px);
  background-size:40px 40px;opacity:.28;
  mask-image:radial-gradient(90% 60% at 50% 18%,#000 0%,transparent 75%)}
.glow{position:absolute;width:1500px;height:1200px;left:-210px;top:-620px;
  background:radial-gradient(circle,var(--halo) 0%,transparent 62%)}
.cap{position:absolute;left:76px;right:76px;top:104px}
.h{font-size:76px;line-height:1.06;font-weight:800;letter-spacing:-.032em;
  white-space:pre-line}
.h em{font-style:normal;color:var(--hue)}
.sub{margin-top:26px;font-size:31px;line-height:1.4;font-weight:500;
  color:var(--muted);letter-spacing:-.005em}
.frame{position:absolute;left:120px;top:470px;width:840px;height:1560px;
  border-radius:56px;border:1px solid var(--line);background:var(--surface);
  box-shadow:0 40px 90px rgba(0,0,0,.6);overflow:hidden}
.frame img{display:block;width:calc(100% * var(--zoom));margin-left:calc((100% - 100% * var(--zoom)) / 2)}
"""

HTML = """<style>{css}</style>
<div class="stage" style="--halo:{halo};--hue:var(--{role})">
  <div class="grid"></div><div class="glow"></div>
  <div class="cap">
    <div class="h">{head}</div>
    <div class="sub">{sub}</div>
  </div>
  <div class="frame" style="--zoom:{zoom}"><img src="data:image/png;base64,{b64}"></div>
</div>
"""

HALO = {'accent': 'rgba(255,106,61,.22)',
        'good': 'rgba(62,213,152,.16)',
        'gold': 'rgba(255,194,75,.16)'}

for slot, _ in SLOTS:
    (OUT / slot).mkdir(parents=True, exist_ok=True)

for i, (src, slug, head, sub, role, zoom) in enumerate(SHOTS, 1):
    b64 = base64.b64encode((SP / src).read_bytes()).decode()
    # The last word of the headline picks up the accent colour.
    first, _, last = head.rpartition('\n')
    words = last.split(' ')
    lit = ' '.join(words[:-1] + [f'<em>{words[-1]}</em>']) if len(words) > 1 \
        else f'<em>{last}</em>'
    page = SP / f'page-{i}.html'
    page.write_text(HTML.format(css=CSS, halo=HALO[role], role=role, zoom=zoom,
                                head=(first + '\n' + lit) if first else lit,
                                sub=sub, b64=b64))
    for slot, factor in SLOTS:
        raw = SP / f'raw-{slot}-{i}.png'
        subprocess.run(
            ['google-chrome', '--headless', '--disable-gpu', '--hide-scrollbars',
             f'--force-device-scale-factor={factor}', '--window-size=1080,1920',
             f'--screenshot={raw}', str(page)],
            check=True, capture_output=True)
        w = round(1080 * factor)
        subprocess.run(['magick', str(raw), '-resize', f'{w}x{round(w*16/9)}!',
                        '-strip', f'PNG24:{OUT / slot / f"{i:02d}-{slug}.png"}'],
                       check=True)
        raw.unlink()
    print(f'{i}: {src} -> {head.replace(chr(10), " ")}')

for slot, _ in SLOTS:
    files = sorted((OUT / slot).glob('*.png'))
    ident = subprocess.run(['identify', '-format', '%f %wx%h %B\n', *map(str, files)],
                           capture_output=True, text=True).stdout
    print(f'\n{slot}:\n{ident}', end='')
