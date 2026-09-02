# INFINIDIVE

**Fight giants outside. Destroy them within.**

INFINIDIVE is a portrait-oriented mobile action roguelite built with Godot 4. The hero begins unarmed, wakes the hand-cast **AION SPARK**, breaks a Titan's exterior armor, opens a breach, destroys an internal organ, and returns to an exterior battle changed by that loss.

> **Current status:** version `0.1.0` is a playable public pre-alpha, not a release candidate. Bright Greek-mythic/AION commit [`e9e7a50f24914fab8afd1cfe36b2e236c5402e7f`](https://github.com/matanita44-sudo/claude-builders-bounty/commit/e9e7a50f24914fab8afd1cfe36b2e236c5402e7f) completed GitHub Actions run [`33590118787`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33590118787): strict validation, Web export and full-path/reload Chromium smoke, Android debug export/validation, unsigned iOS Xcode scaffold validation, a fresh source-bound 30-minute soak, Pages deployment, and public-host semantic smoke all passed. The public [game](https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/) now serves that bright candidate. There is still no live backend transport, production-signed native build, store submission, simulator install, or physical-device QA evidence.

> **Current evidence boundary:** the deployed public artifact `9832202834` is bound to `e9e7a50`, returns HTTP 200 on a live 540×960 canvas, and traverses exterior combat → breach → organ selection → Dive → internal route → Hunter Eye destruction → mutation → changed exterior. A same-context reload restores the primary save with exact tutorial and mutation-discovery counts; no page error, crash, or request failure was recorded. The 30-minute artifact `9832161116` passed for 1,800.002 seconds at production fingerprint `6b7a5fa2f9639c2855874e9f91d3632ab49af274d2cb6b6cbd4a4c2d1c1456a1`, with 25,369 cycles, 2,537 restarts/Dives, 1,270 saves, 21 reloads, exact 7/7 travel-model coverage, zero failures, and zero orphan nodes. The uncommitted follow-up adds durable schema-7 first-breach receipts, a public Draft Terms page, and nine stage-specific CI captures; its local matrix passes `28,949/0`, but it is not part of the deployed artifact yet. None of this substitutes for Mobile Safari/Chrome, human control-feel, simulator, native-install, signing, or physical-device evidence.

## What currently works

- A complete coded outside -> breach -> organ choice -> inside -> organ destruction -> mutation -> outside loop.
- Three exterior armor phases followed by a final core phase.
- Player drag movement with an 82-pixel finger offset, automatic fire, shields, damage, and Phase Dash.
- Dedicated-button, double-tap, and flick dash input paths.
- Four launch Titans—**CRONUS**, **HYPERION**, **OCEANUS**, and **MNEMOSYNE**—with three organs each, distinct presentation, palettes, and attack-ability sets. Stable gameplay/save IDs remain `gravemaw`, `seraph_9`, `abyss_leviathan`, and `null_twin`; those IDs are not player-facing names. All 12 organs declare a validated loss contract: seven replace the intact attack with a safer degraded pattern, five shut it down, and every loss publishes a unique exterior visual state plus English/Hebrew result copy.
- Five weapon definitions with pulse, scatter, rail, arc, and orbital runtime behavior. The stable starter-weapon ID remains `pulse_needle`, while its displayed English name is **AION SPARK**.
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
- Five truthful 1080×1920 runtime stills, a 17.2-second 1080×1920 H.264/AAC social-development edit, and an 886×1920 Apple-format experiment retain capture, audio, limitations, and SHA-256 provenance. They were produced from a Linux virtual-display run before the bright Greek-mythic/AION pivot, so they are historical development evidence only—not current marketing, store, physical-device, or submission-ready media. Every store capture must be replaced from the frozen RC.
- An opt-in, vendor-neutral analytics event queue that remains local; no analytics transport is connected.
- Fail-closed local configuration plus a validated, checksummed offline leaderboard outbox. Completed Daily/Friend runs queue bounded summaries under canonical challenge IDs; Story/Abyss results remain local-only and do not consume the outbox. No account, network transport, server verification, or online leaderboard is connected.
- A confirmed Reset Progress flow in Settings. After confirmation it replaces the versioned profile and recovery backup with clean defaults and idempotently clears the local analytics queue plus the Daily/Friend leaderboard primary, backup, and temporary files.

The data counts and effect contracts above are real. The room runtime now executes the authored structural, projectile, movement, and defender identities instead of reducing them to a generic executor; it is still a code-drawn system, not 42 bespoke art scenes. Automated playback proves the named timing, geometry, preview, ownership, collision, and cleanup invariants, not human reachability, visual clarity, or fun. Human balance, browser, and device validation remain outstanding. See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) before treating content counts as release-complete.

## Controls

- **Move:** drag anywhere in the combat field. The hero follows above the finger.
- **Fire:** AION SPARK fires automatically during active combat; aim selection prefers internal defenders before the Titan or organ.
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
2,726 assertions, 0 failures
```

The main suite validates data counts and IDs; all organ-order permutations; malformed and fuzzed challenge codes; deterministic mutation offers, full-catalog exhaustion, and near-exhaustion rerolls; mutation/weapon runtime behavior; localization and RTL widgets; analytics opt-out; safe-area math; deterministic room generation; pooled projectile collision; 30/60 Hz movement consistency; dash, shields, save recovery/migration/banking; lifecycle pause/save locking; full Reset Progress cleanup; live telegraph-avoidance observation; rate-limited combat-audio call sites; the first outside-inside-outside hook; 24 deterministic full-victory simulations; and a real UI failure/progression loop. That loop dies, banks the 55 Bio-Matter failure floor, returns to the Nest, buys Reinforced Hull in the Forge, starts a 110-HP run, dies again, presses instant retry, and verifies the saved profile in a separate Godot process.

The current matrix passes **28,949 assertions and 0 failures across 15 suites**: main `2,726`; backend/offline `82`; permanent upgrades `120`; tutorial `198`; room mechanics `3,541`; room compiler `15,515`; pure defender effects `354`; live defender effects `212`; projectile travel `685`; live room integration `4,131`; organ transformations `325`; meta goals `111`; adaptive audio `505`; story `164`; and story presentation `280`. The six room-runtime suites contribute `24,438/0`. Editor import and every suite pass through the strict wrapper with zero `ERROR`, script-error, or parse-error lines. Deployed candidate `e9e7a50` passed the same remote suite matrix; the post-e9 first-breach/schema-7/Terms/stage-capture delta repeats it locally and still requires its own remote run. Coverage includes complete run/progression and save paths, full boss/organ permutations, data-driven weapons/mutations/upgrades, exact-once rewards and story receipts, room topology/travel/collision/cleanup contracts, lifecycle pause/save locking, English-first localization with optional Hebrew/RTL, accessibility settings, and complete outside-inside-outside semantics. These are automated contracts, not physical mobile suspend/resume, control-feel, balance, or visual-quality evidence.

The workflow runs every discovered standalone suite through an isolated strict wrapper: a nonzero process exit, any engine `ERROR`, script/parse error, missing exact result sentinel, assertion-count drift, stale inventory entry, or invalid/missing soak report pair fails the job. The soak writer stages JSON and Markdown as a two-phase transaction, validates the complete schema and semantic coverage, binds the exact Markdown SHA-256 into JSON, and marks `report_transaction_complete` only after cleanup succeeds. It preserves or restores the previous complete pair symmetrically, accepts positive fractional durations, and persists partial/early or source-change diagnostic `FAIL` evidence without allowing it to qualify as `PASS`. Failure injection covers both sides of open, write, verify, first/second commit, and cleanup plus truncated and mixed primary/backup pairs. CI independently recomputes the current production fingerprint, rejects stale reports/recovery pairs, self-tests `PASS`/diagnostic and strict negative fixtures, and requires an exact JSON/Markdown result, transaction, completion marker, bound hash, requested duration, and semantic exercise contract.

Historical 8.049-second and 90.041-second source-locked reports for fingerprint `1db2d97a…` remain retained comparison evidence. They are not the active bright candidate's endurance proof.

The current deployed-candidate 30-minute CI soak in run [`33590118787`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33590118787), job [`100122969264`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33590118787/job/100122969264), passed for 1,800.002 seconds. It completed 25,369 cycles, 2,537 restarts/Dives, 1,270 saves / 21 reloads, 3,057 queued events / 23 queue reloads / final queue 500, 1,556,637 player and 3,058,437 enemy projectile executions, peak 540 projectiles, 1,641 objects / 42 nodes / zero orphan nodes, exact 7/7 travel models, stable-memory delta 3,700,120 bytes, and zero failures. Its start/end fingerprint is `6b7a5fa2f9639c2855874e9f91d3632ab49af274d2cb6b6cbd4a4c2d1c1456a1`; transaction `65a4f2109909677648587490` is complete. Artifact `9832161116` is a 9,282-byte ZIP with SHA-256 `cd27506d42293e04d1f8dd21b7caf72428164a013f23df3ec661115b69c0160d`.

For historical comparison, the previous-source 30-minute CI soak in run [33559947112](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33559947112), job [`100030992601`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33559947112/job/100030992601), passed for 1,800.043 seconds with seed 203541. It completed 26,676 iterations/projectile cycles, 2,668 boss restarts and Dives, 1,335 save writes / 22 save reloads, 3,188 queued offline events / 24 queue reloads / final queue 500, peak 540 projectiles, 7/7 exact requested-versus-executed models, stable-memory delta 3,667,676 bytes, slope 84,517.9971965645 B/min, and zero failures. Its start and end fingerprints both equal prior fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`; transaction `5c047f1a630e8e1de5c5ffff` is complete. Artifact `9822001845` is 9,042 bytes as a ZIP with SHA-256 `f93bd2c76a640c8cc2ccbc80593112752bf625298f00af86037091c667b7d29c`; inside it, the 53,857-byte JSON hashes to `2f8171e8317572f31fd479884edcaa441452082640a9be4f3fe9339da02710b4`, and the 1,091-byte Markdown/bound report hashes to `a508864e78c75981e8221df2c53f0ed97c82501295e999328fa86b78970f1856`. The production fingerprint intentionally excludes `assets/store/gameplay/raw/`: that directory is local-only, non-exported capture provenance rather than executable product source. Neither Linux headless structural soak proves human control feel, browser compatibility, target-device FPS, thermals, battery, GPU behavior, native installation, production signing, background/force-close safety, an update from a previously shipped build, repeated Abyss depths, or physical-device behavior.

## Export Web locally

The checked-in `Web` preset writes a normal export to `../build/web/`. Historical pre-pivot packages remain under `../../build/semantic-qa-1db2d97a/`; current candidate artifacts are retained by Actions run `33590118787`:

```bash
GODOT=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --path . --export-release Web
```

The current post-e9 local export under `../../build/local-story-terms-web/` passes release export and static validation, including Privacy, Support, Draft Terms, PCK, and WASM. It remains a local follow-up package. In run `33590118787`, CI-served Chromium exported `e9e7a50` and passed the full query-gated outside-inside-outside path plus same-context reload; Web artifact `9831547931` is 780,235 bytes with SHA-256 `e26b88701f0da6dba70a0887cc5876b0a0751585bc7a37cc6f53b4fd635a90e7`.

The same run deployed commit `e9e7a50f24914fab8afd1cfe36b2e236c5402e7f` to the public [game](https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/) and passed the public-host semantic smoke: HTTP 200, live 540×960 canvas, complete exterior → breach → organ selection → Dive → internal route → Hunter Eye destruction → mutation → changed exterior, then primary-save reload with exact persisted tutorial/mutation aggregates. Public artifact `9832202834` is 780,343 bytes with ZIP SHA-256 `28ec3a55c1d0ed8c57f6a0587371792d3680048b29d5c4ea69593505c7d79dd7`; zero page errors, crashes, or request failures were recorded. Mobile-browser behavior, human feel, and simulator/physical-device behavior remain unproven.

Historical pre-pivot packaged evidence is development-only:

- `../../build/semantic-qa-1db2d97a/INFINIDIVE-0.1.0-prealpha-web-1db2d97a.zip` is 11,022,194 bytes with SHA-256 `a8504d0c0630dced1c3892c971a0d3f9be67844250927b8bf9a80340ebc98e4f`; archive integrity, static validation, and local HTTP checks pass. Its privacy/support files hash to `81cf55f7f9e4c18a9c3a611593f358597020e93e61e594d89da482fd80bae17e` / `283e82c98eb26180c6426b2d9fcba919f0546eec8ea714f487b1eb5c50a802b2`.
- `../../build/semantic-qa-1db2d97a/INFINIDIVE-0.1.0-prealpha-debug-1db2d97a.apk` is 29,063,530 bytes with SHA-256 `e3418d97a535cf4e36bb7c1cf05e4f7db4e722a774409e29df6f80b33786cf03`; structural package/SDK/arm64/exact-VIBRATE/alignment/debug-v2-v3 validation passed. It is not an AAB and was not installed on an emulator or physical device.
- `../../build/semantic-qa-1db2d97a/INFINIDIVE-0.1.0-prealpha-ios-unsigned-1db2d97a.zip` is 98,500,694 bytes with SHA-256 `54bb7d9f866608773470c90f8b8d953b4668f2bc3914086e2e96e131b0f85b9d`. It contains the retained unsigned scaffold plus a 629,332-byte current-source PCK (`8133fcd7ebbb071b20f30ca65a43cb35488b6fff2335915ef47d710693c33a88`) that passed a Linux headless main-pack probe. No Xcode compile, archive, signature, simulator run, install, or TestFlight upload is claimed.

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
