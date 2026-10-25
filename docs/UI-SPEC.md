# YourTube UI spec

Measured from the official YouTube Roku app screenshots in [`reference/`](../reference) (Roku Channel Store images, 800×454).
Where these photos and the brief disagree, the photos win.

**Units.** Playlet's lib is authored at 720p (`ui_resolutions=hd`, 1280×720) and Roku scales it on the 1080p TV.
All values below are in **720p units** (photo px × 1.6). Multiply by 1.5 for 1080p pixels.
Values marked *est.* were hard to read at this resolution; check against photos taken on the TV.

| Reference | Shows |
| --- | --- |
| `01-home.png` | Home, focused card, collapsed nav rail, top search bar |
| `02-music.png` | Standard shelf sizes, CC/4K chips |
| `03-search.png` | Search: suggestions, keyboard, results shelf |
| `04-player.png` | Player overlay: title, actions, scrubber, related shelf |
| `05-account-picker.png` | Account picker (not in scope; Playlet has its own profiles screen) |

## Color

| Token | Value | Source |
| --- | --- | --- |
| Background | `#0F0F0F` | sampled (15,15,15) |
| Primary text | `#F1F1F1` | titles, row titles |
| Secondary text | `#AAAAAA` | channel, stats |
| Nav icon, current | `#FFFFFF` (filled icon) | sampled `#FDFDFD` |
| Nav icon, other | `#929292` (outline icon) | sampled |
| Surface (search pill, keys, suggestion pills) | `#282828` | sampled |
| Chip (4K, CC) | `#3F3F3F` bg, `#AAAAAA` text *est.* | |
| Scrubber played | gradient `#FB0034` → `#FD1C7A` (red to pink) | sampled |
| Scrubber buffered | `#B7B6B9` | sampled |
| Scrubber unplayed | `#818183` (white ~50% over video) | sampled |
| Focus ring | `#FFFFFF` | |

Lint in this repo requires broadcast-safe colors in `.bs` code, so code uses `#EBEBEB` / `#161616` where the spec says white / black. XML values are not linted.

## Layout: Home

- **Content left edge:** x = 104.
- **Top bar** (y center 70):
  - Mic button: circle, diameter ≈ 48, center (128, 70), fill `#282828`.
  - Search pill: x 165–584, height 45, fully rounded, fill `#282828`, placeholder "Search" in `#F1F1F1` at ≈ 19 Medium.
  - Logo: right-aligned, ends at x ≈ 1200, height ≈ 28.
- **Row title:** ≈ 18–20 Bold, `#F1F1F1`, baseline ≈ 34 above the thumbnails' top edge.
- **Row pitch:** ≈ 448 for standard shelves, ≈ 490 for the large first shelf.

## Video card

| Part | Spec |
| --- | --- |
| Thumbnail, standard shelf | 352 × 198 (16:9), gap 21–24 |
| Thumbnail, first home shelf | 480 × 270, gap 24 (large "Recommended" row) |
| Corner radius | ≈ 10 |
| Focus | white ring ≈ 5 thick drawn on the thumbnail edge (no gap), radius ≈ 11. **No scale-up** (focused card is the same width as its neighbours). |
| Duration badge | bottom-right, inset 6, height ≈ 24, radius ≈ 3, black ≈ 70%, text white ≈ 15 Medium |
| Title | ≈ 20 Bold, `#F1F1F1`, max 2 lines, line height ≈ 29, top ≈ 22 below thumbnail |
| Line 2 | channel name, ≈ 16 Regular, `#AAAAAA` |
| Line 3 | optional chips (`4K`, `CC`) then `28K views · 3 years ago`, ≈ 16 Regular, `#AAAAAA`, separator is a middle dot `·` |
| Watch progress | red bar along the thumbnail bottom (not visible in these shots; kept from the brief) |

## Nav rail (collapsed)

- Rail has no separate background; same `#0F0F0F` as the page.
- Column center x ≈ 51.
- Avatar at top: circle, diameter ≈ 35, center y ≈ 70.
- Icons ≈ 20 tall, pitch ≈ 52, first icon (Search) at y ≈ 157.
- Order seen: Search, Home, (Shorts), (Movies), (Gaming), (Subscriptions), (Library), (More) … then Settings and one more at the bottom (y ≈ 613 and 664).
- Current section: white filled icon. Others: gray outline icons. **No pill or highlight shape** when collapsed.
- Expanded state (labels) is not in these photos. Until we have one, YourTube shows the focused item as a white pill with a dark icon and label.

## Search

- Search pill moves to the top and widens to x 165–848; mic button turns white when active ("Voice search" placeholder).
- **Suggestions on the left** (x 104–320): pills height ≈ 35, fully rounded, `#282828`, history icon then text ≈ 16 `#F1F1F1`.
- **Keyboard in the middle** (starts x ≈ 480): 7 columns A–G / H–N / O–U / V–Z - ', key pitch ≈ 45 × 45, plain text keys ≈ 19 `#BBBBBB`, no key backgrounds. Right column: backspace, `&123`, globe.
- Bottom key row: SPACE, CLEAR, SEARCH as `#282828` rounded keys, text ≈ 14 Medium.
- Results shelf ("From recommended searches") below at y ≈ 392 with standard cards.
- (The brief said "suggestions to the right"; the photo has them on the left.)

## Player overlay

- Dark gradient scrim over the bottom ~55% of the frame.
- **Title:** x 64, top ≈ 420, ≈ 22 Bold, `#F1F1F1`, max 2 lines (uppercase in the photo is the video's own title).
- **Meta:** `Channel • 55K views • 3 years ago` ≈ 15 `#AAAAAA`, under the title.
- **Action row:** right-aligned, ending x ≈ 1190, center y ≈ 480. Icons ≈ 22, pitch ≈ 59. Order: channel avatar, Captions, Like, Dislike, Save, Settings. YourTube adds Comments and Quality per the brief.
- **Scrubber:** x 64–1216, y ≈ 541, ≈ 5 thick, played portion red→pink gradient, buffered light gray, rest mid gray, white circular thumb ≈ 22.
- **Times:** elapsed at left, duration at right, y ≈ 571, ≈ 15 `#F1F1F1`.
- **Related shelf** peeks in under the scrubber at y ≈ 602 (standard cards).

## Type

Roboto (Apache 2.0, bundled in `playlet-lib/src/fonts/roboto`). The build maps Roku's `font:SystemFontFile`, `MediumSystemFontFile` and `BoldSystemFontFile` to Roboto Regular, Medium and Bold.
Playlet's preset font names (`font:SmallestSystemFont` etc.) still use the Roku system font; those get converted screen by screen.

## Motion

Not measurable from stills. Target from the brief: 150–200 ms eased focus movement, no lag. Playlet's RowList uses floating focus, which is native and smooth.

## Status (what YourTube matches today)

How the restyle is applied:
- **App-wide (build plugin, `tools/bs-plugins/yourtube-rebrand-plugin.ts`):** Playlet palette mapped to the colors above,
  every Roku system/preset font converted to Roboto, Playlet's glow focus swapped for the white ring and its buttons
  for rounded pills. Upstream files stay untouched for these.
- **Per screen:** the edits listed below, each marked `YourTube:` in the source.

| Area | Status |
| --- | --- |
| Colors, background, fonts (every screen) | Done |
| Card: thumbnail, radius, badge, title, channel, stats line, focus ring | Done |
| Home top bar: mic, Search pill, logo; Up from the first row, OK opens Search | Done |
| Nav rail: gray icons, white current icon, white focus pill | Done |
| Search: A–G keyboard, &123 page, SPACE/CLEAR/SEARCH, padded input pill, 5 pill suggestions, results row | Done, checked on the TV |
| Player: title above a right-aligned action row, thin red→pink scrubber, bottom scrim | Done (Play/Pause, Minimize, Comments, Like, Dislike, Save, Subscribe, CC, Description, Settings), checked on the TV |
| Comments panel: right side, 560 wide, `#212121`, round avatars, `#3F3F3F` focused card | Done, checked on the TV |
| Dialogs (`#212121` surface), context menu, settings categories, buttons | Done |
| Info screen: TubeZero labels, Playlet AGPL credit | Done |
| Large first shelf (480 × 270) | Done, checked on the TV (first open included) |
| CC / 4K / HDR chips on cards | Done (badges parsed from YouTube's renderers) |
| Related shelf under the player scrubber | Done (Down from the scrubber), checked on the TV |
| Nav items: Shorts, Subscriptions, You and Live added, 52px pitch, Material Symbols | Done, checked on the TV |
| Voice search via the mic button on Home | Opens Search; a hint under the keyboard, dictated text searches by itself (real dictation still needs a TV check) |
| Empty states (Subscriptions, You, Live) | Done |
| Lists in settings, dialogs, context menu: inset white pill, no sideways shift | Done |
