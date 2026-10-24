# YourTube changelog

Changes on top of [Playlet](https://github.com/iBicha/playlet) (AGPL-3.0). Newest first.

## Unreleased: Phase 3 comments, interaction pass

### Comments (Phase 3)
- Comments button in the player action row opens a side panel over the video. It pages comments in as you
  scroll (InnerTube `/next`, `YourTubeCommentsJob`), with round avatars, author and time, likes, reply counts and
  a Pinned marker. Emoji, channel emoji shortcodes and blank lines are dropped. Back or Left closes it.

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
