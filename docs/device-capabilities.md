# Device capabilities: 55" TCL Roku TV

Captured 2026-10-24 by `CodecProbe.bs` (YourTube build `58cdde7c`) on the TV's debug console (port 8085).
Raw log: `out/console-first-install.log` (not in git).

## Device

| | |
| --- | --- |
| Model | TCL A113X (`GetModel` = A000X), 55" LED |
| Roku OS | 16.0.4 build 842 |
| UI resolution | FHD 1920×1080 (graphics: OpenGL) |
| Video mode | **2160p60** (panel is 4K) |
| HDR | **HDR10 yes, HLG yes, Dolby Vision yes**, HDR10+ no, seamless HDR switching no |
| VRR / ALLM | no / no |
| `GetDisplayCapabilities()` | not available on this OS ("Member function not found") |

## Video decode (`CanDecodeVideo`)

| Codec / profile | 1080p | 2160p | Notes |
| --- | --- | --- | --- |
| H.264 / AVC High | yes (4.1, 4.2) | **no** (5.1, 5.2) | AVC tops out at level 4.2 = 1080p60 |
| HEVC Main | yes | **yes** (5.1) | YouTube doesn't serve HEVC |
| HEVC Main 10 | yes | **yes** (5.1) | YouTube doesn't serve HEVC |
| VP9 profile 0 | yes (`mkv`) | **yes** (5.1, `mkv`) | Container must be `mkv` (WebM is Matroska); `mp4`/`webm` strings return false |
| VP9 profile 2 (10-bit HDR) | yes (`mkv`) | **yes** (5.1, `mkv`) | Re-probed 2026-10-24 with `mkv` |
| AV1 | **no** | **no** | Not in the TV's codec list (hevc, mpeg1, mpeg2, h263, mpeg4 avc, vp9) |

## Audio (`CanDecodeAudio`)

AAC yes, Opus yes, AC-3 yes, E-AC-3 yes.

## What this means for Phase 5 (best quality)

- Playlet only enables 4K for AV1, and **this TV has no AV1**, so Playlet as-is plays at most 1080p here.
- **VP9 profile 0 and profile 2 (HDR) decode at 2160p60** (container `mkv`). YouTube serves 4K/HDR as VP9 in
  WebM, so **4K and HDR are reachable on this TV via VP9**.
- The open question is the player, not the decoder: Playlet's DASH builder skips WebM sets today ("the player
  never picks webm sets"). Phase 5 must test whether Roku's DASH player accepts WebM/VP9 segments
  (mimeType `video/webm`, codecs `vp9` / `vp09.02...`) on this TV, starting with a hand-made manifest.
- If DASH-WebM doesn't work, the fallback ceiling is **1080p60 AVC** (no HDR).

## Phase 5 test: VP9 4K/HDR over DASH (2026-10-24, result: not possible)

Tested on the TV with "Costa Rica in 4K" (`LXb3EKWsInQ`, VP9 HDR up to 2160p60), reading the player's choice from
ECP `query/media-player` and the generated manifest from `GET :8888/api/yourtube/last-dash`.

| Manifest | What the TV played |
| --- | --- |
| Playlet's default (AVC MP4 sets plus VP9 WebM sets) | AVC 1080p60, about 5.9 Mbps |
| VP9 sets listed first, codecs spelled out (`vp09.02.51.10.01.09.16.09.00`, `vp09.00.51.08`) | still AVC 1080p60 |
| VP9 WebM video only (AAC audio) | audio only: `video="none"` |
| WebM only (VP9 video, Opus audio) | error `demux.dash: Format has no audio or video` |

So although `CanDecodeVideo` says VP9 decodes at 2160p, Roku's DASH demuxer does not read YouTube's WebM
streams. With no AV1 decoder on this TV, the ceiling for YouTube here is **AVC 1080p60**, as upstream Playlet's
comment in `DashManifest.bs` says. The experiment was reverted; only the `last-dash` diagnostics route stays.
