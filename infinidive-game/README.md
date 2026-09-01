# INFINIDIVE

**Fight giants outside. Destroy them within.**

INFINIDIVE is a portrait-oriented mobile action roguelite built with Godot 4. The player breaks a colossus's exterior armor, opens a breach, chooses an internal organ, fights through a short seeded route, destroys the organ, and returns to an exterior battle changed by that loss.

> **Current status:** version `0.1.0` is a playable, publicly deployed pre-alpha production foundation, not a release candidate. Runtime-evidence commit [`380b6d4b632e9d507ea42075714d0f18d6cdb74f`](https://github.com/matanita44-sudo/claude-builders-bounty/commit/380b6d4b632e9d507ea42075714d0f18d6cdb74f) passed GitHub Actions run [33565500042](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33565500042): strict validation, Web export/CI Chrome boot, Android debug export/validation, Pages deploy job [`100049011404`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33565500042/job/100049011404), and public-host smoke job [`100049076641`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33565500042/job/100049076641) all passed. The long-soak job was skipped by design because validation first accepted the retained, source-bound 1,800.043-second report from run [33559947112](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33559947112). The latest public-smoke artifact `9823113363` is 90,667 bytes with SHA-256 `5038d055d8cf723b479424b4d099d0e3c036bb4e9eb325cb9c1ee6e00b750985`; it records HTTP 200, a live 540×960 Godot canvas, zero page/console errors, canvas `touchstart`/`touchmove`/`touchend` counts of 3/3/3, and a rendered-frame change from `31212c7891fccbb64e3993062614178a854ac29b185878ee1a5db2963ccf2e23` to `94e6d2654a466e0ecb37670e6621d2b873eb5c9c56c39a5565ea2f38afa0b6d8`; the retained final screenshot visibly shows gameplay with Phase at 89%. This proves that synthetic events reached the canvas, the live game stayed running, and its rendered frame changed—not that the entire intended control path was semantically accepted, nor human control feel, mobile Safari/Chrome behavior, simulator behavior, or physical-device behavior. There is no live backend transport, production-signed native build, store submission, simulator install, or physical-device QA evidence yet.

## What currently works

- A complete coded outside -> breach -> organ choice -> inside -> organ destruction -> mutation -> outside loop.
- Three exterior armor phases followed by a final core phase.
- Player drag movement with an 82-pixel finger offset, automatic fire, shields, damage, and Phase Dash.
- Dedicated-button, double-tap, and flick dash input paths.
- Four boss definitions with three organs each, distinct procedural silhouettes, palettes, and attack-ability sets. All 12 organs now declare a validated loss contract: seven replace the intact attack with a safer degraded pattern, five shut it down, and every loss publishes a unique exterior visual state plus English/Hebrew result copy.
- Five weapon definitions with pulse, scatter, rail, arc, and orbital runtime behavior.
- Seeded mutation offers without duplicate selections. If all 24 mutations are already owned, mutation choice exits deterministically, awards a visible localized 120 Bio-Matter fallback, and cannot soft-lock. Near exhaustion, a reroll whose exclusion window would empty the offer pool reuses the remaining legal unselected pool, consumes one reroll, stays in `MUTATION_CHOICE`, and grants no fallback reward.
- A catalog of 24 mutations, 18 permanent upgrades, 30 non-chamber room modules, and 12 organ chambers.
- Explicit runtime contracts and behavioral tests for all 42 mutation effect keys and all 18 permanent-upgrade effect keys, including Forge prerequisites.
- A ten-step, event-driven tutorial with persistent comprehension state and replay presentation that survives the Run-to-Nest Forge handoff.
- Forty-two validated room/chamber contracts with deterministic schedules, full warning windows, safe gaps, bounded active waves, and cleanup. Their live plans span eight runtime categories, six movement models, 25 projectile profiles, and ten defender archetypes.
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

The data counts and effect contracts above are real. The room runtime now executes the authored structural, projectile, movement, and defender identities instead of reducing them to a generic executor; it is still a code-drawn system, not 42 bespoke art scenes. Automated playback proves the named timing, geometry, preview, ownership, collision, and cleanup invariants, not human reachability, visual clarity, or fun. Human balance, browser, and device validation remain outstanding. See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) before treating content counts as release-complete.

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
2,631 assertions, 0 failures
```

The main suite validates data counts and IDs; all organ-order permutations; malformed and fuzzed challenge codes; deterministic mutation offers, full-catalog exhaustion, and near-exhaustion rerolls; mutation/weapon runtime behavior; localization and RTL widgets; analytics opt-out; safe-area math; deterministic room generation; pooled projectile collision; 30/60 Hz movement consistency; dash, shields, save recovery/migration/banking; lifecycle pause/save locking; full Reset Progress cleanup; live telegraph-avoidance observation; rate-limited combat-audio call sites; the first outside-inside-outside hook; 24 deterministic full-victory simulations; and a real UI failure/progression loop. That loop dies, banks the 55 Bio-Matter failure floor, returns to the Nest, buys Reinforced Hull in the Forge, starts a 110-HP run, dies again, presses instant retry, and verifies the saved profile in a separate Godot process.

The final frozen local matrix passed **28,410 assertions and 0 failures across 13 suites**: main `2,631`; backend/offline `82`; permanent upgrades `120`; tutorial `198`; room mechanics `3,541`; room compiler `15,515`; pure defender effects `354`; live defender effects `212`; projectile travel `685`; live room integration `4,131`; organ transformations `325`; meta goals `111`; and adaptive audio `505`. The six room-runtime suites contribute `24,438/0`. Editor import and every suite passed through the strict wrapper with zero `ERROR`, script-error, or parse-error lines. The current inventories are fingerprinted as production `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382` and tracked tests/CI `e0af48b5b24e2333c928e685eccd12991c22f05d4cd8c37dc1c08f926bcb756b`. Current contracts include compiler-signed owner/cycle cleanup; lane indices bounded by each movement topology; a frozen full-projectile preview signed into the execution payload; removal of actually homing owned threats when tracking is suppressed rather than silently straightening them; 30/60/120 Hz player-homing consistency; swept collision before lifetime/bounds retirement and in physical first-contact order; nonlinear/homing collision subsegments even when no safe-zone metadata is present; and terminal retirement at the first arena exit, including the exact `16/3s` node-link hitch case. Internal routes and organ chambers restore movement/Dash after organ selection, hidden touches during disabled control are ignored, and pause/resume keeps controls locked throughout `DIVING_IN`, `DIVING_OUT`, and `MUTATION_CHOICE`. A paused `BREACH_OPEN` also rejects `_request_dive()` without replacing the pause overlay; after manual resume the same legal Dive path works. Full ownership of all 24 mutations exits the choice state deterministically and grants a visible localized 120 Bio-Matter fallback; a near-exhaustion reroll instead reuses the remaining legal unselected pool, consumes one reroll, stays in `MUTATION_CHOICE`, and grants no reward. The English and Hebrew string tables contain the fallback result key. Application `PAUSED`/`FOCUS_OUT` notifications synchronously and idempotently pause, lock controls, and force a save; `RESUMED`/`FOCUS_IN` only resynchronize state, so manual resume remains required. Headless regression verifies the persisted marker and locked controls, but this is not physical mobile suspend/resume evidence.

The workflow runs every discovered standalone suite through an isolated strict wrapper: a nonzero process exit, any engine `ERROR`, script/parse error, missing exact result sentinel, assertion-count drift, stale inventory entry, or invalid/missing soak report pair fails the job. The soak writer stages JSON and Markdown as a two-phase transaction, validates the complete schema and semantic coverage, binds the exact Markdown SHA-256 into JSON, and marks `report_transaction_complete` only after cleanup succeeds. It preserves or restores the previous complete pair symmetrically, accepts positive fractional durations, and persists partial/early or source-change diagnostic `FAIL` evidence without allowing it to qualify as `PASS`. Failure injection covers both sides of open, write, verify, first/second commit, and cleanup plus truncated and mixed primary/backup pairs. CI independently recomputes the current production fingerprint, rejects stale reports/recovery pairs, self-tests `PASS`/diagnostic and strict negative fixtures, and requires an exact JSON/Markdown result, transaction, completion marker, bound hash, requested duration, and semantic exercise contract.

The regenerated 8.031-second smoke passed 86 cycles, nine restarts and Dives, six saves, 529 queued offline events / two queue reloads / final queue 500, all seven requested projectile-model counts exactly matching executed counts, peak 540 projectiles, and unchanged fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`. Its transaction is `9ac05a1b4bcc696001e5a6e7`; the 3,069-byte JSON SHA-256 is `d8d5c6c5b0667f3b53844839f5955841430e85842ea168220c1a0d8ca4b5c1e9`, and the 1,062-byte Markdown/bound SHA-256 is `9ba26093ba394c70b591130544a21094e719d0801d55755d82fd0e5c93814c27`. The regenerated 90.048-second soak passed 1,169 cycles, 117 restarts and Dives, 60 saves / one save reload, 637 queued offline events / three queue reloads / final queue 500, 7/7 models, peak 540, stable-memory delta 90,040 bytes, slope 218,786.041893738 B/min, the same unchanged fingerprint, and zero failures. Its transaction is `26dad83d28067418d76982a3`; the 5,487-byte JSON SHA-256 is `2bc054556fe9e0c75813feb7e50dfcae5844c8140e4491bfd599e9129309c4c1`, and the 1,075-byte Markdown/bound SHA-256 is `026962ed338b02db99cfee0ecb08bc16b197c9b2abd1544214e11ed61e69ab83`.

The current-source 30-minute CI soak in run [33559947112](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33559947112), job [`100030992601`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33559947112/job/100030992601), passed for 1,800.043 seconds with seed 203541. It completed 26,676 iterations/projectile cycles, 2,668 boss restarts and Dives, 1,335 save writes / 22 save reloads, 3,188 queued offline events / 24 queue reloads / final queue 500, peak 540 projectiles, 7/7 exact requested-versus-executed models, stable-memory delta 3,667,676 bytes, slope 84,517.9971965645 B/min, and zero failures. Its start and end fingerprints both equal `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`; transaction `5c047f1a630e8e1de5c5ffff` is complete. Artifact `9822001845` is 9,042 bytes as a ZIP with SHA-256 `f93bd2c76a640c8cc2ccbc80593112752bf625298f00af86037091c667b7d29c`; inside it, the 53,857-byte JSON hashes to `2f8171e8317572f31fd479884edcaa441452082640a9be4f3fe9339da02710b4`, and the 1,091-byte Markdown/bound report hashes to `a508864e78c75981e8221df2c53f0ed97c82501295e999328fa86b78970f1856`. The production fingerprint intentionally excludes `assets/store/gameplay/raw/`: that directory is local-only, non-exported capture provenance rather than executable product source. None of these Linux headless structural soaks proves human control feel, browser compatibility, target-device FPS, thermals, battery, GPU behavior, native installation, production signing, background/force-close safety, an update from a previously shipped build, repeated Abyss depths, or physical-device behavior.

## Export Web locally

The checked-in `Web` preset writes a normal export to `../build/web/`. The verified frozen packages are retained under `../build/final-0.1.0-e942db6f/`:

```bash
GODOT=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --path . --export-release Web
```

The final Web export contains `index.html` (2,618 bytes; SHA-256 `65c3d9b290b3b3eb4baab5e8d677edee04ea3d0f4dc8331cf792e275a30c9f61`), `index.js` (279,815; `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba`), `index.pck` (625,812; `33283d7cfcf37fc5b1b5ccd5f77254766839bb674f9c8e1bd50cb7c3640ed43d`), and `index.wasm` (39,514,754; `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`). Static validation and local HTTP root/privacy/support/WASM/PCK checks passed. Run [33565500042](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33565500042) then validated and deployed runtime-evidence commit `380b6d4b632e9d507ea42075714d0f18d6cdb74f`; the [game](https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/), privacy, support, PCK, and WASM returned HTTP 200. Its public-host smoke delivered synthetic tap/drag/Dash events to the canvas, observed 3/3/3 touch start/move/end events, retained distinct before/after frames, and finished with a live gameplay frame and zero errors. The public privacy and support response bodies now match the corrected source/package hashes `81cf55f7f9e4c18a9c3a611593f358597020e93e61e594d89da482fd80bae17e` and `283e82c98eb26180c6426b2d9fcba919f0546eec8ea714f487b1eb5c50a802b2`. This is narrow synthetic Chromium evidence; semantic acceptance of every intended action, reload persistence, mobile-browser behavior, human feel, and physical-device behavior remain unproven.

Packaged evidence is development-only:

- `../build/final-0.1.0-e942db6f/INFINIDIVE-0.1.0-prealpha-web-e942db6f.zip` is 11,017,962 bytes with SHA-256 `8df771d497ce98c5807e40bf2e2f0bff9aa5bbdb74f614551668b8fd559b0001`; archive integrity and Web validation pass. Its privacy/support files hash to `81cf55f7f9e4c18a9c3a611593f358597020e93e61e594d89da482fd80bae17e` / `283e82c98eb26180c6426b2d9fcba919f0546eec8ea714f487b1eb5c50a802b2` and match both the corrected bilingual sources and current live responses.
- `../build/final-0.1.0-e942db6f/INFINIDIVE-0.1.0-prealpha-debug-e942db6f.apk` is 29,063,530 bytes with SHA-256 `d089cebf2207391634fa6b2719d9b8c0a56e654619c33b05292e47aacc78bfa6`; structural package/SDK/arm64/permission/alignment/Debug-v2-v3 validation passed. It is not an AAB and was not installed on an emulator or physical device.
- `../build/final-0.1.0-e942db6f/INFINIDIVE-0.1.0-prealpha-ios-unsigned-e942db6f.zip` contains the retained unsigned scaffold plus a fresh 625,908-byte current-source PCK (`8cf2bd0732b1df958f65958cd45fee65d2387527f6a7cf08b6287dff1f3ccf83`) that passed a headless main-pack probe. No Xcode compile, archive, signature, simulator run, install, or TestFlight upload is claimed.

`export_presets.cfg` now includes a separate Gradle `Android AAB` preset targeting `../build/android/infinidive-release.aab`, without replacing the debug-APK preset. The verified CI installer extracts Godot's `android_source.zip`, and the debug-export command uses `--install-android-build-template`; an integrated dry run created `android/build`. No AAB has been produced: Gradle dependencies still need to resolve in a complete SDK/build-tools 36 environment, and release signing requires the owner's private upload/release keystore. Full iOS project re-export/archive/sign/TestFlight work requires macOS, Xcode, the owner's Apple Team ID, certificates, and provisioning; the current-source PCK does not replace that missing native-build evidence.

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
