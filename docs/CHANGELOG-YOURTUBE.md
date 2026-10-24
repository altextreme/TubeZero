# YourTube changelog

Changes on top of [Playlet](https://github.com/iBicha/playlet) (AGPL-3.0). Newest first.

## Unreleased: Phase 0 setup, Phase 1 restyle (in progress)

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

### Temporary
- `CodecProbe.bs` prints device codec/HDR support to the debug console at launch (Phase 0; to be removed).
