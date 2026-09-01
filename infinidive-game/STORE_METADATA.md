# INFINIDIVE Store Metadata

**Status:** DRAFT — DO NOT SUBMIT\
**Code snapshot:** `0.1.0` pre-release\
**Requirements reviewed:** 2026-09-01\
**Support contact:** `matanita44@gmail.com`

This file contains candidate English and Hebrew listing copy plus current official asset requirements. It does not mean that INFINIDIVE is store-ready, approved, uploaded, signed, or publicly available.

## Submission blockers and truth constraints

- Privacy and support pages exist only as repository files at `web_pages/privacy.html` and `web_pages/support.html`; no public HTTPS URLs are verified.
- Original brand sources and verified raster exports exist for the icon, wordmark, Google feature graphic, and social card. Five 1080×1920 real-runtime stills, a 17.2-second 1080×1920 H.264/AAC social-development trailer, and a 17.2-second 886×1920 H.264/AAC Apple-format technical candidate also exist. They remain development evidence: the still set has only five scenes, Apple needs accepted 6.9-inch still dimensions, and its preview requires recapture from a supported iPhone. The Play icon and feature raster dimensions/channels are verified below.
- Android presets target `com.matan.infinidive`, include a separate Gradle/AAB preset, and request only normal `android.permission.VIBRATE` for optional haptics. The verified template-install path creates `android/build`, but no compiled/signed AAB or internal-test upload is evidenced.
- The iOS preset uses `com.matan.infinidive`, targets iPhone, and wires exact-size RGB/no-alpha icons. A fresh reconciled-tree unsigned Xcode export at `../build/ios-iphone-current` passes structural identity/icon/placeholder checks; the checked-in Team ID remains blank and no Xcode compile/archive, signed install, or TestFlight upload is evidenced.
- There is no backend, cloud save, remote leaderboard, account, advertising, or purchase flow. Listing copy must not imply otherwise.
- Daily Rift and Friend Rift are local deterministic modes. Friend challenges are exchanged as codes through a player-directed clipboard action.
- English and Hebrew metadata drafts are complete here. The current code has matching non-empty English/Hebrew UI keys, translated launch catalogs, and headless RTL widget coverage; do not publish a Hebrew store localization until text fit, visual order, screenshots, and live language switching pass final device QA.
- The INFINIDIVE name, package ID, trademarks, and territory availability have not received legal clearance. Run naming and trademark checks before creating irreversible store records.
- Screenshots and video must be captured from the final reviewed binary and may show only functionality actually present in that build.

## Positioning

**Brand:** INFINIDIVE\
**Working tagline:** Fight giants outside. Destroy them within.\
**Primary category (provisional):** Games / Action\
**Secondary game category (provisional):** Arcade\
**Target form factor:** portrait iPhone and Android phone\
**Current business model:** no ads, purchases, subscriptions, or paid gameplay features are implemented

Factual product claims supported by the reviewed code:

- Touch-led portrait action with automatic fire and a rechargeable dash
- Exterior armor combat, breach opening, organ selection, an internal route, organ destruction, and return to an altered exterior attack set
- Four boss definitions with three organs each
- Five weapon behaviors and data-driven temporary mutation choices
- Local permanent progression and five Last Nest visual stages
- Local Story Descent, deterministic Daily Rift, Friend Rift codes, and an early endless Abyss Loop
- Local versioned saves and offline core play

Avoid claiming online leaderboards, cloud sync, multiplayer, video replay export, monetization, complete accessibility, device-validated Hebrew layout, physical-device performance, or store availability until those items have evidence.

## Current brand and gameplay-media evidence

| Artifact | Current evidence | Submission gap |
|---|---|---|
| `assets/brand/app_icon.svg`, three `assets/brand/android_adaptive_*.svg` layers, `assets/store/app-icon-1024.png`, and `assets/store/google-play-icon-512.png` | Original sources with recorded hashes; verified 1024×1024 RGB app raster and 512×512 8-bit/color RGBA Play raster; exact-size RGB iOS derivatives are wired in the preset | Validate small-size/adaptive/themed rendering, re-verify regenerated native catalogs, and complete final console-upload review |
| `assets/brand/wordmark.svg` and `assets/store/wordmark-2400.png` | Original path-based wordmark; verified 2400×630 RGBA raster with recorded SHA-256; no external font file | Verify final lockup, padding, contrast, and localizations where used |
| `assets/brand/feature_graphic.svg` and `assets/store/google-play-feature-1024x500.png` | Original composition plus verified 1024×500 8-bit/color RGB raster with no alpha | Dimension/channel requirement is met; retain final composition and console-upload review |
| `assets/brand/social_card.svg` and `assets/store/social-card-1200x630.png` | Original 1200×630 RGBA social key art with recorded SHA-256 | It is illustrative key art, not gameplay; do not use it as a screenshot |
| `assets/store/gameplay/*.png` | Five direct runtime captures at 1080×1920: Nest, exterior combat, breach, organ choice, and internal zone | Development/virtual-display evidence only; capture final RC, organ destruction/changed exterior/mutations/developed Nest/Friend/Abyss scenes, and Apple-accepted sizes |
| `assets/store/gameplay/trailer-runtime-dev-17s.mp4` | 17.2 seconds, H.264, 1080×1920, 30 fps, 516 frames, hard cuts from real runtime | Silent because capture used Dummy audio; not at Apple's accepted 6.9-inch preview resolution; not uploaded to an ad-free public/unlisted YouTube URL for Google |
| `assets/store/gameplay/trailer-runtime-social-17s.mp4` | 17.2 seconds, 1080×1920 H.264/30 fps plus 48 kHz stereo AAC rendered only from shipped procedural-audio code; SHA-256 `3950107d8ef89abffd42fec303f96ef5931a1c4139dcc771d91c17c7fa9c7103` | Virtual-display development capture; requires final listening/caption review and compliant YouTube publication before Google listing use |
| `assets/store/gameplay/trailer-runtime-apple-candidate-886x1920-17s.mp4` and poster | 17.2 seconds, 886×1920 H.264/30 fps plus 48 kHz stereo AAC; video SHA-256 `7559e8cd1a89820843cd66aa310e1d006cd390668f249ea08fd8b1587df5a1b8`; poster is 886×1920 RGB JPEG | Technical stream candidate only: Linux/Xvfb footage was scaled/padded, not captured on a supported iPhone; recapture and App Store Connect processing are required |
| `assets/store/gameplay/capture-manifest.json` | Records capture method, limitations, segment ranges, sizes, and SHA-256 hashes | Preserve and regenerate against the final committed release candidate |

`assets/store/gameplay/README.md` and `ASSET_LICENSES.md` are the provenance sources. None of this media is evidence of a physical-phone test or store acceptance.

## Apple App Store — English (U.S.)

### App information

| Field | Draft |
|---|---|
| Name | `INFINIDIVE` |
| Subtitle | `Destroy giants from within` |
| Primary category | Games |
| Subcategories | Action; Arcade |
| Privacy Policy URL | `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/privacy.html` — isolated branch fallback, not deployed/verified |

### Version information

**Promotional text**

> Break through colossal armor, dive into living anatomy, and destroy the organs powering each boss. Every choice reshapes the battle outside.

**Description**

> Every boss is also a world.
>
> INFINIDIVE is a portrait action roguelite built around one brutal idea: fight a colossal organism from the outside, tear open a breach, dive into its anatomy, and destroy the organs powering its deadliest attacks.
>
> Break rotating armor while dodging readable projectile patterns. Choose the organ causing the most trouble. Survive a short route through hostile tissue, destroy your target, then return outside and face a boss changed by what you removed.
>
> Shape each run with distinct weapons and temporary mutations. Bring Bio-Matter and Core Shards back to the Last Nest, improve permanent systems, unlock new tools, and watch your damaged refuge come alive.
>
> FEATURES
>
> • Fight four distinct colossi, each with three linked organs.
>
> • Wield five weapons with different firing behavior and tactical range.
>
> • Choose temporary mutations and permanent upgrades that change your approach.
>
> • Play Story Descent, a deterministic Daily Rift, shareable Friend Rift codes, and Abyss Loop.
>
> • Move with touch, fire automatically, and phase through danger with a rechargeable dash.
>
> • Play the core game offline with no required account.

**Keywords**

`action,roguelite,boss,space,shooter,offline,portrait,challenge,endless,arcade`

**What's New / initial release notes draft**

> Initial pre-release content: four colossi, five weapon styles, the outside-to-inside organ combat loop, permanent Nest progression, local Daily and Friend Rifts, and Abyss Loop. This text must be updated from the final release candidate before submission.

**Required URLs**

| Field | Status |
|---|---|
| Support URL | Isolated branch fallback: `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/support.html`; not deployed/verified |
| Privacy Policy URL | Isolated branch fallback: `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/privacy.html`; not deployed/verified |
| Marketing URL | Optional; leave blank until a real public page exists |

## Apple App Store — Hebrew (Israel)

### פרטי האפליקציה

| שדה | טיוטה |
|---|---|
| שם | `INFINIDIVE` |
| כותרת משנה | `השמידו ענקים מבפנים` |
| קטגוריה ראשית | משחקים |
| תתי־קטגוריות | פעולה; ארקייד |
| כתובת מדיניות פרטיות | `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/privacy.html` — יעד fallback מבודד לענף, טרם נפרס או אומת |

### פרטי הגרסה

**טקסט קידומי**

> פרצו דרך השריון של יצורי־ענק, צללו אל האנטומיה החיה שלהם והשמידו את האיברים שמפעילים את מתקפותיהם. כל בחירה משנה את הקרב בחוץ.

**תיאור**

> כל בוס הוא גם עולם.
>
> INFINIDIVE הוא משחק פעולה רוגלייט אנכי שבנוי סביב רעיון אחד: להילחם ביצור עצום מבחוץ, לקרוע פתח בשריון, לצלול לתוך האנטומיה שלו ולהשמיד את האיברים שמפעילים את המתקפות הקטלניות ביותר שלו.
>
> שברו שכבות שריון מסתובבות והתחמקו מדפוסי קליעים קריאים. בחרו באיבר שמסכן אתכם, שרדו מסלול קצר בתוך רקמה עוינת, השמידו את המטרה וחזרו החוצה אל בוס שהשתנה בגלל מה שהסרתם ממנו.
>
> עצבו כל ריצה בעזרת כלי נשק שונים ומוטציות זמניות. החזירו חומר ביולוגי ושברי ליבה אל הקן האחרון, שפרו מערכות קבועות, פתחו כלים חדשים וצפו במקלט ההרוס חוזר לחיים.
>
> תכונות
>
> • הילחמו בארבעה יצורי־ענק שונים, שלכל אחד מהם שלושה איברים מקושרים.
>
> • הפעילו חמישה כלי נשק בעלי התנהגות ירי וטווח טקטי שונים.
>
> • בחרו מוטציות זמניות ושדרוגים קבועים שמשנים את סגנון המשחק.
>
> • שחקו ב־Story Descent, באתגר Daily Rift דטרמיניסטי, בקודי Friend Rift שניתן לשתף וב־Abyss Loop.
>
> • נועו במגע, ירו אוטומטית ועברו דרך סכנה בעזרת דאש נטען.
>
> • שחקו בליבת המשחק ללא חיבור לרשת וללא חשבון חובה.

**מילות מפתח**

`אקשן,רוגלייט,בוסים,חלל,ירי,אתגר,אופליין`

**מה חדש / טיוטת הערות לגרסה הראשונה**

> תוכן טרום־השקה ראשוני: ארבעה יצורי־ענק, חמישה סגנונות נשק, לולאת הקרב מבחוץ אל תוך האיברים, התקדמות קבועה בקן, אתגרי Daily ו־Friend מקומיים ו־Abyss Loop. יש לעדכן את הטקסט לפי גרסת המועמד הסופית לפני הגשה.

**כתובות נדרשות**

| שדה | מצב |
|---|---|
| כתובת תמיכה | יעד fallback מבודד לענף: `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/support.html`; טרם נפרס או אומת |
| כתובת מדיניות פרטיות | יעד fallback מבודד לענף: `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/privacy.html`; טרם נפרס או אומת |
| כתובת שיווקית | אופציונלית; להשאיר ריק עד שקיים עמוד ציבורי אמיתי |

## Google Play — English (U.S.)

| Field | Draft |
|---|---|
| App name | `INFINIDIVE` |
| Short description | `Fight colossal bosses outside. Dive within and destroy their organs.` |
| Category | Game / Action |
| Contains ads | No — no ad SDK or ad placement exists in the reviewed code |

**Full description**

> Every boss is also a world.
>
> Fight a colossal organism from the outside, break its armor, open a breach, and dive into the anatomy powering its attacks. Destroy an organ, choose a temporary mutation, and return to an exterior battle changed by what you removed.
>
> Read the telegraphs, weave through projectile patterns, and use a rechargeable Phase Dash to cross danger. Five weapons offer different firing behavior, from rapid needles and close bursts to piercing shots, arcs, and orbitals.
>
> Bring Bio-Matter and Core Shards back to the Last Nest. Unlock weapons, improve permanent systems, and watch the damaged refuge rebuild through five visual stages.
>
> • Four colossi with three linked organs each
> • Outside, inside, and changed-outside boss combat
> • Temporary mutation builds and permanent progression
> • Story Descent and local deterministic Daily Rifts
> • Shareable Friend Rift challenge codes
> • Abyss Loop for escalating local runs
> • Portrait touch controls, automatic fire, and configurable dash input
> • Offline core play with no required account

**What's new draft**

> Initial pre-release content includes four bosses, five weapon styles, organ dives, Nest progression, local deterministic challenges, and Abyss Loop. Replace this note with release-candidate facts before upload.

## Google Play — Hebrew (Israel)

| שדה | טיוטה |
|---|---|
| שם האפליקציה | `INFINIDIVE` |
| תיאור קצר | `הילחמו בבוסים ענקיים מבחוץ, צללו פנימה והשמידו את איבריהם.` |
| קטגוריה | משחק / פעולה |
| כולל פרסומות | לא — בקוד שנבדק אין SDK או מיקום לפרסומות |

**תיאור מלא**

> כל בוס הוא גם עולם.
>
> הילחמו ביצור עצום מבחוץ, שברו את השריון שלו, פתחו פרצה וצללו אל האנטומיה שמפעילה את מתקפותיו. השמידו איבר, בחרו מוטציה זמנית וחזרו לקרב חיצוני שהשתנה בגלל מה שהסרתם.
>
> קראו את סימני האזהרה, השתחלו בין דפוסי קליעים והשתמשו ב־Phase Dash נטען כדי לחצות סכנה. חמישה כלי נשק מציעים התנהגויות ירי שונות: ממחטים מהירות ומטחי טווח קצר ועד יריות חודרות, קשתות וכלי נשק מסלוליים.
>
> החזירו חומר ביולוגי ושברי ליבה אל הקן האחרון. פתחו כלי נשק, שפרו מערכות קבועות וצפו במקלט ההרוס נבנה מחדש בחמישה שלבים חזותיים.
>
> • ארבעה יצורי־ענק עם שלושה איברים מקושרים לכל אחד
> • קרבות בוס מבחוץ, מבפנים ושוב מבחוץ לאחר שינוי ממשי
> • שילובי מוטציות זמניות והתקדמות קבועה
> • Story Descent ואתגרי Daily Rift מקומיים ודטרמיניסטיים
> • קודי אתגר Friend Rift שניתן לשתף
> • Abyss Loop לריצות מקומיות שהולכות ומקשות
> • שליטת מגע אנכית, ירי אוטומטי ושיטות דאש לבחירה
> • משחק ליבה ללא חיבור לרשת וללא חשבון חובה

**טיוטת מה חדש**

> תוכן טרום־השקה ראשוני כולל ארבעה בוסים, חמישה סגנונות נשק, צלילות לאיברים, התקדמות בקן, אתגרים מקומיים דטרמיניסטיים ו־Abyss Loop. יש להחליף את הטקסט בעובדות מגרסת המועמד הסופית לפני העלאה.

## Draft field counts

Counts below were measured from the copy in this file on 2026-09-01. Re-count after every edit; the store console is the final authority. App Store keywords are measured in UTF-8 bytes because Apple's current limit is byte-based.

| Store/localization | Name | Subtitle / short description | Promotional text | Full description | Keywords |
|---|---:|---:|---:|---:|---:|
| App Store English | 10 characters | 26 characters | 140 characters | 1,158 characters | 77 bytes |
| App Store Hebrew | 10 characters | 19 characters | 126 characters | 950 characters | 72 bytes |
| Google Play English | 10 characters | 68 characters | n/a | 1,053 characters | n/a |
| Google Play Hebrew | 10 characters | 58 characters | n/a | 887 characters | n/a |

## Screenshot narrative and captions

Capture these only after the corresponding feature is visually complete in the release candidate. Use actual gameplay and localize any added overlay text.

| Order | Required scene | English caption | Hebrew caption |
|---:|---|---|---|
| 1 | Readable exterior boss combat | Fight a living giant | הילחמו בענק חי |
| 2 | Breach and dive transition | Break through. Dive within. | פרצו פנימה. צללו לעומק. |
| 3 | Organ chamber and organ destruction | Destroy the organ powering its attack | השמידו את האיבר שמפעיל את המתקפה |
| 4 | Exterior attack removed after return | Return to a boss you changed | חזרו אל בוס שכבר שיניתם |
| 5 | Mutation choice and active build | Build a new mutation combo each run | צרו שילוב מוטציות חדש בכל ריצה |
| 6 | A visibly developed Last Nest | Rebuild the Last Nest | שקמו את הקן האחרון |
| 7 | Friend Rift code/result context | Share the same Friend Rift | שתפו את אותו אתגר חברים |
| 8 | Abyss Loop depth/result | Descend deeper in Abyss Loop | צללו עמוק יותר ב־Abyss Loop |

## Privacy-form draft for the reviewed binary

Do not submit these answers until the final signed artifacts are inspected.

### Apple App Privacy

- Candidate answer: **Data Not Collected**
- Tracking: **No**
- Reason: saves, settings, deterministic challenge data, and the optional analytics queue stay on device; no upload transport or third-party tracking SDK is present.
- Change the answer if any final SDK or feature transmits analytics, diagnostics, identifiers, purchases, accounts, leaderboards, cloud saves, or other user data.

### Google Play Data safety

- Candidate answer to collection/sharing: **No data collected or shared by the app** under Google's off-device definition.
- Ads: **No**
- Required account: **No**
- Data deletion URL for an account: not applicable because no account can be created.
- Re-audit the generated AAB manifest and libraries. Google requires the form to represent the union of practices in all versions active under the package name.

See `PRIVACY_DATA_MAP.md` for the field-level evidence and the separate treatment of voluntary support email and future web-host request logs.

## Content-rating preparation

No final numeric age rating is claimed. Apple generates a rating from its App Store Connect questionnaire; Google Play uses questionnaire responses to generate regional IARC ratings.

Review the final build for:

- Stylized fantasy violence against non-human colossal organisms
- Biopunk body/anatomy and potentially frightening horror imagery
- Organ destruction and combat intensity, including frequency and visual detail
- No sexual content, nudity, profanity, drugs, gambling, or realistic human violence in the reviewed code
- No ads or purchases in the reviewed code
- No in-app chat, public profile, or native user-generated-content exchange; Friend Rift codes are copied for player-directed sharing through external apps
- Not specifically designed for young children; do not select a children's target audience without a separate policy review

Retake both questionnaires whenever art, audio, social functionality, ads, purchases, or user communication changes.

## Current official metadata and asset requirements

The following was checked against primary platform documentation on 2026-09-01. Platform rules can change; verify again inside App Store Connect and Play Console immediately before upload.

### Apple

| Item | Current official requirement relevant to this project | Production action |
|---|---|---|
| App name | 2–30 characters | `INFINIDIVE` fits; confirm name availability before app-record creation |
| Subtitle | Maximum 30 characters | Both drafts fit; re-count after copy edits |
| Promotional text | Maximum 170 characters | Both drafts fit; optional and localizable |
| Description | Maximum 4,000 characters, plain text; HTML is not supported | Keep the localized field plain text |
| Keywords | Maximum 100 bytes; each keyword more than two characters; do not use other app/company names | English and Hebrew drafts are provisional; re-count UTF-8 bytes in App Store Connect |
| Support URL | Required and must lead to real contact information | Publish the support page over HTTPS before submission |
| Privacy Policy URL | Required for iOS | Publish the privacy page over HTTPS before submission |
| App icon source | iOS/iPadOS layout size 1024×1024 px; included through the Xcode asset catalog or Icon Composer | Original 1024 source plus exact-size RGB/no-alpha iOS icon set is wired in the preset and verified in the reconciled-tree Xcode export; validate small sizes and inspect the final signed archive |
| iPhone screenshots | 1–10; `.jpeg`, `.jpg`, or `.png`; no alpha/transparency | Capture eight real portrait scenes after RC freeze |
| 6.9-inch iPhone portrait sizes | 1260×2736, 1290×2796, or 1320×2868 px | Existing 1080×1920 development stills do not qualify; recapture an accepted 6.9-inch set |
| 6.5-inch iPhone portrait sizes | 1284×2778 or 1242×2688 px; required only if a 6.9-inch set is not provided | Not separately required if accepted 6.9-inch screenshots are supplied; verify in Connect |
| iPad screenshots | 13-inch screenshots are required if the app runs on iPad | Current iOS preset targets iPhone only; reassess if device family changes |
| 6.9-inch iPhone App Preview | H.264 or ProRes 422 HQ; 15–30 seconds; maximum 500 MB; portrait 886×1920 px; maximum 30 fps; stereo audio; up to 3 previews | The technical candidate meets the recorded resolution/codec/duration/fps/stereo-audio contract locally, but its underlying Linux/Xvfb capture is not submission-ready. Recapture from the release candidate on a supported iPhone and validate in App Store Connect. |

### Google Play

| Item | Current official requirement relevant to this project | Production action |
|---|---|---|
| App name | Maximum 30 characters | `INFINIDIVE` fits |
| Short description | Maximum 80 characters | Both drafts fit; re-count after edits |
| Full description | Maximum 4,000 characters | Both drafts fit |
| App icon | 512×512 px, 32-bit PNG with alpha, maximum 1,024 KB | Dedicated raster is 512×512, 141,587 bytes, 8-bit/color RGBA. Recorded format/dimension/size requirements pass; final visual and console-upload review remain |
| Feature graphic | Required; 1024×500 px; JPEG or 24-bit PNG without alpha | Verified raster is 1024×500, 79,388 bytes, 8-bit/color RGB with no alpha; perform final visual/console validation |
| Screenshots | Up to 8 per supported device type; at least 2 across device types; JPEG or 24-bit PNG without alpha; each dimension 320–3,840 px; longest side no more than twice the shortest | Five real 1080×1920 RGB development stills satisfy basic phone format/dimensions; recapture the final eight-scene RC narrative |
| Game recommendation surfaces | At least 3 portrait 9:16 screenshots at minimum 1080×1920, or at least 3 landscape 16:9 screenshots at minimum 1920×1080 | Use portrait 1080×1920 or larger for this portrait-first game |
| Screenshot text | Actual experience; localized overlays; taglines should occupy no more than 20% of an image | Keep gameplay dominant and create separate English/Hebrew sets if captions are baked in |
| Preview video | Optional; one YouTube video URL; public or unlisted, not private; ads off; not age-restricted; embeddable; portrait and landscape supported | The 1080×1920 social-development edit has project-generated stereo audio but is local and unreviewed; complete listening/caption review, then upload under the required YouTube settings |

## Official sources

Reviewed 2026-09-01:

### Apple Developer

- App information limits and required privacy URL: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
- Version metadata, promotional text, description, keywords, and support URL: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- App preview specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/
- App icon guidance and layout sizes: https://developer.apple.com/design/human-interface-guidelines/app-icons
- App Privacy definitions: https://developer.apple.com/app-store/app-privacy-details/
- Age-rating values and questionnaire model: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/

### Google Play Console Help

- App name and description limits: https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
- Preview assets, icon, feature graphic, screenshots, and video: https://support.google.com/googleplay/android-developer/answer/9866151?hl=en
- Data safety definitions and form guidance: https://support.google.com/googleplay/android-developer/answer/10787469?hl=en
- Content rating requirements and questionnaire: https://support.google.com/googleplay/android-developer/answer/9859655?hl=en
- Metadata policy: https://support.google.com/googleplay/android-developer/answer/9898842?hl=en

## Final pre-submission metadata checks

1. Inspect the exact signed IPA archive and AAB, including permissions and third-party libraries.
2. Confirm public HTTPS support and privacy URLs on mobile Safari and Chrome.
3. Replace every pre-release note with facts from the release candidate.
4. Run trademark/name checks and confirm the final seller/developer identity.
5. Capture real screenshots at accepted dimensions from the final binary; verify every pictured feature.
6. Localize baked-in screenshot captions and validate Hebrew direction, glyphs, and clipping.
7. Complete Apple privacy/age-rating and Google Data safety/IARC forms from the final content.
8. Verify metadata counters in each store console, which is the final authority.
9. Do not select Made for Kids or a child target audience without a dedicated policy review.
10. Do not claim release readiness until signed installs and store-review evidence exist.
