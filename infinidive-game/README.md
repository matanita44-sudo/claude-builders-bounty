# INFINIDIVE

**Fight giants outside. Destroy them within.**

INFINIDIVE is a portrait-oriented mobile action roguelite built with Godot 4. The player breaks a colossus's exterior armor, opens a breach, chooses an internal organ, fights through a short seeded route, destroys the organ, and returns to an exterior battle changed by that loss.

> **Current status:** version `0.1.0` is a playable pre-alpha production foundation, not a release candidate. The frozen local working tree described below has not yet been pushed. Commit `8e4be78267a043072827963d6492c7964239ae94` and GitHub Actions run [33514397476](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476) are explicitly historical remote evidence: that run passed its then-configured eight validation suites, Web export/Chromium boot smoke, and Android debug export, while deploy job [99878161111](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476/job/99878161111) failed because the integration could not create the Pages site. The repository's authenticated Pages setting is now enabled with Source `GitHub Actions`, but no new workflow deployment or public-URL success has been verified. There is no verified public playable deployment, live backend transport, production-signed native build, store submission, simulator install, or physical-device QA evidence yet.

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

The final frozen local matrix passed **28,410 assertions and 0 failures across 13 suites**: main `2,631`; backend/offline `82`; permanent upgrades `120`; tutorial `198`; room mechanics `3,541`; room compiler `15,515`; pure defender effects `354`; live defender effects `212`; projectile travel `685`; live room integration `4,131`; organ transformations `325`; meta goals `111`; and adaptive audio `505`. The six room-runtime suites contribute `24,438/0`. Editor import and every suite passed through the strict wrapper with zero `ERROR`, script-error, or parse-error lines. The frozen inventories are fingerprinted as production `8e9810de2615332713f86f47bf2f28f38728fb75e51ea5bfaf2d16760927d863` and tests/CI `db398ae7804cf75e6741e13380993f9425d42b3e44de8da62631f159595f1597`. Current contracts include compiler-signed owner/cycle cleanup; lane indices bounded by each movement topology; a frozen full-projectile preview signed into the execution payload; removal of actually homing owned threats when tracking is suppressed rather than silently straightening them; 30/60/120 Hz player-homing consistency; swept collision before lifetime/bounds retirement and in physical first-contact order; nonlinear/homing collision subsegments even when no safe-zone metadata is present; and terminal retirement at the first arena exit, including the exact `16/3s` node-link hitch case. Internal routes and organ chambers restore movement/Dash after organ selection, hidden touches during disabled control are ignored, and pause/resume keeps controls locked throughout `DIVING_IN`, `DIVING_OUT`, and `MUTATION_CHOICE`. A paused `BREACH_OPEN` also rejects `_request_dive()` without replacing the pause overlay; after manual resume the same legal Dive path works. Full ownership of all 24 mutations exits the choice state deterministically and grants a visible localized 120 Bio-Matter fallback; a near-exhaustion reroll instead reuses the remaining legal unselected pool, consumes one reroll, stays in `MUTATION_CHOICE`, and grants no reward. The English and Hebrew string tables contain the fallback result key. Application `PAUSED`/`FOCUS_OUT` notifications synchronously and idempotently pause, lock controls, and force a save; `RESUMED`/`FOCUS_IN` only resynchronize state, so manual resume remains required. Headless regression verifies the persisted marker and locked controls, but this is not physical mobile suspend/resume evidence.

The workflow runs every discovered standalone suite through an isolated strict wrapper: a nonzero process exit, any engine `ERROR`, script/parse error, missing exact result sentinel, assertion-count drift, stale inventory entry, or invalid/missing soak report pair fails the job. The soak writer stages JSON and Markdown as a two-phase transaction, validates the complete schema and semantic coverage, binds the exact Markdown SHA-256 into JSON, and marks `report_transaction_complete` only after cleanup succeeds. It preserves or restores the previous complete pair symmetrically, accepts positive fractional durations, and persists partial/early or source-change diagnostic `FAIL` evidence without allowing it to qualify as `PASS`. Failure injection covers both sides of open, write, verify, first/second commit, and cleanup plus truncated and mixed primary/backup pairs. CI independently recomputes the current production fingerprint, rejects stale reports/recovery pairs, self-tests `PASS`/diagnostic and strict negative fixtures, and requires an exact JSON/Markdown result, transaction, completion marker, bound hash, requested duration, and semantic exercise contract.

The final 8.014-second smoke passed 87 cycles, nine restarts and Dives, six saves, 529 queued offline events / two queue reloads / final queue 500, all seven requested projectile-model counts exactly matching executed counts, peak 540 projectiles, and unchanged fingerprint `8e9810de2615332713f86f47bf2f28f38728fb75e51ea5bfaf2d16760927d863`. Its transaction is `b5a5db690e1513095a2cf63f`; the 3,069-byte JSON SHA-256 is `dbcbf0bdb4fc9e6fb763a5c344f274872cb13875696764fe118a4bf8c3901bdb`, and the 1,062-byte Markdown/bound SHA-256 is `15cd17499c54496ad909536039a3706f46c2fc197c856aa4b9fd89feaf2f5167`. The final 90.118-second soak passed 1,141 cycles, 115 restarts and Dives, 58 saves, 634 queued offline events / three queue reloads / final queue 500, 7/7 models, peak 540, stable-memory delta 87,560 bytes, slope 216,364.835675299 B/min, the same unchanged fingerprint, and zero failures. Its transaction is `22c5717c57c6018e8189b84f`; the 5,487-byte JSON SHA-256 is `119157a6aaf32943c30062dd2b51fe0ee1182b525b50acd0017c8f8c2150c5cf`, and the 1,075-byte Markdown/bound SHA-256 is `30c3b34a24347a5d6267929dc1a1f37bbd3b4a2f7374d64a6b446b6e66679bea`. The older 30-minute soak remains snapshot-only evidence and does not validate the current source; a post-freeze 30-minute RC rerun remains missing. None of this proves human control feel, browser compatibility, target-device performance, native installation, production signing, background/force-close safety, an update from a previously shipped build, repeated Abyss depths, or physical-device behavior.

## Export Web locally

The checked-in `Web` preset writes a normal export to `../build/web/`. The verified frozen packages are retained under `../build/final-0.1.0-8e9810de/`:

```bash
GODOT=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --path . --export-release Web
```

The final Web export contains `index.html` (2,618 bytes; SHA-256 `65c3d9b290b3b3eb4baab5e8d677edee04ea3d0f4dc8331cf792e275a30c9f61`), `index.js` (279,815; `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba`), `index.pck` (625,812; `33283d7cfcf37fc5b1b5ccd5f77254766839bb674f9c8e1bd50cb7c3640ed43d`), and `index.wasm` (39,514,754; `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`). Static validation and local HTTP root/privacy/support/WASM/PCK checks passed; no local real-browser canvas was available. Historical Web job [99877839855](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476/job/99877839855) remains scoped to commit `8e4be782`. The repository's authenticated Pages Source is now `GitHub Actions`, but no new workflow deployment has been verified and the recorded public paths remain HTTP 404 with no canvas.

Native evidence is development-only:

- `../build/final-0.1.0-8e9810de/INFINIDIVE-0.1.0-prealpha-debug-8e9810de.apk` is 29,063,530 bytes with SHA-256 `d089cebf2207391634fa6b2719d9b8c0a56e654619c33b05292e47aacc78bfa6`; structural package/SDK/arm64/permission/alignment/Debug-v2-v3 validation passed. It is not an AAB and was not installed on an emulator or physical device.
- `../build/final-0.1.0-8e9810de/INFINIDIVE-0.1.0-prealpha-ios-unsigned-8e9810de.zip` contains the retained unsigned scaffold plus a fresh 625,908-byte current-source PCK (`8cf2bd0732b1df958f65958cd45fee65d2387527f6a7cf08b6287dff1f3ccf83`) that passed a headless main-pack probe. No Xcode compile, archive, signature, simulator run, install, or TestFlight upload is claimed.

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
