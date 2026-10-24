# YourTube plan

Fork of [Playlet](https://github.com/iBicha/playlet) (AGPL-3.0) for one TCL 55R635 (Roku OS 16.0.4, 1080p UI).
Personal use, never published. Upstream: `upstream` remote; our work on feature branches, merged to `main` after a TV check.

## Architecture (as it works today)

```
playlet-app  (sideloaded "dev" channel, tiny)
  Main.bs ─ roSGScreen, roInput (input launch / deep links), transport events
  BootstrapScene ─ loads the library via ComponentLibrary, then creates PlayletLib:MainScene
      YourTube: release builds load ONLY pkg:/lib/playlet-lib.zip (bundled), never GitHub/registry URLs
playlet-lib  (bundled zip inside the app; where everything happens)
  MainScene ─ AppController (screen stack), NavBar, AppScreens, VideoQueue, services
  Services/Innertube ─ YouTube API (browse, next, player, search, OAuth, subscribe), NodesParser
  Services/Dash ─ builds the DASH manifest the player plays (fMP4 only)
  VideoPlayerDev ─ the shipping player: custom chrome (TrickPlayBar, ButtonRow, BifDisplay...)
  JobSystem ─ task-thread jobs for parsing/network (keeps the render thread free)
  Web/PlayletWebServer ─ port 8888: phone remote (playlet-web), casting, DIAL/Lounge
playlet-web  (Svelte phone remote, served by the TV app)
```

Build: `tools/yourtube-build.sh` → `out/YourTube-<version>-<sha>.zip` (unsigned, no password).
Theme: `tools/bs-plugins/yourtube-rebrand-plugin.ts` restyles every screen at build time
(palette, Roboto, focus ring, pill buttons, "Playlet" → "YourTube"), so upstream files stay untouched.
Assets: `branding/*.svg` + `tools/yourtube/make-assets.sh`. Previews: `tools/yourtube/render-previews.py`.

## Decision needed: Playlet's support server

Every video play calls `playlet-v8556.ondigitalocean.app`:
- `GET /v1/sts` (signature timestamp, cached in `tmp:`),
- `POST /v2/decipher` (deciphers stream URLs, and mints a PoToken server-side).

Roku can't run YouTube's player JavaScript, so this can't move onto the TV. What it sends: the format URLs/ciphers
of the video being played and a PoToken identity (`LIVING_ROOM_PO_TOKEN_ID`, scraped from YouTube's TV page;
your OAuth tokens are not sent).
No YourTube branding or telemetry goes with it.

| Option | Pros | Cons |
| --- | --- | --- |
| A. Keep Playlet's server (today) | Zero work; Playlet keeps it working when YouTube changes | Playlet's server sees which videos you play; outage = no playback |
| B. Self-host on buzzbox | Private; under your control | Must reimplement `/v1/sts` + `/v2/decipher` (yt-dlp/ejs or youtubei.js + a PoToken minter) and keep it current when YouTube breaks things |

Recommendation: A for now, B as an optional later phase if privacy matters more than upkeep. Your call.

## Where each feature hooks in

| Phase | Feature | Hook point | New files (mergeable) |
| --- | --- | --- | --- |
| 1 | Restyle | Build plugin + `components/YourTube/*` | done, see `docs/UI-SPEC.md` |
| 2 | Like / dislike / remove | New `Innertube/LikeEndpoint` (`like/like`, `like/dislike`, `like/removelike`), state from `/next` | `components/YourTube/Actions/*` |
| 2 | Watch Later / save to playlist | `browse/edit_playlist`; playlist list from `playlist/get_add_to_playlist` | save dialog component |
| 2 | Subscribe | extend existing `SubscriptionEndpoint.bs` | player + channel buttons |
| 2 | Player buttons | `VideoPlayerDev/ButtonRow` (documented 4-step recipe: xml, m.buttons, enum, ActivateButton) | icons |
| 3 | Comments | `/next` engagement panel → continuation → `next` with continuation; `commentsEntryPointHeaderRenderer` is `ParseNotImplemented` in `NodesParser.bs` today | `components/YourTube/Comments/*`, parser + fixtures |
| 4 | Live chat | `liveChatRenderer` continuation from `/next` → `live_chat/get_live_chat` polling (server-given interval) | `components/YourTube/LiveChat/*`, Task node, 150-message ring buffer |
| 5 | Best quality | `Services/Dash/DashManifest.bs` (`HasPlayableVideoGroup`, AV1 gate) + player quality menu | `docs/quality-tests.md` |
| 6 | Live tab | app manifest already has `supports_input_launch=1`; `EcpArgs.bs` handles launch + `roInput` args → add `u`/`f`/`t` handling and a Live screen | `components/YourTube/Live/*`, nav item |

Parsing for 2–4 runs in Job/Task threads; parsers are pure functions over JSON with fixtures in `tests/fixtures/`.

## Risks

- **4K/HDR (Phase 5).** Playlet builds DASH from fragmented MP4 only; Roku's player won't select WebM sets. YouTube
  serves 4K/HDR as VP9 (WebM) or AV1 (MP4). The Phase 0 codec probe (since removed;
  results in docs/device-capabilities.md) found no AV1 on this TV, but VP9 profile 0 and 2 decode at 2160p60 when
  declared in an `mkv` container, and HDR10/HLG/Dolby Vision are supported. So the 4K/HDR route is VP9 WebM in
  DASH; AVC stops at 1080p60, and HEVC is moot because YouTube doesn't serve it.
- **YouTube changes.** InnerTube shapes change often. Defensive parsers (missing field → skip, never crash), saved
  fixtures, and pulling upstream Playlet fixes regularly.
- **Merge conflicts.** Mitigated by the build-time theme and new components. Files we do edit carry `' YourTube:`
  comments; the list is in `docs/CHANGELOG-YOURTUBE.md`.
- **Roku-drawn widgets.** The search keyboard, dialogs and system trick-play bitmaps are drawn by Roku OS; their
  exact look is only partly controllable (palette + layout JSON).
- **Performance on a 2020 TV.** Comments/chat lists must be bounded (≤ ~200 comment nodes, 150 chat messages),
  built off the render thread, and measured (frame drops via the debug console `fps` / timing logs).
- **Device verification.** Every build is installed with `tools/yourtube/install-zip.js` and checked with
  `tools/yourtube/capture-all.sh`, which screenshots every interactive state over ECP.

## Status (2026-10-24)

Done and verified on the TV: Phase 0, Phase 1 restyle, Phase 3 comments panel, Phase 4 live chat, Phase 6 Live tab.
Next: Phase 2 account actions (need a signed-in account to test), Phase 5 VP9 4K/HDR.

## Build order

1. Install current build; run `tools/smoke.sh`; read the codec probe; capture real screenshots; fix restyle issues.
2. Phase 2 account actions (smallest API surface, unlocks the player action row).
3. Phase 3 comments (parser + fixtures first, then the panel).
4. Phase 4 live chat (reuses the panel and Task patterns from comments).
5. Phase 5 quality, shaped by the probe results.
6. Phase 6 Live tab (independent; can move earlier if you want Stream Caster replaced sooner).
