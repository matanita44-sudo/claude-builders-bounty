# INFINIDIVE Open-Source Notices

**Status:** pre-release notice draft\
**Reviewed build:** INFINIDIVE `0.1.0`, Godot `4.7.2-stable`\
**Review date:** 2026-09-01

This file records open-source software known to be included in, or required to produce, the reviewed INFINIDIVE runtime. It is not evidence that the current list has been generated from a final signed AAB or IPA. Re-audit the exact release artifacts and preserve all upstream notices before distribution.

## Godot Engine

INFINIDIVE is built with and distributes the Godot Engine runtime. Godot Engine is free and open-source software distributed under the MIT License.

Upstream references:

- https://godotengine.org/license/
- https://github.com/godotengine/godot/blob/master/LICENSE.txt
- https://github.com/godotengine/godot/blob/master/COPYRIGHT.txt

Godot's upstream copyright notice is:

> Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).\
> Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

### MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Creative-asset boundary

No third-party creative asset is present in the reviewed repository inventory. Runtime visuals, procedural audio, brand SVGs, raster store exports, gameplay captures, and the social/Apple-candidate trailer audio are original project work described in `ASSET_LICENSES.md`. Trailer audio was rendered only from the shipped procedural-audio implementation; it contains no external sample, recording, voice, music, or audio library. The project currently includes no external sprite pack, texture pack, icon library, typeface file, sampled sound effect, recorded music, stock image, or copied store artwork.

Godot's default/runtime font and platform/export-template components are engine dependencies, not project-authored creative assets. The final distribution audit must inspect Godot's `COPYRIGHT.txt` and the exact native/Web export contents for bundled third-party library notices; this draft does not replace those upstream notices.

## Build-only tooling

GitHub Actions and the configured export action are build/deployment tooling, not claimed as bundled game-runtime components. If a future release embeds code from a plugin, SDK, library, font, or content package, add its name, version, copyright, license text, source URL, modifications, and shipped paths here before release.

## תקציר בעברית

INFINIDIVE נבנה באמצעות Godot Engine בגרסה `4.7.2-stable`. מנוע Godot מופץ ברישיון MIT; נוסח הרישיון והודעות זכויות היוצרים שלעיל חייבים להישמר בהתאם לדרישות הרישיון.

במלאי שנבדק אין נכסים יצירתיים חיצוניים: אין חבילות ספרייטים או טקסטורות, גופנים חיצוניים, אייקונים חיצוניים, דגימות קול, מוזיקה מוקלטת, תמונות מאגר או חומר מועתק. גם שמע הטריילרים הופק אך ורק מקוד הסינתזה הפרוצדורלי שנשלח במשחק, ללא דגימות, הקלטות או ספריות שמע חיצוניות. מקור הנכסים וה־SHA-256 שלהם מתועד ב־`ASSET_LICENSES.md`.

לפני הפצה יש לבדוק מחדש את קובצי ה־AAB, ה־IPA וה־Web המדויקים מול `COPYRIGHT.txt` של Godot ולהוסיף כל הודעת צד שלישי שנכללת בפועל. מסמך טרום־השקה זה אינו הוכחה שבוצעה בדיקת רישוי של קובץ חתום סופי.
