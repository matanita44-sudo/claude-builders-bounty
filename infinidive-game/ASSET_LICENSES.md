# Asset licenses and provenance

Last audited: 2026-09-02

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
| `assets/platform/ios/launch_screen.svg` | iOS launch-screen source | Original hand-authored SVG geometry; no font or external image | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/brand-metadata.json` | Asset metadata | Original project metadata | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/README.md` | Asset documentation | Original project documentation | None | Copyright © 2026 Matan. All rights reserved. |
| `assets/brand/*.svg.import` | Godot import metadata, when present | Generated automatically from the SVG sources by Godot | Godot Engine | Generated metadata; not a separate creative asset |

The feature and social graphics are illustrative key art. They are not gameplay screenshots and must not be represented as such.

The bright Greek-mythic SVG masters were fingerprinted after final raster QA on 2026-09-02:

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
| `assets/platform/ios/launch_screen.svg` | 8,473 bytes | `2f1fafaadf76afe6c9331cee09c4334feb229459fd6ad0278a7add38442f3a39` |

### Store raster exports

The following files are deterministic raster exports of the original SVG sources above. `file(1)` inspection on 2026-09-02 verified the stated dimensions and channel formats. The Google Play icon, wordmark, and social card are RGBA; the app icon and feature graphic are RGB without alpha.

| Path | Verified format | Size | SHA-256 | Rights |
|---|---|---:|---|---|
| `assets/store/app-icon-1024.png` | PNG, 1024×1024, 8-bit/color RGB | 143,963 bytes | `69a38953ac5403f7db0c287dec796ca905684013da6b53936ccce2623630627c` | Copyright © 2026 Matan. All rights reserved. |
| `assets/store/google-play-icon-512.png` | PNG, 512×512, 8-bit/color RGBA | 72,562 bytes | `eb161d7102cc2d73f1859a53775f38d52350d8355bd9342763772d7653540244` | Copyright © 2026 Matan. All rights reserved. |
| `assets/store/google-play-feature-1024x500.png` | PNG, 1024×500, 8-bit/color RGB | 112,731 bytes | `b1c85302917e766e40869dfa22c01c58e1fa6d71deef3eb284716833eef7daa8` | Copyright © 2026 Matan. All rights reserved. |
| `assets/store/wordmark-2400.png` | PNG, 2400×630, 8-bit/color RGBA | 122,479 bytes | `52dd7ad56152e1916d6c0166ecbec7ecc06e4cf6ef895215e86747e90534ff12` | Copyright © 2026 Matan. All rights reserved. |
| `assets/store/social-card-1200x630.png` | PNG, 1200×630, 8-bit/color RGBA | 157,601 bytes | `45dffcfb19beed61ac5d6ad4166f3ab04b1ee59459928471333433bf84809777` | Copyright © 2026 Matan. All rights reserved. |

`assets/platform/ios/icon-{40,58,60,76,80,87,114,120,128,136,152,167,180,192,1024}.png` are deterministic exact-size RGB/no-alpha derivatives of the same original app-icon source, wired through `export_presets.cfg`. Their generated `.import` files are Godot metadata, not separate creative assets. The exact derivative fingerprints are:

| iOS icon | Size | SHA-256 |
|---|---:|---|
| `icon-40.png` | 2,716 bytes | `f58a3fb4f30eeb2dd9296af3c8b2e414a580587ce6241ecd37a6e4b18b27d0e8` |
| `icon-58.png` | 4,807 bytes | `3a82966af16c568c5b5235004eca3f0935dd736060e9747641d2ad4bf7aa00ca` |
| `icon-60.png` | 5,093 bytes | `8eae7838ca59acf79c9f7b2c37d9a6acc5a078d647213b84ea7018aadf84ef91` |
| `icon-76.png` | 7,161 bytes | `afff2ecb0123d230b4021e0b862df74b4f58e63941c9a1d828b860abcaab96d1` |
| `icon-80.png` | 7,639 bytes | `50eb995d6c8fad48ee497ddec09d5e6e85fee66124dc6474ccf09160f0cefbc5` |
| `icon-87.png` | 8,707 bytes | `14477455949281218ef07d3fcec125b34a6c5bbdd5a81fc70b54b9c9c9fcaee1` |
| `icon-114.png` | 12,251 bytes | `13444a7486d2640fd475ae0a6de23e95673cf4fb2d60e19111a9e22c5fd83508` |
| `icon-120.png` | 13,115 bytes | `b48431324802375ba8dfcf8e436a2baa85fe9b730bc942489ae6437e3327a271` |
| `icon-128.png` | 14,101 bytes | `6a4de57ee3c0be00e80075d8615c5f4171fb9743226cce65987d4cd61c43a190` |
| `icon-136.png` | 15,187 bytes | `04b38f67de033e8abf9b2827c7cbedc6691b454445af9a6b4f05f1a8ed36eca9` |
| `icon-152.png` | 17,394 bytes | `1e20b494b0c9d7e82ef4ae900184afccd1a61d6e7f9d8db513d9b83241362ad4` |
| `icon-167.png` | 19,256 bytes | `5b25e1da29f11eeb27c15ae371a2104ac9bf5eb94aad0b401acace73593a6dc3` |
| `icon-180.png` | 21,146 bytes | `6ac4a57546d0e2a5f88cea9bb5c66eea35abf05f6fe25ae713282c193768af17` |
| `icon-192.png` | 22,722 bytes | `c4ac3acba7d4f52beb7708ae0c4d6908b9f9af3eee1c8fcfbab32fe805ba5e63` |
| `icon-1024.png` | 143,963 bytes | `69a38953ac5403f7db0c287dec796ca905684013da6b53936ccce2623630627c` |

`assets/platform/ios/launch_screen@2x.png` and `launch_screen.png` are the 780×1688 and 1170×2532, 8-bit sRGB RGB/no-alpha rasters exported from `launch_screen.svg` and wired to the iOS storyboard as its 2x/3x images. Source size/hash: 8,473 bytes, `2f1fafaadf76afe6c9331cee09c4334feb229459fd6ad0278a7add38442f3a39`; 2x raster size/hash: 201,788 bytes, `905cf3045c20775fe5a1ca25835fd352fe48dc8c01738c49307d7e4c86ca0f12`; 3x raster size/hash: 313,398 bytes, `c17a2df0f4bd695888c74157d6f9c341a9efe8c6b952bfd5991a863db9f686e6`.

The feature graphic satisfies the recorded no-alpha channel requirement. The Play icon has the recorded 512×512, 32-bit RGBA format and size limit; final visual and console-upload validation still remain before submission.

## Project-generated runtime artwork

The runtime images below were created on 2026-09-02 specifically for INFINIDIVE at the project owner's direction using the image generator built into the development environment. The generation briefs requested original Greek-mythic characters and environments with a bright, readable mobile-game presentation; they did not request imitation of a named artist or the reproduction of an existing game asset.

A user-supplied reference image was consulted only for broad visual direction such as readability, color, scale, and energy. The reference image is not included in this repository, was not composited into these files, and is not redistributed by the project.

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
| `artifacts/aion-prologue-preview.png` | Current English-first story capture | Captured from the live bright-mythic Godot window at 405×720 under Linux/Xvfb; 35,099 bytes; SHA-256 `2c1516b855150b92a86bf5b2b6e33eedad11352c36f5b560a9fe58db6611dca8` |
| `artifacts/unarmed-intro-preview.png` | Current unarmed-Keeper capture | Captured from the live bright-mythic Godot window at 405×720 before first movement; 370,304 bytes; SHA-256 `d38654f404e22145cf3897a7eb7e11d593ee737fcae76f4a23b14c5a7cace04c` |
| `artifacts/mythic-combat-preview.png` | Current Aion Spark combat capture | Captured from the live bright-mythic Godot window at 405×720 after first movement; 372,962 bytes; SHA-256 `8499307355d156125588c622119229d3c3742676c22f1dfaa9115cc757303da1` |
| `artifacts/mythic-nest-preview.png` | Current Last Nest capture | Captured from the live bright-mythic Godot window at 405×720; 83,630 bytes; SHA-256 `7b73ea56bb3e2bf8620741c11fee8995dbd5359603389a89d9189c977e12a35e` |
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
| `assets/store/gameplay/trailer-runtime-social-17s.mp4` | Legacy pre-pivot social development trailer | The unchanged 1080×1920, 30 fps H.264 gameplay stream from the development edit plus a 48 kHz stereo AAC arrangement rendered only from the shipped `ProceduralAudio` implementation; 3,183,616 bytes; SHA-256 `3950107d8ef89abffd42fec303f96ef5931a1c4139dcc771d91c17c7fa9c7103`. Truthful historical provenance only; its dark GRAVEMAW identity does not represent the current product. |
| `assets/store/gameplay/trailer-runtime-apple-candidate-886x1920-17s.mp4` | Legacy pre-pivot Apple-format experiment | Complete runtime frames scaled proportionally to 886×1576 and padded to 886×1920, with the same project-generated 48 kHz stereo AAC; no gameplay crop or fabricated frames; 22,353,991 bytes; SHA-256 `7559e8cd1a89820843cd66aa310e1d006cd390668f249ea08fd8b1587df5a1b8`. Not submission-ready because it predates the identity pivot and the source was Linux/Xvfb rather than a supported Apple capture path. |
| `assets/store/gameplay/trailer-runtime-apple-poster-5s-886x1920.jpg` | Legacy pre-pivot poster frame | 886×1920, 8-bit RGB JPEG frame extracted at 5.0 seconds from the Apple-format experiment; 78,842 bytes; SHA-256 `f04c066c4cc3e8124984bd78a3c3c8d11fae59d5f6e332d17c288dcb01b466a5` |
| `assets/store/gameplay/capture-manifest.json` | Provenance metadata | Original project documentation containing capture facts, hashes, limitations, and an explicit legacy pre-pivot/non-submission status |
| `assets/store/gameplay/README.md` | Evidence documentation | Original project documentation |
| `assets/store/gameplay/*.import` | Godot import metadata, when present | Generated engine metadata; not a separate creative asset |

## Third-party asset inventory

No separately sourced third-party creative assets are currently committed to this project. The project-generated image outputs are disclosed in their own section above and remain governed by the applicable image-generator provider terms. The delivered trailer audio is an offline render from the game's original procedural-audio source; it contains no external sample, recording, voice, music, or sound library.

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
