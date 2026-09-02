# Historical pre-pivot runtime media

Every gameplay pixel in this folder came from an actual running INFINIDIVE Godot build. The media contains no mockups, recreated UI, key art, speed changes, generated frames, or claims for unimplemented features.

> **Legacy identity notice:** this capture predates the bright Greek-mythic/AION presentation pivot. It truthfully records the earlier dark GRAVEMAW build, but it does **not** represent the current CRONUS, unarmed-Keeper, AION SPARK, sky-world, or story presentation. None of these stills, posters, or trailers is submission-ready or approved for current store/marketing use. Preserve them as development provenance only; replace them with real release-candidate captures after the pivot is frozen and validated.

## Trailer deliverables

| File | Intended use | What changed from the runtime edit |
|---|---|---|
| `trailer-runtime-social-17s.mp4` | Historical pre-pivot social-development edit | Original 1080×1920 H.264 video stream copied without re-encoding; stereo procedural game audio added |
| `trailer-runtime-apple-candidate-886x1920-17s.mp4` | Historical pre-pivot iPhone technical-format experiment | Full 1080×1920 frame scaled to 886×1576, then padded with 172 black pixels above and below; stereo procedural game audio added |
| `trailer-runtime-apple-poster-5s-886x1920.jpg` | Historical five-second poster-frame reference | Actual historical video frame; no alpha channel |
| `trailer-runtime-dev-17s.mp4` | Preserved silent development edit | Unchanged source edit made only from the continuous runtime capture |

The 17.2-second audio arrangement was rendered directly from the shipped `ProceduralAudio` implementation. It uses the stable internal `gravemaw` boss profile and the captured build's `nest`, `exterior`, `breach`, `organ`, `dive`, and `interior` music states plus shipped game SFX. Its player-facing GRAVEMAW identity is pre-pivot; the same internal boss ID is now displayed as CRONUS. There are no external samples, music, voices, or sound libraries.

## Historical Apple-format status

The historical Apple-format file passed local technical checks performed on 2026-09-01 for the then-reviewed portrait iPhone App Preview stream contract: 886×1920, H.264 High Profile Level 4.0, 30 fps, 10.12 Mbps video, stereo AAC configured at 256 kbps/48 kHz, 17.2 seconds, and under 500 MB. The checked reference was Apple's [App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications).

It was deliberately named **candidate**, but the visual pivot makes it a legacy artifact rather than a current candidate. The original footage was also captured from Linux/Xvfb rather than an iPhone. If an App Preview is used, it needs fresh release-candidate capture through a supported Apple workflow, truthful editing, current-spec validation, and App Store Connect processing. Passing local `ffprobe` checks never proved upload or review acceptance.

## Historical runtime evidence

| File | What the runtime visibly proves |
|---|---|
| `nest-1080x1920.png` | The Last Nest boot/home state |
| `exterior-combat-1080x1920.png` | Live movement, automatic fire, boss armor, projectiles, HUD, and dash control |
| `breach-open-1080x1920.png` | Armor depletion creates a visible breach and enables `DIVE NOW` |
| `organ-choice-1080x1920.png` | Three actual organ choices explain their exterior-combat consequence |
| `internal-zone-1080x1920.png` | The captured build's Hunter Eye route changes the environment and HUD to an internal room |
| `raw/session-1080x1920.mp4` | Local-only 44.4-second continuous provenance capture; intentionally excluded from version control |

## Capture truth and limitations

- Godot ran in a 1080×1920 X11 window through a TCP-only Xvfb display.
- Godot itself rendered at that window size using its 540×960 design viewport and canvas scaling. The runtime stills and preserved development edit were not post-upscaled.
- Interaction used ordinary mouse input through the project's mouse-to-touch emulation.
- No save manipulation, state injection, debug skip, gameplay edit, or feature simulation was used.
- The capture used Godot's Dummy audio driver, so the continuous capture and preserved development edit are silent. Audio was later rendered offline from shipped game code.
- This is pre-pivot virtual-display evidence, not current-presentation evidence or physical iPhone/Android QA.
- The candidate's 172-pixel top and bottom black bars are disclosed format padding; they are not part of the game UI.

## Reproduction and validation

Run from the repository root:

```bash
INFINIDIVE_GODOT_BIN=/absolute/path/to/Godot \
  infinidive-game/tools/build_gameplay_trailers.sh
```

The script renders a deterministic 44.1 kHz stereo PCM mix from shipped code, encodes both trailers, checks their stream contracts with `ffprobe`/`jq`, decodes both outputs end-to-end, and prints exact SHA-256 hashes. Detailed provenance, cut ranges, transformations, measured stream properties, and hashes are in `capture-manifest.json`.
