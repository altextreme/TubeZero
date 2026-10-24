#!/usr/bin/env python3
# TubeZero: builds branding/{mark,logo-wordmark,poster,splash}.svg from branding/tubezero-mark.svg.
# Wordmark on the dark UI: "Tube" in Ice White, "Zero" in TubeZero Blue. Backgrounds stay charcoal (#0F0F0F).
# Then run tools/yourtube/make-brand.sh to render them into the app images.
import os, re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
BRAND = os.path.join(ROOT, 'branding')
src = open(os.path.join(BRAND, 'tubezero-mark.svg')).read()
inner = src[src.index('<defs>'):src.rindex('</svg>')]
bx, by, bw, bh = (float(v) for v in re.search(r'<rect x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)"', src).groups())

FONT = ('<style>@font-face{font-family:YTRoboto;font-weight:700;src:url("../playlet-lib/src/fonts/roboto/Roboto-Bold.ttf")}'
        'text{font-family:YTRoboto,Roboto,"Helvetica Neue",Helvetica,Arial,sans-serif;font-weight:700;letter-spacing:-1px}</style>')


def mark(x, y, h, cid):
    """The mark's body scaled to height h with its top-left at (x, y)."""
    s = h / bh
    body = inner.replace('id="rounded"', f'id="{cid}"').replace('url(#rounded)', f'url(#{cid})')
    return f'<g transform="translate({x - bx * s:.2f} {y - by * s:.2f}) scale({s:.5f})">{body}</g>'


def width(h):
    return bw * h / bh


def word(x, y, size, anchor='start'):
    return (f'<text x="{x:.1f}" y="{y}" font-size="{size}" text-anchor="{anchor}">'
            '<tspan fill="#E4F5FF">Tube</tspan><tspan fill="#1E90FF">Zero</tspan></text>')


def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n'


def write(name, text):
    open(os.path.join(BRAND, name), 'w').write(text)


# mark alone, centered in a square (app favicon / top-left logo)
h = 64
write('mark.svg', svg(100, 100, mark((100 - width(h)) / 2, (100 - h) / 2, h, 'm')))
# mark + wordmark for the dark UI (254x100)
# (drawn at 106x42 in the nav and 76x30 in the top bar, so the gap and type are generous)
h = 46
write('logo-wordmark.svg', svg(254, 100, FONT + mark(2, (100 - h) / 2, h, 'm') + word(2 + width(h) + 16, 62, 33)))
# Roku home tile (540x405)
h = 150
write('poster.svg', svg(540, 405, FONT + '<rect width="540" height="405" fill="#0F0F0F"/>'
                        + mark((540 - width(h)) / 2, 76, h, 'm') + word(270, 312, 64, 'middle')))
# splash (1920x1080)
h = 260
write('splash.svg', svg(1920, 1080, FONT + '<rect width="1920" height="1080" fill="#0F0F0F"/>'
                        + mark((1920 - width(h)) / 2, 330, h, 'm') + word(960, 720, 104, 'middle')))
# phone web app nav logos (Svelte components swapped in by playlet-web/vite.config.ts); light theme uses navy "Tube"
os.makedirs(os.path.join(BRAND, 'web'), exist_ok=True)
for theme, tube in (('dark', '#E4F5FF'), ('light', '#092348')):
    h = 22
    body = (mark(1, 2, h, f'tz-{theme}') + f'<text x="{1 + width(h) + 6:.1f}" y="19.5" font-size="18" '
            'font-family="Roboto,Helvetica Neue,Helvetica,Arial,sans-serif" font-weight="700" letter-spacing="-0.5">'
            f'<tspan fill="{tube}">Tube</tspan><tspan fill="#1E90FF">Zero</tspan></text>')
    write(os.path.join('web', f'logo-{theme}.svg.svelte'), svg(118, 26, body))

print('branding SVGs written')
