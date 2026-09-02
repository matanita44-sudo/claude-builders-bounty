# INFINIDIVE brand sources

This directory contains the original, code-native brand and store-art sources for INFINIDIVE. Every visible shape is authored directly in SVG. The files contain no external images, embedded raster data, external icons, linked assets, or font-dependent `<text>` elements.

## Files

| File | Canvas | Background | Purpose |
|---|---:|---|---|
| `logo_mark.svg` | 1024×1024 | Transparent | Master mark for the game, press kit, and UI |
| `app_icon.svg` | 1024×1024 | Opaque | App-icon source; store platforms add the final corner mask |
| `android_adaptive_background.svg` | 432×432 | Opaque | Android adaptive background layer |
| `android_adaptive_foreground.svg` | 432×432 | Transparent | Android adaptive foreground layer |
| `android_adaptive_monochrome.svg` | 432×432 | Transparent | Single-white Android themed-icon silhouette |
| `wordmark.svg` | 1600×420 | Transparent | Logo lockup with custom path-only lettering |
| `feature_graphic.svg` | 1024×500 | Opaque | Illustrative Google Play/editorial key-art source |
| `social_card.svg` | 1200×630 | Opaque | Open Graph, press, and social-sharing key-art source |
| `../platform/ios/launch_screen.svg` | 1170×2532 | Opaque | Static iOS launch-screen source |
| `brand-metadata.json` | — | — | Machine-readable palette, intended uses, provenance, and disclosures |

The feature graphic and social card are **illustrative key art, not gameplay screenshots**. They must never be placed in a store screenshot slot or described as captured gameplay.

## Mark meaning

The monumental marble figure is a Titan: readable scale and mythic danger, not a portrait of one specific boss. The small foreground figure is the unarmed Keeper at the beginning of the journey. The star between the Keeper's open hands is the first Aion spark.

The circular emblem combines three ideas:

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

## Raster export

Keep these SVGs as the source of truth. Rasterize only for a concrete delivery target. Example commands, when Inkscape is available:

```bash
inkscape app_icon.svg --export-filename=app_icon-1024.png --export-width=1024 --export-height=1024
inkscape feature_graphic.svg --export-filename=feature_graphic-1024x500.png --export-width=1024 --export-height=500
inkscape social_card.svg --export-filename=social_card-1200x630.png --export-width=1200 --export-height=630
inkscape ../platform/ios/launch_screen.svg --export-filename=launch-1170x2532.png --export-width=1170 --export-height=2532
```

Before store submission, verify the current official size, color-space, alpha, and file-size requirements. Do not bake rounded corners into the app icon. Review every raster export at full size and at a 48-pixel thumbnail.

## Clear space and modification

- Keep clear space around the standalone mark equal to at least 8% of its width.
- Keep clear space around the wordmark equal to at least one narrow `I` glyph.
- Scale proportionally; never stretch, shear, or rotate the masters.
- Preserve the deep-blue outline on the Titan, seal and Keeper at small sizes.
- Keep the Keeper visibly unarmed; the Aion spark is energy, not a physical weapon.
- Do not add store badges, ratings, awards, player counts, or unsupported claims to these masters.

Licensing and provenance are recorded in the project root `ASSET_LICENSES.md`.
