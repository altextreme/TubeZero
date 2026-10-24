#!/usr/bin/env python3
"""YourTube: renders approximate 1920x1080 previews of Home, Search and the player.

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
ITEM_H, ITEM_GAP = 50, 2    # ItemsList itemSize[1], itemSpacing[1]
ITEM_W = 222                # itemSize[0] after ResizeNavBar (widest label "Subscriptions" + padding)
SCREEN_OFFSET = ITEM_W - RAIL_W + 30
ROWS_Y = 120                # HomeScreen rowList translation (below the top bar)
ROW_X = 90                  # rowLabelOffset / focusXOffset
CARD_W, CARD_H, CARD_GAP = 350, 196, 25
ROW_PITCH = 326 + 65        # itemSize[1] + itemSpacing[1]
AGES = ["2 days ago", "5 hours ago", "1 week ago", "3 weeks ago", "4 months ago", "1 year ago"]

NAV = [
    ("Profile", None),
    ("Search", "search.png"),
    ("Home", "home.png"),
    ("Subscriptions", "yt-subscriptions.png"),
    ("You", "yt-you.png"),
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


def card(v, x, y, thumbs, focused, age, progress=0, size=(None, None), chips=()):
    card_w, card_h = size[0] or CARD_W, size[1] or CARD_H
    thumb = (thumbs / f"{v['id']}.jpg").as_uri()
    ring = ('<div style="position:absolute;left:-2px;top:-2px;right:-2px;bottom:-2px;border:5px solid #FFF;'
            'border-radius:12px"></div>') if focused else ""
    bar = ""
    if progress:
        bar = (f'<div style="position:absolute;left:0;bottom:0;width:100%;height:4px;background:#717171"></div>'
               f'<div style="position:absolute;left:0;bottom:0;width:{progress}%;height:4px;background:#F00"></div>')
    chip_html = "".join(f'<span style="display:inline-block;height:20px;line-height:20px;padding:0 5px;margin-right:6px;'
                        f'border-radius:4px;background:#3F3F3F;color:#AAAAAA;font-size:12px;font-weight:500;'
                        f'vertical-align:2px">{c}</span>' for c in chips)
    stats = " · ".join(p for p in (fmt_views(v.get("view_count")), age) if p)
    return f'''
<div style="position:absolute;left:{x}px;top:{y}px;width:{card_w}px">
 <div style="position:relative;width:{card_w}px;height:{card_h}px">
  <div style="position:relative;width:{card_w}px;height:{card_h}px;border-radius:10px;overflow:hidden;
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
  <div style="margin-top:2px;font-size:16px;color:#AAAAAA;white-space:nowrap">{chip_html}{stats}</div>
</div>'''


def img(rel):
    return (LIB / "images" / rel).as_uri()


def top_bar(shift, focused=False):
    pill_bg, text = ("#F1F1F1", "#0F0F0F") if focused else ("#282828", "#F1F1F1")
    mic = "yt-mic-dark.png" if focused else "yt-mic.png"
    return f'''
<div style="position:absolute;left:{104 + shift}px;top:46px;width:48px;height:48px;border-radius:50%;background:{pill_bg}">
  <img src="{img("icons/" + mic)}" style="position:absolute;left:11px;top:11px;width:26px;height:26px"></div>
<div style="position:absolute;left:{165 + shift}px;top:47px;width:420px;height:45px;border-radius:18px;background:{pill_bg};
            color:{text};font-size:19px;font-weight:500;line-height:45px;padding-left:22px;box-sizing:border-box">Search</div>
<img src="{img("logo-dark.png")}" style="position:absolute;left:{1124 + shift}px;top:54px;width:76px;height:30px">'''


def home(rows, thumbs, nav_expanded):
    shift = SCREEN_OFFSET if nav_expanded else 0
    parts = [top_bar(shift)]
    first_row_h = 400  # rowHeights[0] in HomeScreen.xml
    for r, (title, videos) in enumerate(rows):
        top = ROWS_Y if r == 0 else ROWS_Y + first_row_h + 65 + (r - 1) * ROW_PITCH
        size = (480, 270) if r == 0 else (CARD_W, CARD_H)
        gap = 24 if r == 0 else CARD_GAP
        parts.append(f'<div style="position:absolute;left:{ROW_X + shift}px;top:{top}px;font-size:20px;'
                     f'font-weight:700;color:#EBEBEB;line-height:24px">{html.escape(title)}</div>')
        for i, v in enumerate(videos):
            x = ROW_X + shift + i * (size[0] + gap)
            focused = (not nav_expanded) and r == 0 and i == 0
            progress = 62 if (r == 1 and i == 1) else 0
            chips = [("4K",), ("CC",), (), ("4K", "CC"), (), ("CC",)][(i + r) % 6]
            parts.append(card(v, x, top + 24 + 20, thumbs, focused, AGES[(i + r) % len(AGES)], progress, size, chips))
    return "".join(parts) + nav(nav_expanded, focus_index=2)


def search(suggestions, results, thumbs):
    kb_x, kb_y, key = 480, 40, 44
    parts = [nav(False, focus_index=1, current_index=1)]
    # Search field (TextEditBox at the top of the keyboard)
    parts.append(f'<div style="position:absolute;left:{kb_x}px;top:{kb_y}px;width:352px;height:46px;border-radius:18px;'
                 f'background:#282828;color:#AAAAAA;font-size:19px;line-height:46px;padding-left:18px;box-sizing:border-box">'
                 f'Search</div>')
    rows = ["ABCDEFG\u232b", "HIJKLMN&", "OPQRSTU\U0001F310", "VWXYZ-' "]
    grid_y = kb_y + 60
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            label = {"&": "&amp;123", "\u232b": "\u232b", "\U0001F310": "\u25CE"}.get(ch, ch)
            focused = (r == 0 and c == 0)
            style = "background:#F1F1F1;color:#0F0F0F;border-radius:8px;" if focused else "color:#BBBBBB;"
            size = 15 if ch == "&" else 19
            parts.append(f'<div style="position:absolute;left:{kb_x + c * key}px;top:{grid_y + r * key}px;width:{key}px;'
                         f'height:{key}px;line-height:{key}px;text-align:center;font-size:{size}px;{style}">{label}</div>')
    bottom_y = grid_y + 4 * key + 6
    for i, label in enumerate(["SPACE", "CLEAR", "SEARCH"]):
        parts.append(f'<div style="position:absolute;left:{kb_x + i * 117 + 2}px;top:{bottom_y}px;width:113px;height:36px;'
                     f'border-radius:18px;background:#282828;color:#F1F1F1;font-size:14px;font-weight:500;line-height:36px;'
                     f'text-align:center">{label}</div>')
    # Suggestions as pills with the history icon
    for i, text in enumerate(suggestions):
        parts.append(f'<div style="position:absolute;left:104px;top:{122 + i * 44}px;height:36px;min-width:216px;max-width:330px;'
                     f'border-radius:18px;background:#282828;color:#F1F1F1;font-size:16px;line-height:36px;'
                     f'padding:0 18px 0 44px;box-sizing:border-box;white-space:nowrap;overflow:hidden">'
                     f'<img src="{img("icons/yt-history.png")}" style="position:absolute;left:14px;top:9px;width:18px;height:18px">'
                     f'{html.escape(text)}</div>')
    # Filters button, top right
    parts.append('<div style="position:absolute;left:880px;top:42px;height:58px;padding:0 26px;border-radius:24px;'
                 'background:#282828;color:#F1F1F1;font-size:22px;line-height:58px">Filters</div>')
    # Results row
    top = 370
    parts.append(f'<div style="position:absolute;left:{ROW_X}px;top:{top}px;font-size:20px;font-weight:700;'
                 f'color:#EBEBEB;line-height:24px">Search - {html.escape(suggestions[0])}</div>')
    for i, v in enumerate(results):
        parts.append(card(v, ROW_X + i * (CARD_W + CARD_GAP), top + 44, thumbs, False, AGES[i % len(AGES)]))
    return "".join(parts)


def player(v, thumbs, related):
    frame = (thumbs / f"{v['id']}.jpg").as_uri()
    played = 0.42
    bar_x, bar_w, bar_y = 68, 1144, 535 + 3.5
    stats = " • ".join(p for p in (v.get("channel"), fmt_views(v.get("view_count")), "2 days ago") if p)
    icons = ["play.png", "minimize.png"]
    buttons = []
    for i, name in enumerate(icons):
        x = 1108 + i * 62
        focused = i == 0
        disc = "background:#F1F1F1;" if focused else ""
        color = "#0F0F0F" if focused else "#F1F1F1"
        url = img("icons/player/" + name)
        buttons.append(f'<div style="position:absolute;left:{x}px;top:458px;width:42px;height:42px;border-radius:50%;{disc}">'
                       f'<div style="width:42px;height:42px;background:{color};-webkit-mask:url({url}) center/contain no-repeat"></div></div>')
    elapsed = fmt_duration((v.get("duration") or 0) * played)
    remaining = "-" + fmt_duration((v.get("duration") or 0) * (1 - played))
    return f'''
<div style="position:absolute;inset:0;background:#000 url({frame}) center/cover"></div>
<div style="position:absolute;left:0;top:260px;width:1280px;height:460px;
            background:linear-gradient(rgba(0,0,0,0),rgba(0,0,0,.88))"></div>
<div style="position:absolute;left:64px;bottom:{720 - 506}px;width:900px">
  <div style="font-size:22px;font-weight:700;color:#F1F1F1;line-height:1.17;display:-webkit-box;-webkit-line-clamp:2;
              -webkit-box-orient:vertical;overflow:hidden">{html.escape(v["title"])}</div>
  <div style="margin-top:6px;font-size:15px;color:#AAAAAA">{html.escape(stats)}</div>
</div>
{"".join(buttons)}
<div style="position:absolute;left:{bar_x}px;top:{bar_y}px;width:{bar_w}px;height:5px;border-radius:3px;background:rgba(255,255,255,.45)"></div>
<div style="position:absolute;left:{bar_x}px;top:{bar_y}px;width:{bar_w * played}px;height:5px;border-radius:3px 0 0 3px;
            background:linear-gradient(90deg,#FB0034,#FD1C7A {100 / played}%)"></div>
<div style="position:absolute;left:{bar_x + bar_w * played - 6}px;top:535px;width:12px;height:12px;border-radius:50%;background:#FFF"></div>
<div style="position:absolute;left:{bar_x}px;top:561px;font-size:16px;color:#F1F1F1">{elapsed}</div>
<div style="position:absolute;left:{bar_x + bar_w - 120}px;top:561px;width:120px;text-align:right;font-size:16px;color:#F1F1F1">{remaining}</div>
'''


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
    render(page(search(["japan travel vlog", "japan travel guide", "japan food tour", "tokyo night walk",
                        "kyoto in autumn"], videos[12:18], thumbs)), out / "06-search.png", out)
    render(page(player(videos[1], thumbs, videos[6:12])), out / "07-player.png", out)
    for f in out.glob("*.html"):
        f.unlink()


if __name__ == "__main__":
    main()
