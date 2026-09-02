# INFINIDIVE

**Fight giants outside. Destroy them within.**

INFINIDIVE is a portrait-oriented mobile action roguelite built with Godot 4. The hero begins unarmed, wakes the hand-cast **AION SPARK**, breaks a Titan's exterior armor, opens a breach, destroys an internal organ, and returns to an exterior battle changed by that loss.

> **Current status:** version `0.1.0` is a playable public pre-alpha, not a release candidate. The public [game](https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/) currently carries deployment marker `e7275f5fc78ad7237da2549ff0396123814ccebc` from Actions run [`33668271115`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33668271115). That run passed validation, Web/Android exports, unsigned-iOS scaffold, 30-minute soak, Pages deploy, and unsigned Xcode 26 Simulator/iPhoneOS compilation, but its public-smoke job failed later during bright-trailer input and its native capture did not complete. The latest fully passing public whole-path/reload proof remains bright Greek-mythic/AION commit [`a550ca867506f34856cf337fbe28083a9cdbaec5`](https://github.com/matanita44-sudo/claude-builders-bounty/commit/a550ca867506f34856cf337fbe28083a9cdbaec5) in run [`33594396541`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33594396541). There is still no live backend transport, production-signed native build, store submission, TestFlight install, or physical-device QA evidence.

> **Current evidence boundary:** public artifact `9833689840` (4,752,918-byte ZIP; SHA-256 `b5c2034b1398f852846c476f18c49d758c9fc17836607e06983eeb745a1d7f58`) is bound to `a550ca8`, returns HTTP 200 on a live 540×960 canvas, and traverses exterior combat → breach → organ selection → Dive → internal route → Hunter Eye destruction → mutation → changed exterior. A same-context reload restores the primary save with tutorial count 8 and mutation-discovery count 1; no page error, crash, or request failure was recorded. Soak artifact `9833647628` (SHA-256 `4607d9dfb3e5c0fdb53dd2666a10922fd6b90a7ace18ef6db0236a15ef8ac245`) passed for 1,800.026 seconds at fingerprint `a0e456bc31c947cb1db2330e40b5069a323168b2b0ac1df553143bf9e9eb9a2c`, with 25,109 cycles, 2,511 restarts/Dives, and zero failures or orphan nodes. Hardening commit `e7275f5` later added and deployed much of the rebuilt content/CI surface, with green validation/build/soak jobs but incomplete native/public capture. The fresh post-`e7275f5` local matrix passes `40,709/0` across 21 suites; only that latest tuning/share/capture delta lacks remote evidence. None of this substitutes for Mobile Safari/Chrome, human control feel, native signing, TestFlight, or physical-device evidence.

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
- 123 original, deterministic pre-rendered sound/music resources: 24 SFX plus three-layer adaptive music across nine states and four Titan tonal identities. Runtime loads them lazily; it no longer synthesizes PCM during combat transitions.
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
2,868 assertions, 0 failures
```

The main suite validates data counts and IDs; all organ-order permutations; malformed and fuzzed challenge codes; deterministic mutation offers, full-catalog exhaustion, and near-exhaustion rerolls; mutation/weapon runtime behavior; localization and RTL widgets; analytics opt-out; safe-area math; deterministic room generation; pooled projectile collision; 30/60 Hz movement consistency; dash, shields, save recovery/migration/banking; lifecycle pause/save locking; full Reset Progress cleanup; live telegraph-avoidance observation; rate-limited combat-audio call sites; the first outside-inside-outside hook; 24 deterministic full-victory simulations; and a real UI failure/progression loop. That loop dies, banks the 55 Bio-Matter failure floor, returns to the Nest, buys Reinforced Hull in the Forge, starts a 110-HP run, dies again, presses instant retry, and verifies the saved profile in a separate Godot process.

The rebuilt post-`a550ca8` tree passes **40,709 assertions and 0 failures across 21 local suites**. The exact suite counts are main `2,868`, backend `100`, upgrades `120`, tutorial `198`, mechanics `3,541`, compiler `15,515`, defender effects `354`, live defender effects `212`, projectile travel `685`, live integration `4,131`, organs `7,354`, Titan attack specifications `1,045`, meta `111`, audio `684`, story `164`, story presentation `280`, visual `412`, story canon `476`, Story Overlay `34`, Player Presentation `17`, and localized-layout acceptance `2,408`. The main suite includes fail-closed activation and source-binding tests for the QA-only native iOS capture controller and Friend Rift result sharing. Editor/import plus the strict drivers produced exact sentinels and zero unexpected engine/script/parse errors; inventory is 23 scenes / 21 standalone suites / one nested probe / one soak. A source-current bounded 8.05-second soak passed with 97 iterations, 10 restarts/Dives, 97 projectile cycles, six saves, 530 queued events, peak 540, zero failures, and all seven movement models. Deployed `a550ca8` separately retains remote `28,949/0` proof. The rebuilt delta still requires remote CI, export, native Simulator, deployment, and public-smoke evidence.

The workflow runs every discovered standalone suite through an isolated strict wrapper: a nonzero process exit, any engine `ERROR`, script/parse error, missing exact result sentinel, assertion-count drift, stale inventory entry, or invalid/missing soak report pair fails the job. The soak writer stages JSON and Markdown as a two-phase transaction, validates the complete schema and semantic coverage, binds the exact Markdown SHA-256 into JSON, and marks `report_transaction_complete` only after cleanup succeeds. It preserves or restores the previous complete pair symmetrically, accepts positive fractional durations, and persists partial/early or source-change diagnostic `FAIL` evidence without allowing it to qualify as `PASS`. Failure injection covers both sides of open, write, verify, first/second commit, and cleanup plus truncated and mixed primary/backup pairs. CI independently recomputes the current production fingerprint, rejects stale reports/recovery pairs, self-tests `PASS`/diagnostic and strict negative fixtures, and requires an exact JSON/Markdown result, transaction, completion marker, bound hash, requested duration, and semantic exercise contract.

Historical 8.049-second and 90.041-second source-locked reports for fingerprint `1db2d97a…` remain retained comparison evidence. They are not the active bright candidate's endurance proof.

The retained `a550ca8` 30-minute CI soak in run [`33594396541`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33594396541), job [`100135598119`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33594396541/job/100135598119), passed for 1,800.026 seconds. It completed 25,109 cycles and 2,511 restarts/Dives with zero recorded failures and zero orphan nodes. Its unchanged start/end fingerprint is `a0e456bc31c947cb1db2330e40b5069a323168b2b0ac1df553143bf9e9eb9a2c`. Artifact `9833647628` is 9,281 bytes with SHA-256 `4607d9dfb3e5c0fdb53dd2666a10922fd6b90a7ace18ef6db0236a15ef8ac245`; hardening run `33668271115` separately passed a newer source-bound 30-minute soak for `e7275f5`.

For historical comparison, the previous-source 30-minute CI soak in run [33559947112](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33559947112), job [`100030992601`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33559947112/job/100030992601), passed for 1,800.043 seconds with seed 203541. It completed 26,676 iterations/projectile cycles, 2,668 boss restarts and Dives, 1,335 save writes / 22 save reloads, 3,188 queued offline events / 24 queue reloads / final queue 500, peak 540 projectiles, 7/7 exact requested-versus-executed models, stable-memory delta 3,667,676 bytes, slope 84,517.9971965645 B/min, and zero failures. Its start and end fingerprints both equal prior fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`; transaction `5c047f1a630e8e1de5c5ffff` is complete. Artifact `9822001845` is 9,042 bytes as a ZIP with SHA-256 `f93bd2c76a640c8cc2ccbc80593112752bf625298f00af86037091c667b7d29c`; inside it, the 53,857-byte JSON hashes to `2f8171e8317572f31fd479884edcaa441452082640a9be4f3fe9339da02710b4`, and the 1,091-byte Markdown/bound report hashes to `a508864e78c75981e8221df2c53f0ed97c82501295e999328fa86b78970f1856`. The production fingerprint intentionally excludes `assets/store/gameplay/raw/`: that directory is local-only, non-exported capture provenance rather than executable product source. Neither Linux headless structural soak proves human control feel, browser compatibility, target-device FPS, thermals, battery, GPU behavior, native installation, production signing, background/force-close safety, an update from a previously shipped build, repeated Abyss depths, or physical-device behavior.

## Export Web locally

The checked-in `Web` preset writes a normal export to `../build/web/`. Historical pre-pivot packages remain under `../../build/semantic-qa-1db2d97a/`; the latest fully passing public whole-path artifacts are retained by Actions run `33594396541`:

```bash
GODOT=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --path . --export-release Web
```

Run `33594396541` exported `a550ca8` and passed the query-gated outside-inside-outside path plus same-context reload. Its CI Web smoke artifact is `9833003906` (4,746,140 bytes; SHA-256 `1a6a23bbb8de3896e515cdd7e6f6174115407175b8567a60a1985fa2718981ba`). Run `33668271115` later deployed hardening commit `e7275f5`, including the public notices page, but its public job failed during the subsequent trailer capture; the post-`e7275f5` local fixes still need a fresh export/static/browser/deployment chain.

Run `33594396541` deployed commit `a550ca867506f34856cf337fbe28083a9cdbaec5` and passed the public-host semantic smoke: HTTP 200, live 540×960 canvas, complete exterior → breach → organ selection → Dive → internal route → Hunter Eye destruction → mutation → changed exterior, then primary-save reload with exact persisted tutorial/mutation aggregates. Public artifact `9833689840` is 4,752,918 bytes with ZIP SHA-256 `b5c2034b1398f852846c476f18c49d758c9fc17836607e06983eeb745a1d7f58`; zero page errors, crashes, or request failures were recorded. This remains the latest complete public-path evidence even though the live deployment marker later advanced to `e7275f5`. Mobile-browser behavior, human feel, and native Simulator/physical-device behavior remain unproven.

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
