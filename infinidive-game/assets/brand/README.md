# INFINIDIVE brand sources

This directory contains the brand and store-art sources for INFINIDIVE. Most masters are original, code-native SVG geometry with no external images, embedded raster data, external icons, linked assets, or font-dependent `<text>` elements. The iOS launch SVG is the documented exception: it links the existing project-generated `assets/art/backgrounds/sky_battle.png` behind its original vector crest and path-only wordmark. The current app-icon master is the separate project-directed generated raster `app_icon_source_v2.png`; its embedded C2PA manifest identifies `gpt-image` version `2.0` and `trainedAlgorithmicMedia`. The generated-art provenance and provider-terms notices are recorded in `ASSET_LICENSES.md`.

## Files

| File | Canvas | Background | Purpose |
|---|---:|---|---|
| `logo_mark.svg` | 1024×1024 | Transparent | Master mark for the game, press kit, and UI |
| `app_icon_source_v2.png` | 1254×1254 | Opaque RGB | Current app-icon source of truth; store platforms add the final corner mask |
| `app_icon.svg` | 1024×1024 | Opaque | Historical vector retained for provenance; no longer an app-icon source |
| `android_adaptive_background.svg` | 432×432 | Opaque | Android adaptive background layer |
| `android_adaptive_foreground.svg` | 432×432 | Transparent | Android adaptive foreground layer |
| `android_adaptive_monochrome.svg` | 432×432 | Transparent | Single-white Android themed-icon silhouette |
| `wordmark.svg` | 1600×420 | Transparent | Logo lockup with custom path-only lettering |
| `feature_graphic.svg` | 1024×500 | Opaque | Illustrative Google Play/editorial key-art source |
| `social_card.svg` | 1200×630 | Opaque | Open Graph, press, and social-sharing key-art source |
| `../platform/ios/launch_screen.svg` | 1170×2532 | Opaque | Static iOS launch-screen source; links the project-owned sky-battle background |
| `brand-metadata.json` | — | — | Machine-readable palette, intended uses, provenance, and disclosures |

The feature graphic and social card are **illustrative key art, not gameplay screenshots**. They must never be placed in a store screenshot slot or described as captured gameplay.

## Current app-icon meaning

The current icon pairs a monumental crowned stone Titan with the small, visibly unarmed Keeper at the beginning of the journey. The star between the Keeper's open hands is the first Aion Spark. Bright sky, floating ruins, warm gold, a red mantle, and a turquoise scarf keep the mythic scale inviting and legible at store-thumbnail size.

The older `app_icon.svg` expressed the same product hook through a time-sun seal and remains useful historical design provenance, but it must not be used to regenerate or replace the current raster icon family.

Across the wider brand system, the circular emblem combines three ideas:

- a gold sun for divine power;
- clock marks and an hourglass for Aion and time;
- an aqua opening for the breach through which the Keeper enters a Titan.

Together, the Titan, Keeper and seal reduce the game's outside → inside → changed outside hook to one bright, readable symbol. The product name remains **INFINIDIVE**; Aion is the divine force inside its story world.

## Color and shape rules

- Sky blue `#8EDCF4` and haze `#C8F1EC`: open mythic sky-world.
- Marble `#FFF7E8` and shadow `#C7D9DD`: Titan mass and classical structure.
- Bronze `#B96F3A`: Titan armor, history, and depth.
- Aqua `#35C8C0`: Aion energy, safe interaction, and the active breach.
- Coral `#FF786B`: danger, urgency, and exposed divine essence.
- Gold `#F6C84A`: seals, recovered power, and major milestones.
- Deep blue `#203354`: the shared chunky outline that preserves thumbnail readability.

Keep the major silhouettes distinct in grayscale: Titan above, circular seal at center, Keeper below. Do not convert the seal into an eye, add a weapon to the Keeper, or restore dark space, magenta-iris, bone-monster, or generic neon-biopunk motifs.

## Adaptive-icon safety

The 432×432 Android foreground intentionally includes overscan in the Titan crown and Keeper extremities. The time-sun seal and Aion spark—the critical identity—remain within the central safe area. Always preview the foreground and background together under circle, squircle, rounded-square, and Android themed-icon masks. The monochrome file must stay a single white silhouette on transparency; Android supplies the final themed colors.

## App-icon derivatives and raster export

`app_icon_source_v2.png` is the source of truth for `assets/store/app-icon-1024.png`, `assets/store/google-play-icon-512.png`, and every `assets/platform/ios/icon-*.png` file. All current derivatives are opaque 8-bit/color RGB PNGs; do not regenerate them from `app_icon.svg`. Exact byte sizes and SHA-256 fingerprints are recorded in `ASSET_LICENSES.md` and `brand-metadata.json`.

The other SVG masters remain the source of truth for their corresponding raster exports. The iOS launch derivatives must be normalized after Inkscape export because the strict scaffold contract requires PNG color type 2 (opaque RGB, no alpha). Example commands, when Inkscape and ImageMagick are available:

```bash
inkscape feature_graphic.svg --export-filename=feature_graphic-1024x500.png --export-width=1024 --export-height=500
inkscape social_card.svg --export-filename=social_card-1200x630.png --export-width=1200 --export-height=630
inkscape ../platform/ios/launch_screen.svg --export-filename=launch-1170x2532-rgba.png --export-width=1170 --export-height=2532
convert launch-1170x2532-rgba.png -alpha off PNG24:launch-1170x2532.png
```

Before store submission, verify the current official size, color-space, alpha, and file-size requirements. Do not bake rounded corners into the app icon. Review every raster export at full size and at a 48-pixel thumbnail.

## Clear space and modification

- Keep clear space around the standalone mark equal to at least 8% of its width.
- Keep clear space around the wordmark equal to at least one narrow `I` glyph.
- Scale proportionally; never stretch, shear, or rotate the masters.
- Preserve the current icon's Titan/Keeper scale, warm-gold focal path, red/turquoise character accents, and readable separation at small sizes.
- Keep the Keeper visibly unarmed; the Aion spark is energy, not a physical weapon.
- Do not add store badges, ratings, awards, player counts, or unsupported claims to these masters.

Licensing and provenance are recorded in the project root `ASSET_LICENSES.md`.
