# Asset licenses and provenance

Last audited: 2026-09-02

This file documents the creative media committed to the INFINIDIVE project. It distinguishes original project work, generated evidence, and third-party material. It is not a license for the source code as a whole.

## Brand and store art

The hand-authored vector portions of the SVG sources and the project documentation in this section are Copyright © 2026 Matan. All rights reserved. Generated raster sources and derivatives are governed by the provider-terms limitations recorded below and are not included in that blanket copyright claim.

| Path | Kind | Creation method | External dependencies | Rights |
|---|---|---|---|---|
| `assets/brand/logo_mark.svg` | Brand mark source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/app_icon_source_v2.png` | Current app-icon source of truth | Project-directed original image-generator output using only the project-owned CRONUS, unarmed Aion hero, and bright sky-battle images as visual references | Image-generator provider; use is subject to the provider terms applicable to the owner and service account | No independent copyrightability or exclusivity claim is made beyond the applicable provider terms; see the generated-art notice below. |
| `assets/brand/app_icon.svg` | Legacy app-icon vector | Original hand-authored SVG geometry retained for historical provenance; no longer the app-icon source of truth | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/wordmark.svg` | Logo/wordmark source | Original hand-authored path geometry; no font file or `<text>` element | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/feature_graphic.svg` | Store key-art source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/social_card.svg` | Social key-art source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/android_adaptive_background.svg` | Android adaptive-icon background source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/android_adaptive_foreground.svg` | Android adaptive-icon foreground source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/android_adaptive_monochrome.svg` | Android themed/monochrome icon source | Original hand-authored SVG geometry | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/platform/ios/launch_screen.svg` | iOS launch-screen source | Original hand-authored Aion crest and path-only wordmark over the existing project-generated `sky_battle.png` background | Local project asset `assets/art/backgrounds/sky_battle.png`; no external font, icon, or third-party image | Vector geometry Copyright © 2026 Matan. Generated background use is subject to the provider terms recorded below. |
| `assets/brand/brand-metadata.json` | Asset metadata | Original project metadata | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/README.md` | Asset documentation | Original project documentation | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/*.svg.import` | Godot import metadata, when present | Generated automatically from the SVG sources by Godot | Godot Engine | Generated metadata; not a separate creative asset |

The feature and social graphics are illustrative key art. They are not gameplay screenshots and must not be represented as such.

The bright Greek-mythic SVG masters were fingerprinted after final raster QA on 2026-09-02. `app_icon.svg` is retained in this inventory as the legacy app-icon vector and is not the source of the current raster icon family:

| Source path | Size | SHA-256 |
|---|---:|---|
| `assets/brand/logo_mark.svg` | 6,320 bytes | `d68bea3cebe0c3f95ce32d2681e4de1a78b30b16ebf239985ef03f9778b1d777` |
| `assets/brand/app_icon.svg` | 5,929 bytes | `dd6a756e859a21c306438fdc5aea8cac3b752086ba8c29a11fb5d89149810e0a` |
| `assets/brand/wordmark.svg` | 5,605 bytes | `8a37e7a7de3b21500f7c872b61db7348d005728d142b56ba7d155103677d0812` |
| `assets/brand/feature_graphic.svg` | 6,883 bytes | `433b2c68a0bb4dace139a40a2b2e8d13692822788e2f93735bf1a1eaa37c1c14` |
| `assets/brand/social_card.svg` | 7,170 bytes | `14f1f1863603c59ec6f926e1cc6f5a3579339d646be74d9ca69c43f5dd70b95b` |
| `assets/brand/android_adaptive_background.svg` | 1,114 bytes | `a7f6d6c006b5929bd4981a527bc7e8c42717d4fdce99e81198149c28247fec8a` |
| `assets/brand/android_adaptive_foreground.svg` | 3,642 bytes | `31ef1eddf22964e8ef5e212d1e734fb6c712cd1633737740242d4066a2aa2ae8` |
| `assets/brand/android_adaptive_monochrome.svg` | 1,204 bytes | `3944bb9fb7b745b785c5ffe184b9e1808a6c0f5dec85eec388b792b0723fca8b` |
| `assets/platform/ios/launch_screen.svg` | 9,875 bytes | `1a458c66dc7627a21fe14b02d45357b3bfdcba7bb43ff44a134ec36bd113dcee` |

The current app-icon source was created on 2026-09-02 specifically for INFINIDIVE at the project owner's direction. The generation workflow used `assets/art/titans/cronus.png`, `assets/art/heroes/aion_diver_unarmed.png`, and `assets/art/backgrounds/sky_battle.png` as project-owned visual references for the Titan, unarmed hero, and bright Greek-mythic sky identity. No separately sourced stock image, font, icon, texture, or third-party character asset was intentionally added. The source's embedded C2PA manifest identifies `gpt-image` version `2.0` and the digital-source type `trainedAlgorithmicMedia`. The source is an opaque full-frame raster; the platform files listed below are resized derivatives, not independent generated works.

As with the other generated art recorded in this file, use of this output is subject to the image-generator provider terms applicable to the owner and service account. This record describes the workflow and does not make an independent claim about copyrightability, exclusivity, or the absence of incidental visual similarity beyond those terms.

| Current source path | Verified format | Size | SHA-256 |
|---|---|---:|---|
| `assets/brand/app_icon_source_v2.png` | PNG, 1254×1254, 8-bit/color RGB, opaque/no alpha | 2,805,506 bytes | `a3543a1d1ba0340594afad7d233301bff88396860106a7550deb0e2c3dce2b6a` |

### Store raster exports

The current app-icon files are resized raster derivatives of `assets/brand/app_icon_source_v2.png`; they are not exports of the legacy `app_icon.svg`. The remaining store rasters are exports of their corresponding SVG sources above. `file(1)` inspection on 2026-09-02 verified the stated dimensions and channel formats. Both current app-icon rasters are RGB without alpha; the wordmark and social card are RGBA, and the feature graphic is RGB without alpha.

| Path | Verified format | Size | SHA-256 | Rights |
|---|---|---:|---|---|
| `assets/store/app-icon-1024.png` | PNG, 1024×1024, 8-bit/color RGB, opaque/no alpha | 1,929,348 bytes | `ea21459bafafd32851bc0e56a791ac6fdc253e58b64e8d7624bec69fff95f22f` | Generated-art use subject to the provider terms recorded above. |
| `assets/store/google-play-icon-512.png` | PNG, 512×512, 8-bit/color RGB, opaque/no alpha | 546,245 bytes | `e1fbcf95badb833282da7d5eb12031fbe8a7e91d3d58c4046664f87f6fd7d187` | Generated-art use subject to the provider terms recorded above. |
| `assets/store/google-play-feature-1024x500.png` | PNG, 1024×500, 8-bit/color RGB | 112,731 bytes | `b1c85302917e766e40869dfa22c01c58e1fa6d71deef3eb284716833eef7daa8` | Copyright © 2026 Matan. All rights reserved. |
| `assets/store/wordmark-2400.png` | PNG, 2400×630, 8-bit/color RGBA | 122,479 bytes | `52dd7ad56152e1916d6c0166ecbec7ecc06e4cf6ef895215e86747e90534ff12` | Copyright © 2026 Matan. All rights reserved. |
| `assets/store/social-card-1200x630.png` | PNG, 1200×630, 8-bit/color RGBA | 157,601 bytes | `45dffcfb19beed61ac5d6ad4166f3ab04b1ee59459928471333433bf84809777` | Copyright © 2026 Matan. All rights reserved. |

`assets/platform/ios/icon-{40,58,60,76,80,87,114,120,128,136,152,167,180,192,1024}.png` are exact-size 8-bit/color RGB, opaque/no-alpha derivatives of `assets/brand/app_icon_source_v2.png`, wired through `export_presets.cfg`. Their generated `.import` files are Godot metadata, not separate creative assets. The exact derivative fingerprints are:

| iOS icon | Verified format | Size | SHA-256 |
|---|---|---:|---|
| `icon-40.png` | PNG, 40×40, 8-bit/color RGB, opaque/no alpha | 4,440 bytes | `cf469765ef193d41ab6b79d63c91d63096ad5319caa4a83736ce747c6a872d8d` |
| `icon-58.png` | PNG, 58×58, 8-bit/color RGB, opaque/no alpha | 9,020 bytes | `73f064343168a2aca2e63265b82b83d91675a16262ce9a034cbcbec2102a64cf` |
| `icon-60.png` | PNG, 60×60, 8-bit/color RGB, opaque/no alpha | 9,612 bytes | `73c112cac5ef9b9ff7707b8c192c7f4889d8fbc5e764811ee2c3fea46f9017a6` |
| `icon-76.png` | PNG, 76×76, 8-bit/color RGB, opaque/no alpha | 15,088 bytes | `e491f16911204d420911de2f50a11d5f11e5c02cdcc33aefc716c1bb56a0ef54` |
| `icon-80.png` | PNG, 80×80, 8-bit/color RGB, opaque/no alpha | 16,645 bytes | `7f7846c4ddf59edef2f796e0843cddfe7313d5bfad8c23c6c247309f898c17f5` |
| `icon-87.png` | PNG, 87×87, 8-bit/color RGB, opaque/no alpha | 19,521 bytes | `99559cb15e28061e0f77fc1a69b7e3c8229341b6a1c950daa676dbe566ba356d` |
| `icon-114.png` | PNG, 114×114, 8-bit/color RGB, opaque/no alpha | 32,734 bytes | `40c2d678942c352edc8aaa5c46942c58a36a0b6f4bb19cce7959aa2594bf8fc0` |
| `icon-120.png` | PNG, 120×120, 8-bit/color RGB, opaque/no alpha | 36,093 bytes | `d392e593e25cf498086cc66bc6e9f34a0654de2a1cbbb74b8360f961686e01d8` |
| `icon-128.png` | PNG, 128×128, 8-bit/color RGB, opaque/no alpha | 40,852 bytes | `0c89497a83d712df53d1f2f653a114be6ecbf12f0ff31fef0fdbf1c0575935bf` |
| `icon-136.png` | PNG, 136×136, 8-bit/color RGB, opaque/no alpha | 45,817 bytes | `86e27a7b4d7edc5bb1615f234fb401c2551ce9e46e652f0b8131d9ccc0e42a7d` |
| `icon-152.png` | PNG, 152×152, 8-bit/color RGB, opaque/no alpha | 56,582 bytes | `70ebf6bd41826a4aa1216eb882d0583f8785e90acf4a1e7ce2476095086f9ca9` |
| `icon-167.png` | PNG, 167×167, 8-bit/color RGB, opaque/no alpha | 67,619 bytes | `623c186d122dc04906b4fe62d58d3c1e98480d64140cf88f3a477d98ce499f88` |
| `icon-180.png` | PNG, 180×180, 8-bit/color RGB, opaque/no alpha | 77,829 bytes | `dbff38cc49a70c6163d1d23982f7d84bf7608908660f7926a092cb6c6483aac8` |
| `icon-192.png` | PNG, 192×192, 8-bit/color RGB, opaque/no alpha | 88,002 bytes | `71d3a03322255fcebb95f491160b63b9b49fe707e44756d487591f14fc224b6d` |
| `icon-1024.png` | PNG, 1024×1024, 8-bit/color RGB, opaque/no alpha | 1,929,348 bytes | `ea21459bafafd32851bc0e56a791ac6fdc253e58b64e8d7624bec69fff95f22f` |

`assets/platform/ios/launch_screen@2x.png` and `launch_screen.png` are the 780×1688 and 1170×2532, 8-bit sRGB RGB/no-alpha rasters exported from `launch_screen.svg` and wired to the iOS storyboard as its 2x/3x images. The source composes the already documented project-generated `assets/art/backgrounds/sky_battle.png` with an original vector Aion crest and custom path-only wordmark; it is static illustrative brand art, not gameplay, a captured screen, or a loading/progress indicator. Source size/hash: 9,875 bytes, `1a458c66dc7627a21fe14b02d45357b3bfdcba7bb43ff44a134ec36bd113dcee`; 2x raster size/hash: 1,053,086 bytes, `9b43acec7db8a8046a4ed88e48d53be79ade7ee85bb959bd4b398743097819bb`; 3x raster size/hash: 1,863,629 bytes, `7011671570f697ee87a5b007cbb548408bdd9ea33cc82ad49269519c421177ff`.

The feature graphic satisfies the recorded no-alpha channel requirement. The current Play listing icon is 512×512 and below the recorded 1,024 KB size limit, but it is 8-bit/color RGB without alpha rather than the 32-bit RGBA format recorded in `STORE_METADATA.md`; regenerate or obtain explicit Play Console acceptance before treating that asset as submission-ready. Final visual and console-upload validation still remain for every store raster.

## Project-generated runtime artwork

The runtime images below were created on 2026-09-02 specifically for INFINIDIVE at the project owner's direction using the image generator built into the development environment. The generation briefs requested original Greek-mythic characters and environments with a bright, readable mobile-game presentation; they did not request imitation of a named artist or the reproduction of an existing game asset.

A user-supplied reference image was consulted only for broad visual direction such as readability, color, scale, and energy. The reference image is not included in this repository, was not composited into these files, and is not redistributed by the project.

The current app-icon source recorded above is a separate project-directed generated output. Its reference inputs were limited to the already project-owned CRONUS, unarmed Aion hero, and sky-battle artwork in this repository. It was not derived from the legacy `app_icon.svg`, and that vector must not be used to regenerate the current icon family.

Use of the generated outputs is subject to the image-generator provider terms applicable to the owner and the relevant service account. This provenance record does not make an independent claim about copyrightability, exclusivity, or ownership beyond those terms. No third-party stock asset, texture pack, character file, font, or watermarked element was intentionally incorporated.

The transparent hero and Titan outputs were processed after generation by removing their generated chroma-key backgrounds, trimming the transparent canvas, and resizing them for the Godot runtime. Oceanus received one additional image-generator edit on 2026-09-02 to remove residual green inside the water halo before the same mechanical resize/canvas fit. The two full-frame backgrounds were resized and exported as 8-bit RGB PNGs at the game's 540×960 portrait reference size; they did not require chroma-key transparency. These operations did not introduce another creative source.

| Path | Runtime format | Post-generation processing | SHA-256 |
|---|---|---|---|
| `assets/art/heroes/aion_diver_unarmed.png` | PNG, 313×512, 8-bit sRGBA | Chroma-key background removal, transparent trim, and resize | `ca6b44ba4842de8c2b31b35b8063b34a2235253b515820874b2e13b917631697` |
| `assets/art/titans/cronus.png` | PNG, 683×768, 8-bit sRGBA | Chroma-key background removal, transparent trim, and resize | `13090ff99e036af3d96561ae0844586aa5905675c5ce8b198f27f84ab47045a0` |
| `assets/art/titans/hyperion.png` | PNG, 512×768, 8-bit sRGBA | Chroma-key background removal, transparent trim, and resize | `da242f5413c29b0358d735647292979b89bb649c1b8a21ac4e698f6fabee7245` |
| `assets/art/titans/oceanus.png` | PNG, 540×768, 8-bit sRGBA | Image-generator transparent-background cleanup, resize, and transparent canvas fit | `d662a4e09b69f05036d877b780497f218151ad382527d8a98df810463627273a` |
| `assets/art/titans/mnemosyne.png` | PNG, 515×768, 8-bit sRGBA | Chroma-key background removal, transparent trim, and resize | `a496f32f5b331f6ba7a729303f702bd3cbe09de3f5bad486d0e42eb841eb443a` |
| `assets/art/backgrounds/sky_battle.png` | PNG, 540×960, 8-bit sRGB | Portrait resize and PNG24/RGB export; no chroma key | `020e2702d677950e2224ec03a87e10805bdf01f1d7892a56a423ffacac82b3a8` |
| `assets/art/backgrounds/divine_interior.png` | PNG, 540×960, 8-bit sRGB | Portrait resize and PNG24/RGB export; no chroma key | `9d104587ebf8d6361d021d19fbbca883450e30ee6276be08ba311d2b231c076e` |

Godot-generated `assets/art/**/*.import` files are engine import metadata and are not separate creative assets.

## Runtime visual and audio identity

The current game ships the project-generated runtime images catalogued above. It does not ship separately sourced stock sprites, texture packs, sound samples, music recordings, icon libraries, or font files.

| System | Relevant source | Provenance |
|---|---|---|
| Runtime characters, Titans, and battle backgrounds | `assets/art/`, `scripts/gameplay/player_controller.gd`, `scripts/gameplay/boss_visual.gd`, and `scripts/gameplay/run_scene.gd` | Project-directed generated artwork catalogued above, with original code-native fallbacks and effects |
| Procedural projectile, room, UI, and Nest visuals | `scripts/gameplay/projectile_pool.gd`, `scripts/gameplay/run_scene.gd`, `scripts/ui/nest_view.gd`, and related project scripts | Original code-native geometry and drawing logic |
| Pre-rendered sound effects and adaptive music | `scripts/services/procedural_audio.gd`, `tools/audio_asset_synthesizer.gd`, `tools/generate_audio_assets.gd`, and `assets/audio/generated/` | Original deterministic project synthesis rendered offline into shipped PCM resources; no external recording, sample, voice, music, or sound library |
| Semantic palette | `scripts/ui/visual_theme.gd` | Original project palette |
| UI text rendering | Godot runtime/default font behavior | No font file is redistributed by this repository |

The shipped audio catalog contains 123 Godot `AudioStreamWAV` resources: 24 one-shot sound effects and 99 adaptive-music layers. The resources are signed 16-bit mono PCM generated deterministically by the project-owned offline synthesizer. `assets/audio/generated/manifest.json` records each resource path, byte size, PCM size, mix rate, loop state, and SHA-256, plus the generator/synthesizer/definition source fingerprints. The `tools/` renderer is excluded from every export preset; the production runtime loads the generated resources on demand and does not synthesize audio samples during application startup or gameplay.

Any future recorded sound, music stem, raster image, typeface, icon library, texture, model, animation, or generated media must be added to this file with its exact source, author, version or retrieval date, license, modifications, and local path before it may ship.

## Gameplay evidence captures

Gameplay evidence is retained only when the referenced file is present in this repository or in a source-bound CI artifact. Earlier local-only filenames such as `artifacts/boot.png`, `artifacts/aion-prologue-preview.png`, and `artifacts/mythic-combat-preview.png` are not present in the current tree and are therefore not release inputs or evidence claims here. Current browser captures are produced by CI, bound to their source commit/run, and remain review evidence rather than automatically approved store screenshots.

Copyright © 2026 Matan. All rights reserved.

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
| `assets/store/gameplay/trailer-runtime-social-17s.mp4` | Legacy pre-pivot social development trailer | The unchanged 1080×1920, 30 fps H.264 gameplay stream from the development edit plus a 48 kHz stereo AAC arrangement rendered only from the shipped `ProceduralAudio` implementation; 3,183,616 bytes; SHA-256 `3950107d8ef89abffd42fec303f96ef5931a1c4139dcc771d91c17c7fa9c7103`. Truthful historical provenance only; its dark GRAVEMAW identity does not represent the current product. |
| `assets/store/gameplay/trailer-runtime-apple-candidate-886x1920-17s.mp4` | Legacy pre-pivot Apple-format experiment | Complete runtime frames scaled proportionally to 886×1576 and padded to 886×1920, with the same project-generated 48 kHz stereo AAC; no gameplay crop or fabricated frames; 22,353,991 bytes; SHA-256 `7559e8cd1a89820843cd66aa310e1d006cd390668f249ea08fd8b1587df5a1b8`. Not submission-ready because it predates the identity pivot and the source was Linux/Xvfb rather than a supported Apple capture path. |
| `assets/store/gameplay/trailer-runtime-apple-poster-5s-886x1920.jpg` | Legacy pre-pivot poster frame | 886×1920, 8-bit RGB JPEG frame extracted at 5.0 seconds from the Apple-format experiment; 78,842 bytes; SHA-256 `f04c066c4cc3e8124984bd78a3c3c8d11fae59d5f6e332d17c288dcb01b466a5` |
| `assets/audio/generated/trailer/bright-browser-gameplay-music.wav` | Build-time bright-trailer music bed | Deterministic 30.000 s PCM s16le, 48 kHz stereo project-original offline mix; 5,760,044 bytes; SHA-256 `ffe2e88daa2a3b9e17322e081357b03399036aeed3199720605eb1be0426c442`; rendered by `tools/render_bright_trailer_audio.gd` (SHA-256 `a714845ad3259d77d7f55e9c1fb67d20df2818b444aea65ac6dc50e0e59aff0a`) through `tools/bright_trailer_audio_renderer.tscn` from the hash-bound generated runtime music catalog; no external samples or recordings. It is added offline, is not live-captured or event-synchronous, is ignored by Godot through `.gdignore`, and is also excluded from every runtime export preset. |
| `assets/store/gameplay/capture-manifest.json` | Provenance metadata | Original project documentation containing capture facts, hashes, limitations, and an explicit legacy pre-pivot/non-submission status |
| `assets/store/gameplay/README.md` | Evidence documentation | Original project documentation |
| `assets/store/gameplay/*.import` | Godot import metadata, when present | Generated engine metadata; not a separate creative asset |

## Third-party asset inventory

No separately sourced third-party creative assets are currently committed to this project. The project-generated image outputs are disclosed in their own section above and remain governed by the applicable image-generator provider terms. The shipped game audio and any delivered trailer audio are offline renders from the project's original deterministic synthesizer; they contain no external sample, recording, voice, music, or sound library.

Specifically, the current inventory contains:

- no separately sourced character or environment art;
- no stock imagery;
- no external icons;
- no external fonts;
- no sampled sound effects;
- no recorded music;
- no watermarked material;
- no copied store art;
- no embedded service or API credentials.

## Engine notice

Godot Engine is third-party software distributed under the MIT License. Engine license and copyright notices must be preserved wherever required in distributed binaries and open-source notices. The public Web build includes the bilingual `web_pages/notices.html` notice page, which is also reachable from Settings, Privacy, Support, and Terms. Godot's license does not grant rights to third-party assets, but none are currently included here.

The required upstream copyright lines are:

> Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
>
> Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

The complete MIT license text is reproduced on the distributed notices page. Before freezing a native release archive, audit the exact archive and every bundled third-party component again; this development inventory is not a substitute for that final archive audit.

## Intake checklist for future assets

Before adding any creative asset:

1. Confirm that commercial mobile, web, trailer, screenshot, and marketing use is allowed.
2. Save the original license text when attribution or redistribution requires it.
3. Record the source URL, creator, version or retrieval date, and exact local path.
4. Record substantive edits or transformations.
5. Confirm Hebrew and Latin font licenses separately if fonts are introduced.
6. Reject unclear, non-commercial, editorial-only, watermarked, or provenance-free material.
7. Never label illustrative key art as gameplay.
