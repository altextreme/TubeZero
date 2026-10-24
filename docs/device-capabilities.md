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
| VP9 profile 0 | ? | ? | Probed with container `mp4`/`webm`; TV answered "container must be `mkv`". **Needs a re-probe with `mkv`.** |
| VP9 profile 2 (HDR) | ? | ? | Same as above |
| AV1 | **no** | **no** | Not in the TV's codec list (hevc, mpeg1, mpeg2, h263, mpeg4 avc, vp9) |

## Audio (`CanDecodeAudio`)

AAC yes, Opus yes, AC-3 yes, E-AC-3 yes.

## What this means for Phase 5 (best quality)

- Playlet only enables 4K for AV1, and **this TV has no AV1**, so Playlet as-is plays at most 1080p here.
- YouTube serves 4K/HDR as AV1 (MP4) or VP9 (WebM). VP9 is in this TV's decoder list and the TV asked for
  container `mkv` (WebM is a subset of Matroska). So **VP9 in WebM is the only route to 4K/HDR from YouTube
  on this TV**.
- Playlet's DASH builder skips WebM sets today ("the player never picks webm sets"). Phase 5 has to check
  whether Roku's DASH player accepts WebM/VP9 segments on this TV (re-probe VP9 with `mkv`, then a test manifest).
- If VP9-in-DASH doesn't work, the ceiling is **1080p60 AVC**, and HDR is not reachable from YouTube on this TV.
