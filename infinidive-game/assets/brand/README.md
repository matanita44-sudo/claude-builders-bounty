# INFINIDIVE brand sources

This directory contains the original, code-native brand and store-art sources for INFINIDIVE. Every visible shape is authored directly in SVG. The files contain no external images, embedded raster data, external icons, linked assets, or font-dependent `<text>` elements.

## Files

| File | Canvas | Purpose |
|---|---:|---|
| `logo_mark.svg` | 1024×1024 | Transparent master mark for the game, press kit, and UI |
| `app_icon.svg` | 1024×1024 | Opaque app-icon source; store platforms add the final corner mask |
| `wordmark.svg` | 1600×420 | Transparent logo lockup with custom path-only lettering |
| `feature_graphic.svg` | 1024×500 | Illustrative Google Play/editorial key-art source |
| `social_card.svg` | 1200×630 | Open Graph, press, and social-sharing key-art source |
| `brand-metadata.json` | — | Machine-readable palette, intended uses, provenance, and disclosure |

The feature graphic and social card are **illustrative key art, not gameplay screenshots**. They must never be placed in a store screenshot slot or described as captured gameplay.

## Mark meaning

The outer bone segments represent a colossal creature. The three-lobed magenta iris is the breach. The cyan needle craft is the Diver crossing from exterior combat into the anatomy. The violet ring is the recoverable Core. This is the core outside → inside → changed outside relationship reduced to one readable symbol.

## Color rules

- Cyan `#54F2E7`: player/Diver only.
- Magenta `#F32D83`: vulnerable tissue and breach.
- Bone `#D7D0BD`: exterior armor and the first half of the name.
- Violet `#A78BFA`: Core energy and the inner boundary.
- Near-black `#070A0F`: primary space background.

Do not replace these with arbitrary neon gradients. The mark must remain legible in grayscale because the craft, aperture, and armor have distinct silhouettes.

## Raster export

Keep these SVGs as the source of truth. Rasterize only for a concrete delivery target. Example commands, when Inkscape is available:

```bash
inkscape app_icon.svg --export-filename=app_icon-1024.png --export-width=1024 --export-height=1024
inkscape feature_graphic.svg --export-filename=feature_graphic-1024x500.png --export-width=1024 --export-height=500
inkscape social_card.svg --export-filename=social_card-1200x630.png --export-width=1200 --export-height=630
```

Before store submission, verify the current official size, color-space, alpha, and file-size requirements. Do not bake rounded corners into the app icon. Review every raster export at full size and at a 48-pixel thumbnail.

## Clear space and modification

- Keep clear space around the standalone mark equal to at least 8% of its width.
- Keep clear space around the wordmark equal to at least one narrow `I` glyph.
- Scale proportionally; never stretch, shear, rotate, or add a drop shadow.
- Do not remove the dark outline around the Diver at small sizes.
- Do not add store badges, ratings, awards, player counts, or unsupported claims to these masters.

Licensing and provenance are recorded in the project root `ASSET_LICENSES.md`.
