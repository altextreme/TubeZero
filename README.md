<p align="center">
  <img src="branding/mark.svg" alt="YourTube mark" width="120"/>
</p>

# YourTube

A personal, ad-free YouTube client for Roku TVs, styled after the YouTube TV app. YourTube is a fork of
[Playlet](https://github.com/iBicha/playlet) by Brahim Hadriche and is licensed under the same
[AGPL-3.0](LICENSE). It is not affiliated with YouTube or Google, and it uses none of their logos or brand assets.

Upstream Playlet's README is kept at [docs/PLAYLET-README.md](docs/PLAYLET-README.md).

## What's different from Playlet

- A YouTube TV look: near-black surfaces, Roboto, white focus pills, Google Material Symbols, 16:9 cards with
  a large first shelf, a left nav rail, and a player overlay with an action row above the scrubber.
- Subscriptions and You sections, with empty states when there's nothing to show.
- A comments panel in the player (Comments button in the action row).
- A Live tab, replacing Stream Caster. It plays any HLS, DASH or MP4 link sent from your phone (QR code) or over ECP
  (`launch/dev?u=...`) and keeps favorites and recent links.
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

That writes `out/YourTube-<version>-<commit>.zip`. Upload it from the Roku's developer page
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
carry a `' YourTube:` (or `<!-- YourTube: -->`) comment at each edit.

## Credits

- [Playlet](https://github.com/iBicha/playlet) by Brahim Hadriche and contributors (AGPL-3.0). Most of this app is
  their work.
- [Roboto](https://fonts.google.com/specimen/Roboto) (SIL Open Font License) and
  [Material Symbols](https://fonts.google.com/icons) (Apache 2.0) by Google.

The source for this build is at [github.com/altextreme/YourTube](https://github.com/altextreme/YourTube), as the
AGPL requires.
