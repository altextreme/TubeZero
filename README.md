<p align="center">
  <img src="branding/tubezero-mark.svg" alt="TubeZero mark" width="140"/>
</p>

# TubeZero

A personal, ad-free YouTube client for Roku TVs, styled after the YouTube TV app. TubeZero is a fork of
[Playlet](https://github.com/iBicha/playlet) by Brahim Hadriche and is licensed under the same
[AGPL-3.0](LICENSE). It is not affiliated with YouTube or Google, and it uses none of their logos or brand assets.

Upstream Playlet's README is kept at [docs/PLAYLET-README.md](docs/PLAYLET-README.md).

## What's different from Playlet

- A YouTube TV look: near-black surfaces, Roboto, white focus pills, Google Material Symbols, 16:9 cards with
  a large first shelf, a left nav rail, and a player overlay with an action row above the scrubber.
- Nav: Profile, Search, Home, Shorts, Subscriptions, You, Live, Settings.
- Home: one row per shelf YouTube returns plus category rows, "Live now from your subscriptions", and a chip row
  (All, Live, Music, Gaming...). Back below the first row jumps to the top.
- Shorts: a 9:16 player with Up/Down between Shorts, Like/Dislike/Comments/Subscribe beside it, and a
  "From subscriptions" feed.
- Subscriptions: your channels in a row, then a video grid with filter chips (Today, Unwatched, Live now...).
- You: watch history (searchable), Watch later, Liked videos, playlists and bookmarks.
- Player: CC and settings (captions, speed, quality, audio track), chapters and a most-replayed heatmap on the
  scrubber, a Description panel, like/dislike counts (Return YouTube Dislike), comments and live chat, an Up next
  card, quick 10-second skip, and "Go live" on live streams with DVR.
- Library and account: save to any playlist, Not interested / Don't recommend channel with Undo, Watch later edits,
  pause watch history.
- Channel pages styled like the TV app, with tab chips, Play all and search inside the channel. Search has filter
  chips and voice input.
- SponsorBlock with per-category Skip / Ask / Show / Off and a "Jump to highlight" prompt; a channel and keyword
  blocklist; ALL-CAPS titles in sentence case; local watch-time stats (Settings > More > Your stats).
- A Kids profile: only the channels and playlists you allow, a daily limit, and a PIN to leave.
- A Live tab, replacing Stream Caster. It plays any HLS, DASH or MP4 link sent from your phone (QR code) or over ECP
  (`launch/dev?u=...`) and keeps favorites and recent links.
- The phone web remote must pair with a code shown on the TV before it can play, change settings or switch profiles.
- Telemetry is off and hidden. No update checks against Playlet's GitHub, and the app loads only the library bundled
  in its own zip.

The full list is in [docs/CHANGELOG-YOURTUBE.md](docs/CHANGELOG-YOURTUBE.md). The roadmap and status are in
[docs/PLAN.md](docs/PLAN.md), and the visual spec is in [docs/UI-SPEC.md](docs/UI-SPEC.md).

## Build and install (sideload)

Requirements: Node 22, ImageMagick (only to regenerate assets), and a Roku in
[developer mode](https://developer.roku.com/docs/developer-program/getting-started/developer-setup.md).

```bash
npm install
```

```bash
tools/yourtube-build.sh
```

That writes `out/TubeZero-<version>-<commit>.zip`. Upload it from the Roku's developer page
(`http://<roku-ip>`), or let the installer do it. The installer reads `ROKU_DEV_TARGET` and the developer
password from a git-ignored `.env`:

```bash
node tools/yourtube/install-zip.js
```

To screenshot every interactive state on the TV over ECP (output in `out/screens/all/`):

```bash
tools/yourtube/capture-all.sh
```

## Staying mergeable with upstream

Most of the restyle happens at build time in `tools/bs-plugins/yourtube-rebrand-plugin.ts` (palette, fonts, focus
images, widget defaults). New features live in `playlet-lib/src/components/YourTube/`. Upstream files that do change
carry a `' YourTube:` or `' TubeZero:` comment (`<!-- YourTube: -->` in XML) at each edit; YourTube was the
project's name before the rebrand.

The build also runs `tools/yourtube/check-shadowed-names.js`. BrighterScript compiles a local or parameter that
shares a name with a function in the same namespace (say `today` next to `Today()`) into a reference to that
function, which only fails at runtime; the check fails the build instead.

Running the device test suite (`npm run test:run` in `playlet-lib`) wipes the app's registry, which signs you out.

## Credits

- [Playlet](https://github.com/iBicha/playlet) by Brahim Hadriche and contributors (AGPL-3.0). Most of this app is
  their work.
- [Roboto](https://fonts.google.com/specimen/Roboto) (SIL Open Font License) and
  [Material Symbols](https://fonts.google.com/icons) (Apache 2.0) by Google.

The source for this build is at [github.com/altextreme/TubeZero](https://github.com/altextreme/TubeZero), as the
AGPL requires.
