# TubeZero changelog

(Called YourTube until 2026-10-24; file and code names keep the old name to avoid churn.)

Changes on top of [Playlet](https://github.com/iBicha/playlet) (AGPL-3.0). Newest first.

## Unreleased: TubeZero

### Personal extras and polish (not yet checked on the TV)
- Phone pairing: account and playback routes on the phone web server (every POST/PUT/DELETE except DIAL, DRM
  licenses, the built-in Invidious backend and `/api/pair*`; plus GET `/watch`, `/api/view/open`,
  `/invidious/login`, `/invidious/authenticated-request`, `/api/innertube/potoken`) answer 401 until the phone
  pairs. The phone asks the TV for a code (`POST /api/pair/code`, shown in the on-screen-code dialog), sends it
  (`POST /api/pair {code}`) and gets a token, kept in localStorage and sent as `X-TubeZero-Pair` (the TV also sets
  a `tz_pair` cookie so plain links work). The phone app and the Live page pair and retry on a 401. Up to 10
  tokens are kept in the registry; Settings > More > "Forget paired phones" revokes them. The X-Playlet CSRF
  check is unchanged, and casting from the YouTube app (DIAL/Lounge) needs no pairing.
- Blocklist: Settings > Content Feed > "Blocked channels" and "Blocked keywords" (comma-separated). Matching cards
  are left out of every feed row, the Home shelf rows, search, the Subscriptions grid, Related and Shorts. Channels
  match by name (any case, "@" ignored) or channel id; keywords match whole words in the title. Long-press a card >
  "Block this channel" adds it and removes its cards from the screen. A page of only blocked cards keeps paging.
- Your stats (Settings > More): watch time today, in the last 7 and 30 days, the five most watched channels and
  SponsorBlock time saved. `YourTubeWatchStatsTracker` observes each player's position/state from VideoQueue
  (wall-clock time while playing, saved at most once a minute); SponsorBlock auto/manual skips add the segment
  length. Kept only on the TV, in one compact registry value (30 days, 25 channels).
- Sentence-case titles (Settings > Content Feed > "Fix ALL-CAPS titles", on by default): a title that is mostly
  capitals is shown in sentence case on cards, Related, the player title, Shorts and the long-press menu.
  Acronyms (NBA, USA, ASMR), two-letter non-words (VR, UK, TV), words with digits (4K, PS5), hashtags, @handles,
  Roman numerals, "I" and mixed-case words (iPhone) are kept; sentences and text after " - " / " | " start with
  a capital. `YourTubeText.CleanTitle` = Clean + `FixCaps`; the setting is mirrored to the global
  `ytFixCapsTitles` field for cards and jobs.
- Back on Home (and You) below the first row jumps to the first row; the next Back goes to the nav as before.
  Home, Subscriptions and You already keep their focused row and card when you leave and come back (root screens
  stay alive and RowList keeps its focus); the one reset found, You rebuilding its rows after a bookmark change,
  now returns to the row you were on.
- Comments panel backdrop: the video's thumbnail (`mqdefault`) decoded at a tenth of the panel size and stretched,
  which reads as a heavy blur, under a #0F0F0F scrim at 85% (`YourTubeThumbBackdrop`, reusable for other opaque
  panels). Not added to the large pause icon, the Related row or live chat: those sit over the video itself, so the
  paused frame already is the backdrop.
### Library and account (not yet checked on the TV)
- Save to playlist: long-press a video (rows and playlist pages) > "Save to playlist..." opens "Save video to..."
  with your playlists as check boxes (OK adds or removes right away) plus "New playlist" (Roku keyboard; the new
  playlist is private and starts with the video). `playlist/get_add_to_playlist`, `browse/edit_playlist`,
  `playlist/create` on the TV client with the profile's token. The player's Save button can open the same dialog
  with `m.global.yourtubeLibrary@.OpenSaveToPlaylist(videoId)` (not wired yet).
- Not interested / Don't recommend channel / Remove from watch history: NodesParser keeps the feedback tokens from a
  card's menu (`feedbackTokens` on the video node); cards that have them get the long-press items. The card leaves
  its row, the token goes to InnerTube `feedback`, and an "Undo" toast (OK to undo) appears when YouTube sent an
  undo token. Hidden when signed out.

### Shorts, Subscriptions, deeper Home, tidier nav (not yet checked on the TV)
- Nav: Profile, Search, Home, Shorts, Subscriptions, You, Live, Settings. Bookmarks rows moved into You; Phone remote
  and About moved to Settings > More (full-screen pages, Back returns).
- Shorts tab: the Short plays in a centered 9:16 frame (the shared player in a custom rect), Up/Down for the
  previous/next Short, title/channel/views beside it, endless feed from `reel/reel_watch_sequence`. Respects
  Disable Shorts.
- Subscriptions: a row of your subscribed channels (OK opens the channel), then latest videos as a 4-column grid
  that pages in as you scroll. Debug route `GET /api/yourtube/debug/subscribed-channels` shows the raw fetch.
- Home: every shelf YouTube returns for your home page is its own row, plus Live, Music, Gaming, News, Sports,
  Movies & trailers, Learning & science, Podcasts and Fashion & beauty rows. Empty rows are removed; the home
  screen editor lists the new rows.

### Sign-in flow restyle
- Profile: "Accounts" heading, a signed-out explanation, an "Add account" tile (plus in a dark circle) and a white
  focus ring instead of the floating avatar, drop shadow and square focus frame.
- Account type picker: matching white-circle logos, "Choose an account type", and a darker dim behind it.
- Disclaimer: narrower panel (820) with paragraph spacing.
- New full-screen "Sign in to YouTube" page (`YourTubeSignInView`) instead of Roku's cramped login dialog: two
  numbered steps, the code large, a QR code, Cancel. Same YouTubeLoginJob, so approving on the phone moves straight on
  to picking the account.

### Rebrand to TubeZero
- New name everywhere people see it: TV title, launcher, Info screen, cast name ("TubeZero on ..."), phone pages,
  build zip (`out/TubeZero-*.zip`). The build-time rename now maps Playlet to TubeZero.
- New mark (cleaned up from the provided concept): blue rounded player with a snow cap, layered frozen mountains and
  a white play triangle. Wordmark "Tube" Ice White + "Zero" TubeZero Blue on the charcoal UI; navy "Tube" on light.
  `tools/yourtube/brand-svgs.py` builds every branding SVG from `branding/tubezero-mark.svg`; `make-brand.sh`
  renders the Roku tile, splash and logos (the UI 9-patches stay in `make-assets.sh`).
- Phone web app: a Vite plugin swaps in the TubeZero logos and renames "Playlet" in visible text at build time.
- Backgrounds stay charcoal; blue is only the brand color. Progress bars and LIVE badges stay YouTube red.

## Phase 3 comments, interaction pass

### Comments (Phase 3)
- Comments button in the player action row opens a side panel over the video. It pages comments in as you
  scroll (InnerTube `/next`, `YourTubeCommentsJob`), with round avatars, author and time, likes, reply counts and
  a Pinned marker. Emoji, channel emoji shortcodes and blank lines are dropped. Back or Left closes it.

### App-drawn dialogs
- Message dialogs (exit, errors, notices) are drawn by the app (`YourTubeDialog` on `YourTubeDialogHost`) with a
  neutral black dim; Roku's own dialog dims in purple with no setting to change it. Same fields as before for
  callers. Timed dialogs (the playback-error "Play next video (10)" countdown) use it too. Keyboard,
  Invidious sign-in and on-screen-code dialogs still use Roku's.

### Loading skeletons
- Placeholder cards take their row's size (the big first shelf is 480 × 270), so nothing jumps when the
  thumbnails arrive.
- Restyled like YouTube's: dark rounded thumbnail block with two title bars and a channel bar, and a soft pulse
  that ripples across the row (was a flat light-gray box).

### Related videos
- Down from the scrubber opens a "Related" row over the bottom of the player (YouTube's /next recommendations, up to
  12 cards). OK plays a card through the queue; Up or Back closes it and hands focus back to the player.
- Panels over the player now let go of focus before closing, so the next OK reaches the player instead of the
  hidden list (affected the comments panel too).

### Tests and polish
- The Rooibos suites run green on the TV (748 lib, 20 app). The player test double mirrors the new YourTube nodes.
- Bookmarks uses the app's empty state when there are no bookmarks.
- Search Filters panel uses the `#212121` dialog surface so it stands off the page.
- `capture-all.sh` covers the channel page and the Filters dialog.
- Sign-in service picker: `#212121` surface and a filled card highlight behind the logo instead of a square frame.

### Account actions (Phase 2, verified on the TV with a signed-in YouTube account)
- Like, Dislike and Save (Watch Later) buttons in the player row; icons fill in when active. They call InnerTube
  (`like/like`, `like/dislike`, `like/removelike`, `browse/edit_playlist` on `WL`) with the YouTube profile's token,
  flip right away, and flip back with a message if the request fails.
- Signed out or on an Invidious profile, they show "Sign in with a YouTube account from Profile...".
- `YourTubeToast`: a short message pill at the top of the player.
- Verified 2026-10-24 on a real account: like, remove like, dislike, remove dislike, save, remove from Watch Later,
  subscribe and unsubscribe all succeed, and reopening a video loads the liked, disliked, saved and subscribed
  states from YouTube. Each change was undone after the test.
- Subscribe button in the player too (`subscription/subscribe` / `unsubscribe` for the video's channel).
- When a video opens on a YouTube profile, the like, dislike and subscribe buttons load your real state from `/next`
  (`YourTubeVideoStateJob`; parser tested against the saved `/next` sample). Save checks the first page of your Watch Later
  playlist (`browse` `VLWL`, the newest saves).
- The player title is 700 wide so long titles wrap before the action row instead of running under it.

### Live chat (Phase 4)
- On live videos the comments button becomes Chat and toggles an overlay at the top right. It never takes focus,
  so the remote keeps controlling playback. It polls `live_chat/get_live_chat` on the server's interval, keeps the
  newest 30 messages, colors owner, moderator and member names, and tints Super Chats. Chat stops when hidden,
  on the next video and when the player closes.
- Emoji between two words now leave a space ("STREAM BILLIONS", not "STREAMBILLIONS").

### Best quality (Phase 5): tested, not possible on this TV
- VP9 4K/HDR through DASH was tried four ways on the TV; Roku's DASH demuxer won't read YouTube's WebM streams and
  the TV has no AV1, so playback stays AVC up to 1080p60. Write-up in docs/device-capabilities.md.
- `GET /api/yourtube/last-dash` returns the last generated DASH manifest (release builds have no /debug routes).

### Interaction pass (every focus state screenshotted on the TV)
- Google Material Symbols (Rounded) for every icon; consistent nav states (focused: dark on white pill,
  current: white filled, others: gray outline).
- Search: padded input pill, 5 de-duplicated suggestions, symbol keyboard page.
- Empty states with messaging for Subscriptions and You; Home loads its first shelf large on first open.
- Player: scrub preview strip clears the bar and the title hides while scrubbing.
- Settings rows no longer shift sideways after focus; context menu uses the inset pill focus and drops
  emoji from titles; dialogs use a gray divider.
- Live tab (replaces Stream Caster): favorites and recent links, phone page via QR, `u=` launch and input params.

### Removed
- The Phase 0 `CodecProbe` (results are in docs/device-capabilities.md).

## Phase 0 setup, Phase 1 restyle

### Build and privacy
- Release builds load only the library bundled in the zip; no Playlet builds from GitHub, no saved library URLs.
- `tools/yourtube-build.sh` builds one unsigned sideload zip; no device password involved.
- Diagnostics (Sentry) off by default; no "latest version" checks against Playlet's GitHub.
- `.gitignore` covers env files, packages, tokens and cookies.

### Branding
- Original play-button mark in a coral-to-magenta gradient, Roboto Bold wordmark, poster and splash
  (`branding/`, rendered by `tools/yourtube/make-assets.sh`).
- User-visible "Playlet" renamed to "YourTube" at build time (translations untouched in source).
- YouTube logo asset replaced with a neutral account icon.
- Roboto (OFL) bundled; all UI text uses it.
- Info screen credits Playlet and links both repositories (AGPL-3.0).

### UI (see docs/UI-SPEC.md)
- App-wide YouTube TV palette, Roboto, white focus ring, pill buttons (build plugin).
- New video card, Home top bar, nav rail colors, search screen and keyboard, player overlay, dialogs,
  settings categories, context menu.

### Since the first restyle pass
- Telemetry hard-disabled and its settings switch hidden (TV and phone remote).
- Home: large first shelf (480×270); 4K/CC/HDR chips on cards; Subscriptions and You nav sections.
- Comments and live chat parsers with real InnerTube fixtures and Rooibos specs (not yet wired to UI).
- `tools/smoke.sh` (ECP + console), `docs/PLAN.md`, `tools/yourtube/capture-fixtures.mjs`.
- Reference photos of the official app kept out of git (Google's images).
