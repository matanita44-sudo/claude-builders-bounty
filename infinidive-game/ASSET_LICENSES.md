# Asset licenses and provenance

Last audited: 2026-09-01

This file documents the creative media committed to the INFINIDIVE project. It distinguishes original project work, generated evidence, and third-party material. It is not a license for the source code as a whole.

## Original brand and store art

Copyright © 2026 Matan. All rights reserved.

| Path | Kind | Creation method | External dependencies | Rights |
|---|---|---|---|---|
| `assets/brand/logo_mark.svg` | Brand mark source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/app_icon.svg` | App icon source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/wordmark.svg` | Logo/wordmark source | Original hand-authored path geometry; no font file or `<text>` element | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/feature_graphic.svg` | Store key-art source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/social_card.svg` | Social key-art source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/android_adaptive_background.svg` | Android adaptive-icon background source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/android_adaptive_foreground.svg` | Android adaptive-icon foreground source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/android_adaptive_monochrome.svg` | Android themed/monochrome icon source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/brand-metadata.json` | Asset metadata | Original project metadata | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/README.md` | Asset documentation | Original project documentation | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/*.svg.import` | Godot import metadata, when present | Generated automatically from the SVG sources by Godot | Godot Engine | Generated metadata; not a separate creative asset |

The feature and social graphics are illustrative key art. They are not gameplay screenshots and must not be represented as such.

Verified SHA-256 values for the Android adaptive-icon SVG sources are: background `78aefec7c75b3019058f50b7c0845a007cef35bfab4dbaf6201d87d84625ec53`, foreground `b1d0620980957c776bc516e8af6cba5a1e09156b4d2d50035723e9c761971c8c`, and monochrome `128040c3ec3808d5d1c0fe30a9e11f5dc180f56e8c8da3976bff8fa43179ab4b`.

### Store raster exports

The following files are deterministic raster exports of the original SVG sources above. `file(1)` inspection on 2026-09-01 verified the stated dimensions and channel formats. The Google Play icon, wordmark, and social card are RGBA; the app icon and feature graphic are RGB without alpha.

| Path | Verified format | Size | SHA-256 | Rights |
|---|---|---:|---|---|
| `assets/store/app-icon-1024.png` | PNG, 1024×1024, 8-bit/color RGB | 160,067 bytes | `1a1d424f889849893a74812209225843a650f46290cb4d26ba18250fe9fedf52` | Copyright © 2026 Matan. All rights reserved. |
| `assets/store/google-play-icon-512.png` | PNG, 512×512, 8-bit/color RGBA | 141,587 bytes | `113502be137d8927654c9906d3237025896074c68f53947c747adf0b18fda635` | Copyright © 2026 Matan. All rights reserved. |
| `assets/store/google-play-feature-1024x500.png` | PNG, 1024×500, 8-bit/color RGB | 79,388 bytes | `88cbbf03f75d0621ff87a4239491ec536eab9eeae7e7a3967d981b568532961c` | Copyright © 2026 Matan. All rights reserved. |
| `assets/store/wordmark-2400.png` | PNG, 2400×630, 8-bit/color RGBA | 69,906 bytes | `85fd835ccc0f0553ebffd3f81b74b806530dc79a222f8d29f6dacdae535c9878` | Copyright © 2026 Matan. All rights reserved. |
| `assets/store/social-card-1200x630.png` | PNG, 1200×630, 8-bit/color RGBA | 115,461 bytes | `3fef144afb1d783e276a5c4b4e0dda272bd0ac46703a3d7174e24d2054ec3321` | Copyright © 2026 Matan. All rights reserved. |

`assets/platform/ios/icon-{40,58,60,76,80,87,114,120,128,136,152,167,180,192,1024}.png` are deterministic exact-size RGB/no-alpha derivatives of the same original app-icon source, wired through `export_presets.cfg`. Their generated `.import` files are Godot metadata, not separate creative assets.

The feature graphic satisfies the recorded no-alpha channel requirement. The Play icon has the recorded 512×512, 32-bit RGBA format and size limit; final visual and console-upload validation still remain before submission.

## Runtime visual and audio identity

The current game does not ship external sprites, texture packs, sound samples, music recordings, icon libraries, or font files.

| System | Relevant source | Provenance |
|---|---|---|
| Procedural boss, projectile, organ, room, and Nest visuals | `scripts/gameplay/boss_visual.gd`, `scripts/gameplay/run_scene.gd`, `scripts/ui/nest_view.gd`, and related project scripts | Original code-native geometry and drawing logic; no external visual assets |
| Procedural sound effects and music | `scripts/services/procedural_audio.gd` | Original runtime synthesis; no recorded or sampled source audio |
| Semantic palette | `scripts/ui/visual_theme.gd` | Original project palette |
| UI text rendering | Godot runtime/default font behavior | No font file is redistributed by this repository |

Any future recorded sound, music stem, raster image, typeface, icon library, texture, model, animation, or generated media must be added to this file with its exact source, author, version or retrieval date, license, modifications, and local path before it may ship.

## Gameplay evidence captures

The following files are locally generated captures of the original INFINIDIVE Godot project. They contain no imported third-party visual or audio content. They are evidence artifacts, not source art and not automatically approved as store screenshots.

Copyright © 2026 Matan. All rights reserved.

| Paths | Kind | Provenance |
|---|---|---|
| `artifacts/boot.png` | Game capture | Rendered from this project |
| `artifacts/breach-open.png` | Game capture | Rendered from this project |
| `artifacts/breach-state.png` | Game capture | Rendered from this project |
| `artifacts/exterior-action.png` | Game capture | Rendered from this project |
| `artifacts/exterior-start.png` | Game capture | Rendered from this project |
| `artifacts/internal-real.png` | Game capture | Rendered from this project |
| `artifacts/internal-zone.png` | Game capture | Rendered from this project |
| `artifacts/organ-choice-real.png` | Game capture | Rendered from this project |
| `artifacts/organ-choice.png` | Game capture | Rendered from this project |
| `artifacts/boot.avi` | Game capture video | Rendered from this project |
| `artifacts/boot.png.import` and other Godot `.import` metadata | Generated engine metadata | Created by Godot; not an authored media asset |

`artifacts/headless-tests.xml` is machine-generated test evidence rather than a creative media asset.

### Store-media development evidence

The files under `assets/store/gameplay/` were captured directly from the running Godot project on 2026-09-01. They contain no third-party creative media. They are development evidence and are not automatically approved as final store-submission assets.

Copyright © 2026 Matan. All rights reserved.

| Path | Kind | Provenance |
|---|---|---|
| `assets/store/gameplay/nest-1080x1920.png` | Actual runtime still | Captured from the live Godot window at 1080×1920 |
| `assets/store/gameplay/exterior-combat-1080x1920.png` | Actual runtime still | Captured from the live Godot window at 1080×1920 |
| `assets/store/gameplay/breach-open-1080x1920.png` | Actual runtime still | Captured from the live Godot window at 1080×1920 |
| `assets/store/gameplay/organ-choice-1080x1920.png` | Actual runtime still | Captured from the live Godot window at 1080×1920 |
| `assets/store/gameplay/internal-zone-1080x1920.png` | Actual runtime still | Captured from the live Godot window at 1080×1920 |
| `assets/store/gameplay/raw/session-1080x1920.mp4` | Continuous actual runtime video | FFmpeg X11 capture of the live Godot window; silent because the virtual run used the Dummy audio driver |
| `assets/store/gameplay/trailer-runtime-dev-17s.mp4` | Edited actual runtime video | Hard cuts from the continuous capture only; no overlays, key art, retiming, or generated frames |
| `assets/store/gameplay/trailer-runtime-social-17s.mp4` | Android/social development trailer | The unchanged 1080×1920, 30 fps H.264 gameplay stream from the development edit plus a 48 kHz stereo AAC arrangement rendered only from the shipped `ProceduralAudio` implementation; 3,183,616 bytes; SHA-256 `3950107d8ef89abffd42fec303f96ef5931a1c4139dcc771d91c17c7fa9c7103` |
| `assets/store/gameplay/trailer-runtime-apple-candidate-886x1920-17s.mp4` | Apple-format technical candidate | Complete runtime frames scaled proportionally to 886×1576 and padded to 886×1920, with the same project-generated 48 kHz stereo AAC; no gameplay crop or fabricated frames; 22,353,991 bytes; SHA-256 `7559e8cd1a89820843cd66aa310e1d006cd390668f249ea08fd8b1587df5a1b8`. Not submission-ready because the source was Linux/Xvfb rather than a supported iPhone capture. |
| `assets/store/gameplay/trailer-runtime-apple-poster-5s-886x1920.jpg` | Candidate poster frame | 886×1920, 8-bit RGB JPEG frame extracted at 5.0 seconds from the Apple-format technical candidate; 78,842 bytes; SHA-256 `f04c066c4cc3e8124984bd78a3c3c8d11fae59d5f6e332d17c288dcb01b466a5` |
| `assets/store/gameplay/capture-manifest.json` | Provenance metadata | Original project documentation containing capture facts, hashes, and limitations |
| `assets/store/gameplay/README.md` | Evidence documentation | Original project documentation |
| `assets/store/gameplay/*.import` | Godot import metadata, when present | Generated engine metadata; not a separate creative asset |

## Third-party asset inventory

No third-party creative assets are currently committed to this project. The delivered trailer audio is an offline render from the game's original procedural-audio source; it contains no external sample, recording, voice, music, or sound library.

Specifically, the current inventory contains:

- no external or copyrighted character art;
- no stock imagery;
- no external icons;
- no external fonts;
- no sampled sound effects;
- no recorded music;
- no watermarked material;
- no copied store art;
- no embedded service or API credentials.

## Engine notice

Godot Engine is third-party software distributed under the MIT License. Engine license and copyright notices must be preserved wherever required in distributed binaries and open-source notices. Godot's license does not grant rights to third-party assets, but none are currently included here.

## Intake checklist for future assets

Before adding any creative asset:

1. Confirm that commercial mobile, web, trailer, screenshot, and marketing use is allowed.
2. Save the original license text when attribution or redistribution requires it.
3. Record the source URL, creator, version or retrieval date, and exact local path.
4. Record substantive edits or transformations.
5. Confirm Hebrew and Latin font licenses separately if fonts are introduced.
6. Reject unclear, non-commercial, editorial-only, watermarked, or provenance-free material.
7. Never label illustrative key art as gameplay.
