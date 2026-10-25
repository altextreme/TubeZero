# TubeZero feature ideas (2026-10-24)

**Status (2026-10-24):** built on `feat/rebrand-ui`, and described in docs/CHANGELOG-YOURTUBE.md:
- From the top 10: CC and Settings buttons (1), chapters and the Description panel (2), Up next (3), save to any
  playlist (4), like and dislike counts (5), most-replayed heatmap (9), Not interested / Don't recommend (10).
- From the longer list: quick 10-second skip, Watch later and Liked rows, Watch later edits, search watch history and
  pause watch history, notifications inbox (hidden with a TV sign-in, see the changelog), channel page and search
  inside a channel, Home chips, Subscriptions filter chips, Live now from subscriptions, search filter chips, Shorts
  like/comments/subscribe and the subscriptions-only feed, live DVR "Go live", voice search hint and auto-search,
  phone pairing, blocklist, watch-time stats, SponsorBlock extras, Kids profile, sentence-case titles, Back to top,
  and the comments panel backdrop.
- Not built: DeArrow (6), "Who's watching?" (7), the phone companion panel (8) and the rest of the longer list.

What I looked at: docs/CHANGELOG-YOURTUBE.md, docs/PLAN.md, docs/UI-SPEC.md, README.md,
`playlet-lib/src/config/preferences.json5`, `components/YourTube/*`, `components/Services/Innertube/*`,
`VideoPlayerDev/*`, `VideoQueue/*`, `Web/PlayletWebServer/*`. YouTube feature claims are cited as [n] (sources at the end).

What the code already has that the ideas below build on (and what it lacks):
- **Captions:** `VideoContentJob.SetCaptions` already turns `captionTracks` from `/player` into Roku `SubtitleTracks`.
  The player has no CC button (it runs with `enableUI=false`), so captions follow whatever Roku's caption setting is.
- **Playback speed:** `VideoPlayerDev` has a `playbackSpeed` field that only the phone (Lounge) sets. There is no
  control for it on the TV.
- **Chapters on the scrubber:** `TrickPlayBar` has a `chapterLabel`, but only SponsorBlock fills it. Nothing parses
  YouTube's own chapters.
- **Data parsed but unused:** `PlayerEndpoint` reads `storyboards` (used for the scrub preview), `audioTrack`,
  `isDrc` and `xtags`. `NextEndpoint` touches `playerOverlays` and `endscreen`.
- **Queue and autoplay:** `VideoQueue` exists with a "Queue video" item in the context menu, and there is a
  `playback.autoplay` preference. `VideoQueue.bs:367` still has a TODO: "hasNext currently does not account for autoplay".
- **Watch history:** resume works (`timestamp` / `percentDurationWatched`), and `MarkVideoWatchedJob` reports watch
  time to YouTube.
- **Phone server:** routes for state, queue, preferences, bookmarks, home layout and DIAL/Lounge already exist.
- **Not present at all:** DeArrow, Return YouTube Dislike, heatmap (most replayed), sleep timer, a save-to-playlist
  dialog (only Watch Later), and the "Not interested" action.

---

## 1. Top 10 (ranked by user value x feasibility)

### 1. Player "Captions" and "Settings" buttons (CC, speed, quality, audio track)
- **What:** Add a CC button and a gear button to the action row. CC opens a list of the video's caption tracks plus
  Off. The gear opens a sheet with Speed (0.25x to 2x), Quality, Audio track (dubbed or original language, audio
  description) and Sleep timer.
- **Why on a TV:** The current YouTube TV layout puts likes, comments, captions and settings together in the right
  cluster under the scrubber [2][3]. Today TubeZero can only change speed from the phone, and the CC state is
  invisible.
- **How:**
  - Follow the 4-step recipe in `ButtonRow`: add the buttons to the xml and `m.buttons`, add the enum entry in
    `PlayerCoordinatorLogic`, and handle them in ActivateButton.
  - Draw the sheet on `YourTubeDialog` / `YourTubeDialogHost`.
  - **CC:** switch tracks by setting `subtitleTrack` on the Video node (the tracks are already built in
    `SetCaptions`). Remember the last language in a new `playback.captions_language` preference.
  - **Speed:** set the existing `playbackSpeed`, and tell the phone with `Lounge.SendNowPlaying*`.
  - **Quality:** reuse `Screens/SettingsScreen/QualitySelector`.
  - **Audio track:** use the `audioTrack` data `PlayerEndpoint` already parses, and rebuild the DASH manifest with
    the chosen group in `Services/Dash/DashManifest.bs`. The `playback.disable_auto_dubbed` preference already covers
    part of this.
- **Effort:** M (S for CC and speed alone).
- **Risks:**
  - With `enableUI=false` the OS may still apply its own caption mode. Test `globalCaptionMode` and `subtitleTrack`
    together on the TV.
  - Changing the audio track means reloading the manifest, which causes a short rebuffer.

### 2. YouTube chapters plus a "Description" side panel
- **What:**
  - Chapter ticks on the scrubber, and the chapter title above the scrub preview.
  - A Description panel showing channel, views, date, the full description text and a chapter list. OK on a chapter
    seeks to it.
- **Why on a TV:** YouTube TV moved the description to a dedicated button with a side panel that includes chapters
  [2][3]. The Q1 2026 update added chapter navigation inside that panel [4]. Seeking with arrows through a 40-minute
  video is the worst part of TV viewing.
- **How:**
  - Parse chapters from `/next`, in `playerOverlays...decoratedPlayerBarRenderer...markersMap` or the
    `macroMarkersListRenderer` engagement panel. Parse the description from the
    `videoSecondaryInfoRenderer` / `structuredDescription` engagement panel.
  - Add a pure parser with a saved `/next` fixture, in the same pattern as `CommentsParser`.
  - Show the chapter label through the existing `TrickPlayBar.chapterText`. SponsorBlock takes priority while the
    cursor is inside a segment.
  - Build the panel from the `CommentsPanel` shell and open it with a new action-row button.
- **Effort:** M.
- **Risks:**
  - Different clients nest chapters in different places. The parser has to be defensive.
  - Long descriptions need a scrollable label inside a fixed height.

### 3. Up Next card and autoplay countdown
- **What:** About 10 seconds before the end, show a corner card ("Up next in 8", thumbnail and title) with Play now
  and Cancel. In playlists and the queue, autoplay follows the list.
- **Why on a TV:** The Q1 2026 update added Up Next teasers at the end of videos [4]. A lean-back viewer expects the
  next video to start without pressing anything.
- **How:**
  - Take the next video from `/next`. Use the autoplay set (`autoplay.autoplay.sets[0]`), or the first related item
    that `RelatedShelf` already fetches.
  - Fix the `hasNext` TODO in `VideoQueue.bs:367` and gate it with `playback.autoplay`.
  - Reuse the countdown that `YourTubeDialog` already has (the "Play next video (10)" error countdown).
- **Effort:** S–M.
- **Risks:** It must not fire inside an active SponsorBlock outro skip, and it must not fire on live streams.

### 4. Save to any playlist and create a playlist
- **What:** Save opens a list of your playlists with checkmarks, plus "New playlist". Long-press or the context menu
  on any card offers "Save to playlist".
- **Why on a TV:** Watch Later is the only place you can save to today. Building a playlist for the evening is a
  common couch task.
- **How:**
  - Read the list with `playlist/get_add_to_playlist`. Add and remove with `browse/edit_playlist` (already used for
    `WL`). Create with `playlist/create`.
  - Draw it on `YourTubeDialog`. Add the item to `ContextMenuUtils`, next to "Queue video".
  - Planned in PLAN.md Phase 2 but not built.
- **Effort:** S–M.
- **Risks:**
  - Naming a new playlist needs Roku's keyboard dialog.
  - Only works on YouTube (OAuth) profiles. Show the existing sign-in message otherwise.

### 5. Like and dislike counts (Return YouTube Dislike)
- **What:** Show counts next to the Like and Dislike icons in the action row and in the Description panel (for
  example "12K" and "1.1K"), plus an optional ratio bar.
- **Why on a TV:** YouTube added like counts to the TV watch page in 2026 [4], but it still hides dislikes. A
  personal client can show both.
- **How:**
  - Like counts: from `/next` `likeButtonViewModel`. Parse them in `YourTubeVideoStateJob`.
  - Dislikes: `GET https://returnyoutubedislikeapi.com/votes?videoId=…` returns likes, dislikes, rating and views
    [5]. Fetch it in a JobSystem job when a video opens.
  - Add a `ryd.enabled` preference, and credit RYD on the About screen as their terms require [5].
- **Effort:** S.
- **Risks:**
  - The dislike numbers are estimates extrapolated from RYD users [5].
  - Rate limits are 100 per minute and 10,000 per day [5], which is fine for one TV.
  - It is a new third-party host that sees which video IDs you open, so it should be opt-in.

### 6. DeArrow (crowd-sourced titles and thumbnails)
- **What:** Replace clickbait titles, and optionally thumbnails, on every card and in the player. A toggle "Show
  original" sits in the context menu.
- **Why on a TV:** You read titles from three meters away. ALL-CAPS bait is worse on a 55" screen. It is the same
  family of tool as the SponsorBlock you already run.
- **How:**
  - `GET sponsor.ajay.app/api/branding?videoID=…` returns `titles[]` and `thumbnails[]`. Only use the first entry
    if it is locked or its votes are 0 or more [6]. Use the hash-prefix variant for privacy if it is available.
  - Thumbnails are timestamps, not images [6][7], so they have to be rendered. Options: DeArrow's thumbnail cache
    service, or the nearest storyboard frame from `storyboards`, which the scrub preview already uses (a lower
    resolution fallback).
  - Start with titles only (S): batch the visible row's IDs from a `VideoRowList` job and cache them in `tmp:`.
  - Reuse the `Services/SponsorBlock` patterns.
- **Effort:** S for titles, M with thumbnails.
- **Risks:**
  - An extra request for each row.
  - Thumbnail rendering quality.
  - The text must fit the existing two-line title layout.

### 7. "Who's watching?" profile picker at launch, plus a profile lock
- **What:**
  - On launch with more than one profile, show a full-screen picker (big avatars and "Add account").
  - Optional 4-digit PIN for each profile.
  - Optional local "kid" profile (see section 2).
- **Why on a TV:** It is a shared screen. The official app shows "Who's watching?" at startup [8][9], added Google
  Family Group profiles in 2026 [4][9], and is rolling out a profile lock you can unlock from your phone [9][10].
- **How:**
  - `ProfilesService` already holds several Invidious and YouTube profiles.
  - Add a launch route in `AppController` to a new `YourTubeWhoIsWatching` screen, styled like the restyled Profile
    "Accounts" page.
  - Store the PIN hash in the registry.
  - The phone page could unlock the profile over the existing web server.
- **Effort:** S–M.
- **Risks:**
  - It slows launch for single-profile homes. Show it only when there are two or more profiles.
  - The PIN is a local barrier only, as YouTube says of its own lock [10].

### 8. Phone companion panel (playlet-web "Now playing")
- **What:** On the phone remote page, show a Now playing card with:
  - Like, Dislike, Save and Subscribe buttons
  - the description and chapters
  - comments to read
  - speed and captions
  - the queue, which you can reorder and remove from
  - "Send current video to my phone" (copy the link)
- **Why on a TV:** YouTube's 2026 companion mode does this on the phone [11]. Its remote commenting depends on the
  same account being signed in on both devices [12]. The phone is a better place than the TV for reading and typing.
- **How:**
  - Add a `StateApiRouter` / `VideoQueueRouter` endpoint that returns the current video's `/next` state (already
    parsed by `YourTubeVideoStateJob` and `CommentsParser`), plus POST routes that call `YourTubeAccountActionJob`.
  - Add a new Svelte screen in `playlet-web/src/lib/Screens`.
  - Works over the existing LAN server, with no Google relay.
- **Effort:** M.
- **Risks:**
  - The LAN server has no authentication. Anyone on the Wi-Fi could like or subscribe as you. Add a pairing code or
    token.
  - The phone UI has to keep up with the TV state (poll it, or push over the existing websocket if there is one).

### 9. Most-replayed heatmap and "Jump ahead"
- **What:** A faint heat curve above the scrubber. While scrubbing, Right snaps to the next peak, and an optional OK
  shortcut jumps to the most replayed part.
- **Why on a TV:** YouTube offers "Jump ahead" on TV through the Right button, but only for Premium [13]. The heatmap
  data is public, so TubeZero can offer it for free.
- **How:**
  - Parse the heatmap from `/next` `frameworkUpdates.entityBatchUpdate…macroMarkersListEntity` (markerType HEATMAP).
    It is in the same parser as the chapters in item 2.
  - Draw it in `TrickPlayBar` as about 100 small rectangles, or one pre-rendered bitmap.
  - Add the snap logic in `TransportController`.
- **Effort:** M.
- **Risks:**
  - The TV client's `/next` may not include heatmap entities. A WEB-context `/next` may be needed, and
    `CreateContextClientWeb` exists for that.
  - Not every video has a heatmap.

### 10. "Not interested" and "Don't recommend channel"
- **What:** Context-menu items on Home and Related cards. The card disappears with an Undo toast.
- **Why on a TV:** It is the only way to steer recommendations from the couch. Today a bad recommendation stays put.
- **How:**
  - The browse renderers' `menu` already carries `feedbackEndpoint.feedbackToken`. Keep it in `NodesParser` on the
    content node.
  - Post it to `feedback` with the profile's token through `YourTubeAccountActionJob`.
  - Show Undo with `YourTubeToast`, using the undo token in the response.
  - Also add "Remove from Watch history" on the You > History row.
- **Effort:** S–M.
- **Risks:**
  - The tokens expire, so they only work in the session the card came from.
  - The menu format differs between TV-client and WEB-client renderers.

---

## 2. Longer list

### Playback & player
- Sleep timer (15, 30, 60 minutes, end of video, end of playlist) with a fade and an "Are you still watching?"
  prompt. YouTube tested one for Premium [14]. **S**
- Remember speed for each channel (podcasts at 1.5x, music at 1x). **S**
- Skip ±10 seconds on a quick Left/Right press while the overlay is hidden, as the official app does. Check against
  the current transport. **S**
- Previous and Next buttons in the center cluster when a queue or playlist is active [3]. **S**
- "Mark as watched" and "Start over" in the context menu (resume already exists). **S**
- Scrub preview with storyboard frames at chapter boundaries. **S**
- Loop video, and shuffle for playlists, inside `VideoQueue`. **S**
- Chat replay for past live streams (`live_chat/get_live_chat_replay`, reusing `LiveChatPanel`). **M**
- Prefetch the next video's `/player` and decipher call during the Up Next countdown for instant start. **M**
- Info overlay: resolution, codec, buffer and dropped frames (like "Stats for nerds"). **S**

### Discovery & Home
- Channel page restyle: banner, tabs (Videos, Shorts, Live, Playlists, Posts), Subscribe, and a "Play all" button
  that queues uploads. **M**
- Home chips row ("All", "Music", "Gaming", "New to you") using the chip continuations in browse `FEwhat_to_watch`. **M**
- A Subscriptions grid filter: Today, Unwatched, Live now, Videos only or Shorts only. **S**
- "Live now from your subscriptions" row at the top of Home and Subscriptions. **S**
- Hide watched videos (above X%) in Home and Subscriptions. **S**
- Explore pages for trending and music charts (`GetTrending` exists). **S**
- Stations-style "Radio" or Mix from any video or channel (`GetMix` exists) [4]. **S**

### Library & account
- Library page (YouTube's "You" page): Watch Later, Liked videos (`VLLL`), your playlists, and saved playlists, each
  as a row. **S**
- Edit Watch Later: remove items and move them to the top. **S**
- History search and "Pause watch history" (skip `AuthMarkVideoWatched`). **S**
- Notifications inbox (`notification/get_notification_menu`), polled when the app opens, with a bell badge on the
  Profile icon. Roku can't run in the background. **M**
- A "Recently played on this TV" row, local, that works on any profile including Invidious. **S**

### Shorts
- Like, Dislike and Comments on Shorts (same endpoints; the panel docks to the right of the 9:16 frame). **S**
- Right opens the creator and sound info, as the official TV Shorts player does [15]. OK on the channel opens it. **S**
- Pause or loop control, plus a muted autoplay preview when a Short card is focused. **S–M**
- A "Shorts from subscriptions only" feed toggle. **S**

### Live
- DVR rewind on live streams, using `PostLiveDvrInfo` / `GetLiveTimeline` (already in Innertube), with a "Go live"
  button. **M** *Round 2: the rewind already existed; the "Go live" pill (OK on the bar while behind) is added.*
- Upcoming streams and premieres with "Notify me" (`notification/add_upcoming_event_reminder`) and a countdown. **S–M**
- Chat position and opacity settings, and a Super Chat ticker. **S**
- Live tab: pull a channel's live URL automatically, and add M3U playlist import for favorites. **S–M**

### Search
- Voice search: test the remote mic in Search on the TV, and show a listening state. YouTube now pushes AI voice
  search on TVs [1][4]. **S**
- Search inside a channel (browse with the channel `params` search). **S**
- Persistent filter chips under the results (Upload date, Type, Duration; `SearchFilters.bs` already encodes them). **S**
- Type a search on the phone that appears on the TV (playlet-web route into `SearchScreen`). **S**
- Sync search history with the account (read and clear from Google), with the local history kept as an option. **M**

### Comments / community
- Sort comments by Top or Newest (the sort menu continuation tokens are in the comments header). **S**
- Expand reply threads inline. **S–M**
- Like a comment (`comment/perform_comment_action`). **S**
- Post a comment or reply with Roku voice or keyboard, or from the phone companion. YouTube is adding remote
  commenting [12]. **M**
- Creator posts (the channel "Posts" tab) read on the TV, with images. YouTube announced Posts for TVs [12]. **M**

### Phone companion & casting
- Pairing PIN or token for the phone web server before account actions (see the risk on item 8). **S**
- Phone queue editor: drag to reorder, play next, clear. **S–M**
- Share the current video to the phone with a QR code on the TV ("Open on phone" at the current timestamp). **S**
- Cast from the YouTube phone app with queue support: check that `addVideo` / `setPlaylist` Lounge messages
  append rather than replace. **S**
- "Play on different device" works over the internet in the official apps [1][11]. TubeZero stays LAN-only by design. Note it in the docs.

### Accessibility
- In-app caption style (size, background, color) with a preview, where the Roku Video node allows it. Otherwise
  link to the Roku caption settings. **S–M**
- Auto-translated captions: add `&tlang=xx` to the timedtext URL for a "Translate to English" track. **S**
- Audio description and original-audio track choice (see item 1). **M**
- Large-text mode, scaling titles and metadata by 1.25x through `YourTubeTheme`. **M**
- Screen reader: check `AudioGuide` on custom cards and panels, and add `accessibilityName`-style labels where Roku
  supports them. **M**

### Personal / ad-free extras
- Return YouTube Dislike (item 5), DeArrow (item 6), heatmap (item 9).
- SponsorBlock extras:
  - "Highlight" (`poi_highlight`): a "Jump to highlight" prompt at the start.
  - "Filler" category.
  - Per-category skip / ask / show-only modes.
  - A skip-count statistic. **S each**
- Channel and keyword blocklist that hides matching cards everywhere (local, in `content_feed.*` preferences). **S**
- Watch-time stats: minutes per day and week, top channels, total SponsorBlock time saved. Local registry, shown in
  You. **S–M**
- Kid profile: a local profile limited to an allowlist of channels and playlists, with no search, a time limit and a
  PIN to leave. Built on the TubeZero side, not on YouTube Kids. **M**
- Clickbait cleanup without DeArrow: convert ALL-CAPS titles to sentence case. **S**
- Hide members-only, upcoming or Mix cards (toggles in the Content Feed category). **S**
- Self-hosted decipher server (PLAN.md option B) so no third party sees what you watch. **L**

### Polish & performance
- Remember focus per screen and row, and jump to the top of Home with Back on Home. **S**
- Cache Home for instant start and refresh it in the background (show the cached rows first). **S–M**
- Ambient backdrop: a blurred, darkened thumbnail behind the Description and Comments panels and the pause screen
  (a cheap stand-in for ambient mode). **S**
- Fallback when the Playlet support server is down: a clear error and a retry, plus a status line in Settings. **S**
- Thumbnail sizes matched to card size (`mqdefault` for grids) to cut memory on a 2020 TV. **S**
- Clean up old `.claude/worktrees` build copies, and add an image and texture memory budget check to `smoke.sh`. **S**

---

## 3. Avoid, or not possible

| Idea | Reason |
| --- | --- |
| 4K, HDR, VP9 or AV1 playback | Tested four ways. Roku's DASH demuxer won't read YouTube's WebM, and this TV has no AV1. AVC tops out at 1080p60 (docs/device-capabilities.md). |
| "AI upscaling to 4K" like YouTube's TV feature [4] | It is done on YouTube's servers for their own streams. TubeZero only gets the same AVC renditions. |
| Stable volume / loudness normalization | The Roku Video node has no app-side gain control. `loudnessDb` is in `/player` but can't be applied. |
| True ambient mode (glow from video colors) | Roku SceneGraph can't sample decoded video frames. Use the thumbnail backdrop instead. |
| Multiview, or a second video playing at once | Roku apps get one active video decoder. The Shorts card preview has to stop the main player first. |
| Background play, or PiP over other Roku apps | Roku suspends channels that are not in front. No background jobs, so notifications can only be polled at launch. |
| Downloads and offline viewing | No usable persistent storage on the TV (`tmp:` is cleared, and the registry is about 16 KB). |
| Conversational "Ask" AI about the video [1][4] | Needs Google's Gemini backend tied to Premium and experiments. It could be added with your own LLM key, but that is off-mission and sends transcripts to a third party. |
| Shopping overlays and QR product links [1][4] | Ads by another name. Strip them. |
| Gifting, Super Chat or memberships purchase on TV | Payment flows. Out of scope for a personal ad-free client, and risky. |
| YouTube Kids content via a Kids client | Undocumented client and auth. Brittle. The local kid profile covers the need. |
| Premium-only server features (Jump ahead's AI picks, enhanced 1080p bitrate) [13] | Gated by the account's entitlements on YouTube's side. The heatmap version (item 9) is the free equivalent. |
| Internet-wide "Play on different device" [1][11] | Requires Google's cloud cast relay and a registered device. TubeZero stays on the LAN (DIAL and Lounge pairing already work). |
| Running YouTube's player JS on the TV to drop the decipher server | Roku has no JavaScript engine. A server (Playlet's, or self-hosted) is required. |

---

## Sources
1. ppc.land, "YouTube's Q1 2026 TV update brings AI search and family controls to smart TVs" (May 14, 2026). Also
   TechCrunch (2026-04-08) and storyboard18 on TV AI and the companion feature:
   https://ppc.land/youtubes-q1-2026-tv-update-brings-ai-search-and-family-controls-to-smart-tvs/ ,
   https://techcrunch.com/2026/04/08/as-youtube-grows-on-tv-it-eyes-more-interactive-video-across-formats ,
   https://storyboard18.com/digital/youtube-expands-conversational-ai-tool-to-tvs-as-living-room-battle-intensifies-90186.htm
2. Android Central, "YouTube details its 'dual column' TV redesign":
   https://www.androidcentral.com/apps-software/youtube-dual-column-tv-redesign-detailed ; 9to5Google:
   https://9to5google.com/2024/03/13/youtube-player-redesign-tv/
3. TechRadar, "YouTube finally gets the TV update we've been waiting for – and there are 5 handy upgrades" (control
   clusters: channel, description, subscribe / prev, pause, next / likes, comments, captions, settings):
   https://www.techradar.com/televisions/youtube-finally-gets-the-tv-update-weve-been-waiting-for-and-there-are-5-handy-upgrades ;
   Digital Citizen: https://www.digitalcitizen.life/youtube-tv-app-gets-major-redesign/
4. ppc.land Q1 2026 recap (chapter panel in description, like counts on the Watch page, Up Next teasers, Family
   groups on "Who's watching", Stations, 4K AI upscaling, QR shopping): same URL as [1].
5. Return YouTube Dislike API (`/votes?videoId=`, rate limits 100/min and 10k/day, attribution, estimated data):
   https://github.com/rubycoder/return-youtube-dislike , https://pypi.org/project/ryd-client/0.0.3
6. DeArrow API docs (`/api/branding`, titles/thumbnails, locked or votes ≥ 0 rule, random-time fallback):
   https://wiki.sponsor.ajay.app/w/API_Docs/DeArrow
7. DeArrow, "How it works" (thumbnails are timestamps rendered by a caching service): https://dearrow.ajay.app/about
8. 9to5Google, "YouTube for Android TV now shows account switcher at startup" (2025-10-28):
   https://9to5google.com/2025/10/28/youtube-for-android-tv-now-shows-account-switcher-at-startup/ and the 2024
   report: https://9to5google.com/2024/10/09/youtube-for-android-tv-gets-whos-watching-account-switcher-launch-screen/
9. YouTube Help, signing in on TV and profiles: https://support.google.com/youtube/answer/3015415?hl=en
10. Android Authority, YouTube account lock rolling out on smart TVs (Sept 2026):
    https://androidauthority.com/youtube-account-lock-smart-tv-rollout-3710248
11. Android Authority, YouTube TV companion mode (2026-09-02): https://www.androidauthority.com/youtube-tv-companion-mode-3706108/
12. TheWrap, Made on YouTube 2026 (creator Posts on TV, commenting with the remote via companion mode, 2026-09-23):
    https://www.thewrap.com/industry-news/tech/made-on-youtube-updates-2026/
13. Jump ahead on TV (Premium, Right on the remote, dot on the progress bar):
    https://theoutpost.ai/news-story/you-tube-s-ai-powered-jump-ahead-feature-expands-to-tv-platforms-18413/ ,
    https://www.fonearena.com/blog/427499/youtube-premium-jump-ahead-button-pip-for-shorts.html/amp
14. TechCrunch on YouTube's Premium sleep-timer test: https://techcrunch.com/?p=2834220
15. Android Central, "New YouTube Shorts player comes to your TV" (Up/Down to navigate, Right for creator and sound
    info): https://www.androidcentral.com/apps-software/new-youtube-shorts-player-tv

Notes on confidence:
- The exact InnerTube paths for chapters and the heatmap (`markersMap`, `macroMarkersListEntity`) are from memory of
  the web client's `/next` response. Confirm them against a fresh capture with `tools/yourtube/capture-fixtures.mjs`
  before writing parsers, because the TV client may omit the heatmap.
- The DeArrow wiki blocked automated fetching. Details come from search snippets of that page.
