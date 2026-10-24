#!/usr/bin/env python3
"""YourTube: renders approximate 1920x1080 previews of the Home screen.

These are NOT device captures. They re-create the SceneGraph layout in HTML from the
values in the app code (720p units, rendered at 1.5x like the TV does) so the look can
be judged before sideloading. Real captures come from the TV once the app is installed.

Usage: render-previews.py <videos.json> <thumbs_dir> <out_dir>
  videos.json: [{id, title, channel, view_count, duration}], thumbs_dir/<id>.jpg
"""
import html
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LIB = ROOT / "playlet-lib/src"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Values copied from the code (720p units)
BG = "#0F0F0F"
RAIL_W = 62                 # NavBar Background width
LIST_X, LIST_Y = 13, 150    # NavBar ItemsList translation
ITEM_H, ITEM_GAP = 50, 16   # ItemsList itemSize[1], itemSpacing[1]
ITEM_W = 195                # itemSize[0] after ResizeNavBar (widest label + padding)
SCREEN_OFFSET = ITEM_W - RAIL_W + 30
ROWS_Y = 50                 # HomeScreen rowList translation
ROW_X = 90                  # rowLabelOffset / focusXOffset
CARD_W, CARD_H, CARD_GAP = 350, 196, 25
ROW_PITCH = 326 + 65        # itemSize[1] + itemSpacing[1]
AGES = ["2 days ago", "5 hours ago", "1 week ago", "3 weeks ago", "4 months ago", "1 year ago"]

NAV = [
    ("Profile", None),
    ("Search", "search.png"),
    ("Home", "home.png"),
    ("Bookmarks", "star.png"),
    ("Settings", "settings.png"),
    ("Remote", "phone.png"),
    ("Info", "info.png"),
]


def font_faces():
    faces = []
    for weight, name in ((400, "Regular"), (500, "Medium"), (700, "Bold")):
        url = (LIB / f"fonts/roboto/Roboto-{name}.ttf").as_uri()
        faces.append(f"@font-face{{font-family:Roboto;font-weight:{weight};src:url('{url}')}}")
    return "\n".join(faces)


def fmt_views(n):
    if not n:
        return ""
    for div, suffix in ((1e9, "B"), (1e6, "M"), (1e3, "K")):
        if n >= div:
            v = n / div
            return f"{v:.1f}".rstrip("0").rstrip(".") + f"{suffix} views"
    return f"{n} views"


def fmt_duration(s):
    s = int(s or 0)
    h, m, sec = s // 3600, s % 3600 // 60, s % 60
    return f"{h}:{m:02}:{sec:02}" if h else f"{m}:{sec:02}"


def icon(name, color):
    url = (LIB / "images/icons" / name).as_uri()
    return (f'<div style="position:absolute;left:8px;top:8px;width:32px;height:32px;background:{color};'
            f'-webkit-mask:url({url}) center/contain no-repeat"></div>')


def nav(expanded, focus_index, current_index=2):
    items = []
    for i, (label, png) in enumerate(NAV):
        top = LIST_Y + i * (ITEM_H + ITEM_GAP)
        on_pill = expanded and i == focus_index
        is_current = (not expanded) and i == current_index
        if on_pill:
            color = "#161616"
        elif is_current:
            color = "#EBEBEB"
        else:
            color = "#929292"
        pill = (f'<div style="position:absolute;left:0;top:0;width:{ITEM_W}px;height:{ITEM_H}px;'
                f'border-radius:8px;background:#F1F1F1"></div>') if on_pill else ""
        if png:
            glyph = icon(png, color)
        else:
            user = (LIB / "images/icons/user.png").as_uri()
            glyph = (f'<div style="position:absolute;left:4px;top:4px;width:40px;height:40px;border-radius:50%;'
                     f'background:#5A5A5A url({user}) center/26px no-repeat"></div>')
        text = ""
        if expanded:
            weight, tcolor = (500, "#0F0F0F") if on_pill else (400, "#DDDDDD")
            text = (f'<div style="position:absolute;left:55px;top:8px;height:32px;line-height:32px;'
                    f'font-size:22px;font-weight:{weight};color:{tcolor};white-space:nowrap">{label}</div>')
        opacity = 1 if expanded else 0.8
        items.append(f'<div style="position:absolute;left:{LIST_X}px;top:{top}px;width:{ITEM_W}px;'
                     f'height:{ITEM_H}px;opacity:{opacity}">{pill}{glyph}{text}</div>')

    logo = (LIB / ("images/logo-dark.png" if expanded else "images/logo-fav.png")).as_uri()
    logo_w = 106 if expanded else 42
    side = (f'<div style="position:absolute;left:{RAIL_W}px;top:0;width:{SCREEN_OFFSET}px;height:720px;'
            f'background:{BG};opacity:0.9"></div>') if expanded else ""
    version = ('<div style="position:absolute;left:16px;top:96px;font-size:16px;font-weight:700;color:#DDDDDD">'
               'v0.48.10</div>') if expanded else ""
    return (f'{side}<div style="position:absolute;left:0;top:0;width:{RAIL_W}px;height:720px;background:{BG};'
            f'opacity:{1.0 if expanded else 0.9}"></div>'
            f'<img src="{logo}" style="position:absolute;left:16px;top:48px;width:{logo_w}px;height:42px">'
            f'{version}{"".join(items)}')


def card(v, x, y, thumbs, focused, age, progress=0):
    thumb = (thumbs / f"{v['id']}.jpg").as_uri()
    ring = ('<div style="position:absolute;left:-2px;top:-2px;right:-2px;bottom:-2px;border:5px solid #FFF;'
            'border-radius:12px"></div>') if focused else ""
    bar = ""
    if progress:
        bar = (f'<div style="position:absolute;left:0;bottom:0;width:100%;height:4px;background:#717171"></div>'
               f'<div style="position:absolute;left:0;bottom:0;width:{progress}%;height:4px;background:#F00"></div>')
    stats = " · ".join(p for p in (fmt_views(v.get("view_count")), age) if p)
    return f'''
<div style="position:absolute;left:{x}px;top:{y}px;width:{CARD_W}px">
 <div style="position:relative;width:{CARD_W}px;height:{CARD_H}px">
  <div style="position:relative;width:{CARD_W}px;height:{CARD_H}px;border-radius:10px;overflow:hidden;
              background:#222 url({thumb}) center/cover">
    {bar}
    <div style="position:absolute;right:6px;bottom:6px;height:24px;line-height:24px;padding:0 7px;
                border-radius:4px;background:rgba(0,0,0,.7);color:#FFF;font-size:15px;font-weight:500">
      {fmt_duration(v.get("duration"))}</div>
  </div>
  {ring}
 </div>
  <div style="margin-top:22px;font-size:20px;font-weight:700;color:#F1F1F1;line-height:1.17;
              display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden">
    {html.escape(v["title"])}</div>
  <div style="margin-top:6px;font-size:16px;color:#AAAAAA;white-space:nowrap;overflow:hidden;
              text-overflow:ellipsis">{html.escape(v.get("channel") or "")}</div>
  <div style="margin-top:2px;font-size:16px;color:#AAAAAA;white-space:nowrap">{stats}</div>
</div>'''


def home(rows, thumbs, nav_expanded):
    shift = SCREEN_OFFSET if nav_expanded else 0
    parts = []
    for r, (title, videos) in enumerate(rows):
        top = ROWS_Y + r * ROW_PITCH
        parts.append(f'<div style="position:absolute;left:{ROW_X + shift}px;top:{top}px;font-size:20px;'
                     f'font-weight:700;color:#EBEBEB;line-height:24px">{html.escape(title)}</div>')
        for i, v in enumerate(videos):
            x = ROW_X + shift + i * (CARD_W + CARD_GAP)
            focused = (not nav_expanded) and r == 0 and i == 0
            progress = 62 if (r == 1 and i == 1) else 0
            parts.append(card(v, x, top + 24 + 20, thumbs, focused, AGES[(i + r) % len(AGES)], progress))
    return "".join(parts) + nav(nav_expanded, focus_index=2)


def page(body):
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>
{font_faces()}
html,body{{margin:0;width:1280px;height:720px;overflow:hidden;background:{BG};font-family:Roboto}}
</style></head><body><div style="position:relative;width:1280px;height:720px">{body}</div></body></html>'''


def render(html_text, out_png, work):
    src = work / (out_png.stem + ".html")
    src.write_text(html_text)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    "--allow-file-access-from-files", "--force-device-scale-factor=1.5",
                    "--window-size=1280,720", f"--screenshot={out_png}", src.as_uri()],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    videos = json.load(open(sys.argv[1]))
    thumbs = pathlib.Path(sys.argv[2]).resolve()
    out = pathlib.Path(sys.argv[3]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    rows = [("Subscriptions", videos[0:6]), ("Recommended", videos[6:12])]
    render(page(home(rows, thumbs, nav_expanded=False)), out / "03-home.png", out)
    render(page(home(rows, thumbs, nav_expanded=True)), out / "04-home-nav-open.png", out)
    rows2 = [("Trending", videos[12:18]), ("Popular", videos[0:6])]
    render(page(home(rows2, thumbs, nav_expanded=False)), out / "05-home-more-rows.png", out)
    for f in out.glob("*.html"):
        f.unlink()


if __name__ == "__main__":
    main()
