# INFINIDIVE

**Fight giants outside. Destroy them within.**

INFINIDIVE is a portrait-oriented mobile action roguelite built with Godot 4. The player breaks a colossus's exterior armor, opens a breach, chooses an internal organ, fights through a short seeded route, destroys the organ, and returns to an exterior battle changed by that loss.

> **Current status:** version `0.1.0` is a playable pre-alpha production foundation, not a release candidate. The source candidate is committed as `8e4be78267a043072827963d6492c7964239ae94`. GitHub Actions run [33514397476](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476) passed all eight validation suites, current-commit Web export/Chromium boot smoke, and Android debug export. Deploy job [99878161111](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476/job/99878161111) still failed because the integration could not create the Pages site. There is no verified public playable deployment, live backend transport, production-signed native build, store submission, simulator install, or physical-device QA evidence yet.

## What currently works

- A complete coded outside -> breach -> organ choice -> inside -> organ destruction -> mutation -> outside loop.
- Three exterior armor phases followed by a final core phase.
- Player drag movement with an 82-pixel finger offset, automatic fire, shields, damage, and Phase Dash.
- Dedicated-button, double-tap, and flick dash input paths.
- Four boss definitions with three organs each, distinct procedural silhouettes, palettes, and attack-ability sets. All 12 organs now declare a validated loss contract: seven replace the intact attack with a safer degraded pattern, five shut it down, and every loss publishes a unique exterior visual state plus English/Hebrew result copy.
- Five weapon definitions with pulse, scatter, rail, arc, and orbital runtime behavior.
- Seeded mutation offers without duplicate selections.
- A catalog of 24 mutations, 18 permanent upgrades, 30 non-chamber room modules, and 12 organ chambers.
- Explicit runtime contracts and behavioral tests for all 42 mutation effect keys and all 18 permanent-upgrade effect keys, including Forge prerequisites.
- A ten-step, event-driven tutorial with persistent comprehension state and replay presentation that survives the Run-to-Nest Forge handoff.
- Forty-two validated room/chamber contracts with deterministic schedules, full warning windows, safe gaps, bounded active waves, and cleanup; live presentation still collapses them to three broad execution geometries.
- The Last Nest with six facilities and five visual restoration stages.
- Fourteen offline achievements and nineteen rotating offline contracts, shown in the Trophy Chamber and Rift Terminal.
- Local Story Descent, deterministic Daily Rift, offline Friend Rift codes, and an early Abyss Loop flow.
- Versioned local saves with checksum validation, temporary-file promotion, backup rotation, migration, and backup recovery.
- English and Hebrew string tables, audio controls, haptics, screen-shake control, projectile contrast, handedness, and control sensitivity.
- Native and Web safe-area inset adapters are wired into the Nest and run HUD; their math is tested, but notch/Dynamic Island behavior has not been validated on a real browser or device.
- Original procedural sound effects plus three-layer adaptive music across nine states and four boss tonal identities.
- Original code-native brand sources plus development raster exports for the icon, wordmark, feature graphic, and social card, including three original Android adaptive-icon SVG layers.
- Five truthful 1080×1920 runtime stills, a 17.2-second 1080×1920 H.264/AAC social-development trailer, and an 886×1920 Apple-format technical candidate with retained capture, audio, limitations, and SHA-256 provenance. All were produced from a Linux virtual-display run; the Apple candidate still requires recapture from a supported iPhone before submission and none is physical-device QA.
- An opt-in, vendor-neutral analytics event queue that remains local; no analytics transport is connected.
- Fail-closed local configuration plus a validated, checksummed offline leaderboard outbox. Completed Daily/Friend runs queue bounded summaries under canonical challenge IDs; Story/Abyss results remain local-only and do not consume the outbox. No account, network transport, server verification, or online leaderboard is connected.
- A confirmed Reset Progress flow in Settings. After confirmation it replaces the versioned profile and recovery backup with clean defaults and idempotently clears the local analytics queue plus the Daily/Friend leaderboard primary, backup, and temporary files.

The data counts and effect contracts above are real, but the room system still shares three broad execution geometries and one generic defender rather than providing 42 bespoke spatial scenes. Automated playback proves timing/bounds invariants, not human reachability or authored visual fidelity. Human balance, browser, and device validation remain outstanding. See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) before treating content counts as release-complete.

## Controls

- **Move:** drag anywhere in the combat field. The craft follows above the finger.
- **Fire:** automatic during active combat; aim selection prefers internal defenders before the boss or organ.
- **Phase Dash:** use the on-screen button by default. Double-tap and quick-flick modes are selectable in Settings.
- **Dive:** tap `DIVE NOW` after breaking the current armor phase, then choose an organ.
- **Web/desktop test input:** Godot emulates touch from the mouse. Space/controller-dash and Escape/controller-pause entries exist in the InputMap, but the gameplay scripts do not currently consume those actions; use the on-screen controls.

## Run locally

Use Godot `4.7.2-stable`, which matches `project.godot` and the workflow configuration.

```bash
GODOT=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --editor --path .
```

The repository-local executable used for the latest evidence was outside this project directory at:

```text
/workspace/scratch/2209a1fdf3a0/.runtime/Godot_v4.7.2-stable_linux.x86_64
```

That path is workspace-specific and must not be assumed on another machine.

## Run the headless tests

From `infinidive-game/`:

```bash
GODOT=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
test_data_root=$(mktemp -d)
INFINIDIVE_TEST_ISOLATED=1 \
XDG_DATA_HOME="$test_data_root" \
  "$GODOT" --headless --path . --scene res://tests/TestRunner.tscn
```

The main suite intentionally fails closed without both `INFINIDIVE_TEST_ISOLATED=1` and an isolated temporary `XDG_DATA_HOME`; never point it at a player's normal `user://` profile.

The latest local evidence at `artifacts/headless-tests.xml` reports:

```text
2,538 assertions, 0 failures
```

The main suite validates data counts and IDs; all organ-order permutations; malformed and fuzzed challenge codes; deterministic mutation offers; mutation/weapon runtime behavior; localization and RTL widgets; analytics opt-out; safe-area math; deterministic room generation; pooled projectile collision; 30/60 Hz movement consistency; dash, shields, save recovery/migration/banking; full Reset Progress cleanup; live telegraph-avoidance observation; rate-limited combat-audio call sites; the first outside-inside-outside hook; 24 deterministic full-victory simulations; and a real UI failure/progression loop. That loop dies, banks the 55 Bio-Matter failure floor, returns to the Nest, buys Reinforced Hull in the Forge, starts a 110-HP run, dies again, presses instant retry, and verifies the saved profile in a separate Godot process. Seven focused suites additionally pass: backend/offline (`82`), permanent upgrades (`120`), tutorial (`198`), room mechanics (`2,583`), meta goals (`111`), adaptive audio (`505`), and organ transformations (`325`). Across the eight invocations, the latest local result is **6,462 assertions and 0 failures**. A current-tree 90.02-second structural soak also passed 1,563 pressure/projectile cycles, 157 restarts, 157 Dive transitions, 78 save writes, and 676 offline events with a 540-projectile peak, unchanged source fingerprint, and zero failures; the older 30-minute soak remains snapshot-only evidence. None of this proves human control feel, browser compatibility, target-device performance, native installation, production signing, background/force-close safety, an update from a previously shipped build, repeated Abyss depths, or physical-device behavior.

## Export Web locally

The checked-in `Web` preset writes a normal export to `../build/web/`. The separately retained, freshly reconciled evidence build documented below is at `../../build/web/` relative to this file:

```bash
GODOT=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --path . --export-release Web
```

A local export of commit `8e4be78267a043072827963d6492c7964239ae94` contains `index.html` (2,618 bytes; SHA-256 `190b5852ff3c94b4d2e6ce2849bdbc92cb64e77c6cb972d35165b9cf544713b5`), `index.pck` (440,384 bytes; SHA-256 `f9acf67d893ab6513f2b7fde450fcd2129331ba8252b3464132d94892b85b9d4`), `index.wasm` (39,514,754 bytes; SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`), worklets, and generated icons. Static validation passes and confirms that build tooling and adaptive-icon sources are excluded. Separately, current-commit Web job [99877839855](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476/job/99877839855) passed and exported the same file sizes; it retained Pages artifact `9803007777` and browser-smoke artifact `9803006599`. CI-served Chromium returned HTTP 200, started Godot 4.7.2 with WebGL2, created a 540×960 canvas, hid the loading status, and recorded no page errors. The local hashes above identify the local export; no remote Web hash is inferred from matching sizes. CI copies `web_pages/support.html` and `web_pages/privacy.html` beside the game. Settings opens those relative paths on Web, so the links remain valid below a repository-specific Pages base path. Native builds target the isolated branch-fallback pages at `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/support.html` and `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/privacy.html`; the game, support page, and privacy page currently return HTTP 404 there and no game canvas is present.

Native evidence is development-only:

- `../../build/android/infinidive-debug.apk` is the local commit-candidate export: 28,878,673 bytes with SHA-256 `2d3d5fa6f283381fd31aa1702df2cc697c80f12d0d7a96e6c1e22b59c33cdcef`. It passes package/version, min 24/target 36, arm64 portrait, exact-permission, alignment, Debug v2/v3, and adaptive-icon validation. The local exporter warned that it fell back to installed build-tools 34.0.4 while targeting SDK 36. Separately, current-commit Android job [99877839931](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476/job/99877839931) passed using build-tools 36 and produced debug APK SHA-256 `9b981f4d0accc600ef8f869e600b16f5585533ea1fe4cf8c71a983cfbdd87172` in artifact `9802998519`. Neither APK is a Play release AAB, and neither has been installed on an emulator or physical device.
- A full current-tree iOS project re-export failed because the preset has no Apple Development Team ID. The retained 47-file `../../build/ios-iphone-current/INFINIDIVE.xcodeproj` scaffold was therefore not regenerated. A separate `--export-pack iOS` operation did refresh only its current-tree code payload: PCK 440,480 bytes with SHA-256 `ac426ba74dd8993ea129448d2258d4f1b36ea3ee2fd48c28fd342bda53401db6`. The unchanged earlier scaffold retains `project.pbxproj` SHA-256 `dbbc0f658d31f09a8ad0b020a4ef1d1f6072e422088d13c996dd0d09ee7748bb` and 411-byte `INFINIDIVE/export_options.plist` SHA-256 `50c3cbc7d11c6c3c37357dc14e59ef93f1c011897467a9b94bb11637a795ea7d`. No Team is configured, and the project has not been compiled, signed, archived, simulator-run, installed, or uploaded to TestFlight.

`export_presets.cfg` now includes a separate Gradle `Android AAB` preset targeting `../build/android/infinidive-release.aab`, without replacing the debug-APK preset. The verified CI installer extracts Godot's `android_source.zip`, and the debug-export command uses `--install-android-build-template`; an integrated dry run created `android/build`. No AAB has been produced: Gradle dependencies still need to resolve in a complete SDK/build-tools 36 environment, and release signing requires the owner's private upload/release keystore. Full iOS re-export/archive/sign/TestFlight work requires macOS, Xcode, the owner's Apple Team ID, certificates, and provisioning; `--export-pack` evidence proves only the refreshed PCK payload.

## Project map

```text
data/                  JSON definitions for bosses, weapons, mutations, upgrades, and rooms
assets/brand/          Original SVG brand/store-art sources and provenance
assets/store/          Development raster exports and truthful runtime capture evidence
scenes/main/           Godot boot scene
scripts/core/          Deterministic challenge, mutation, organ, and room systems
scripts/gameplay/      Run state machine, player, boss visuals, and projectile pool
scripts/services/      Data, save, settings, localization, analytics, offline leaderboard/config, and audio autoloads
scripts/ui/            Nest, combat HUD, boot coordinator, and visual theme
tests/                 Headless test runner
artifacts/             Latest local JUnit-style test evidence
web/                   Custom Godot Web shell
web_pages/             Static bilingual privacy and support drafts
export_presets.cfg     Web, Android, and iOS export configuration
```

For system boundaries and state flow, read [ARCHITECTURE.md](ARCHITECTURE.md). For current evidence and blockers, read [PROJECT_STATUS.md](PROJECT_STATUS.md). Release gates are tracked in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md). Current privacy behavior, draft store copy, legal draft, and runtime notices are recorded in [PRIVACY_DATA_MAP.md](PRIVACY_DATA_MAP.md), [STORE_METADATA.md](STORE_METADATA.md), [TERMS.md](TERMS.md), and [OPEN_SOURCE_NOTICES.md](OPEN_SOURCE_NOTICES.md).
