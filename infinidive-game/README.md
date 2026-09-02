# INFINIDIVE

**Fight giants outside. Destroy them within.**

INFINIDIVE is a portrait-oriented mobile action roguelite built with Godot 4. The hero begins unarmed, wakes the hand-cast **AION SPARK**, breaks a Titan's exterior armor, opens a breach, destroys an internal organ, and returns to an exterior battle changed by that loss.

> **Current status:** version `0.1.0` is a playable pre-alpha production foundation, not a release candidate. Commit [`73a3f4aad29a2d3900fe55e94ba4cfde6885d42a`](https://github.com/matanita44-sudo/claude-builders-bounty/commit/73a3f4aad29a2d3900fe55e94ba4cfde6885d42a) completed GitHub Actions run [`33572931398`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33572931398): strict validation, Web export and CI-served semantic Chromium smoke, Android debug export/validation, a fresh source-bound 30-minute soak, Pages deployment job [`100078099551`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33572931398/job/100078099551), and public-host semantic smoke job [`100078147875`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33572931398/job/100078147875) all passed. The public [game](https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/) still serves that pre-pivot candidate; it does not yet show the current bright Greek-mythic/AION working tree. There is still no live backend transport, production-signed native build, store submission, simulator install, or physical-device QA evidence.

> **Current candidate evidence:** production fingerprint `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e` and tests/CI fingerprint `ff2530d3aad779a21a3b775e8d973ba1b3e3c37a86b5b97cea133801c954dc59` remained bound throughout the completed run. Local and remote 13-suite matrices passed `28,410/0`; fresh 8.049-second, 90.041-second, and 1,800.035-second source-bound soaks passed. The public-host smoke recorded HTTP 200, a live 540×960 canvas, exact run-generation transition 0→1, 269.180-pixel movement, Dash count 0→1 with charge 1→0, 3/3/3 synthetic touch events, and zero page, crash, network, or critical-subresource failures. This narrow semantic evidence does not cover breach, Dive, organ destruction/return, reload persistence, mobile Safari/Chrome, human control feel, simulator behavior, or physical-device behavior. Fresh local Web/APK/PCK/unsigned-iOS packages are recorded under `../../build/semantic-qa-1db2d97a/` (relative to this project directory).

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
2,631 assertions, 0 failures
```

The main suite validates data counts and IDs; all organ-order permutations; malformed and fuzzed challenge codes; deterministic mutation offers, full-catalog exhaustion, and near-exhaustion rerolls; mutation/weapon runtime behavior; localization and RTL widgets; analytics opt-out; safe-area math; deterministic room generation; pooled projectile collision; 30/60 Hz movement consistency; dash, shields, save recovery/migration/banking; lifecycle pause/save locking; full Reset Progress cleanup; live telegraph-avoidance observation; rate-limited combat-audio call sites; the first outside-inside-outside hook; 24 deterministic full-victory simulations; and a real UI failure/progression loop. That loop dies, banks the 55 Bio-Matter failure floor, returns to the Nest, buys Reinforced Hull in the Forge, starts a 110-HP run, dies again, presses instant retry, and verifies the saved profile in a separate Godot process.

The current candidate local matrix passed **28,410 assertions and 0 failures across 13 suites**: main `2,631`; backend/offline `82`; permanent upgrades `120`; tutorial `198`; room mechanics `3,541`; room compiler `15,515`; pure defender effects `354`; live defender effects `212`; projectile travel `685`; live room integration `4,131`; organ transformations `325`; meta goals `111`; and adaptive audio `505`. The six room-runtime suites contribute `24,438/0`. Editor import and every suite passed through the strict wrapper with zero `ERROR`, script-error, or parse-error lines. The candidate inventories are fingerprinted as production `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e` and tracked tests/CI `ff2530d3aad779a21a3b775e8d973ba1b3e3c37a86b5b97cea133801c954dc59`. Current contracts include compiler-signed owner/cycle cleanup; lane indices bounded by each movement topology; a frozen full-projectile preview signed into the execution payload; removal of actually homing owned threats when tracking is suppressed rather than silently straightening them; 30/60/120 Hz player-homing consistency; swept collision before lifetime/bounds retirement and in physical first-contact order; nonlinear/homing collision subsegments even when no safe-zone metadata is present; and terminal retirement at the first arena exit, including the exact `16/3s` node-link hitch case. Internal routes and organ chambers restore movement/Dash after organ selection, hidden touches during disabled control are ignored, and pause/resume keeps controls locked throughout `DIVING_IN`, `DIVING_OUT`, and `MUTATION_CHOICE`. A paused `BREACH_OPEN` also rejects `_request_dive()` without replacing the pause overlay; after manual resume the same legal Dive path works. Full ownership of all 24 mutations exits the choice state deterministically and grants a visible localized 120 Bio-Matter fallback; a near-exhaustion reroll instead reuses the remaining legal unselected pool, consumes one reroll, stays in `MUTATION_CHOICE`, and grants no reward. The English and Hebrew string tables contain the fallback result key. Application `PAUSED`/`FOCUS_OUT` notifications synchronously and idempotently pause, lock controls, and force a save; `RESUMED`/`FOCUS_IN` only resynchronize state, so manual resume remains required. Headless regression verifies the persisted marker and locked controls, but this is not physical mobile suspend/resume evidence.

The workflow runs every discovered standalone suite through an isolated strict wrapper: a nonzero process exit, any engine `ERROR`, script/parse error, missing exact result sentinel, assertion-count drift, stale inventory entry, or invalid/missing soak report pair fails the job. The soak writer stages JSON and Markdown as a two-phase transaction, validates the complete schema and semantic coverage, binds the exact Markdown SHA-256 into JSON, and marks `report_transaction_complete` only after cleanup succeeds. It preserves or restores the previous complete pair symmetrically, accepts positive fractional durations, and persists partial/early or source-change diagnostic `FAIL` evidence without allowing it to qualify as `PASS`. Failure injection covers both sides of open, write, verify, first/second commit, and cleanup plus truncated and mixed primary/backup pairs. CI independently recomputes the current production fingerprint, rejects stale reports/recovery pairs, self-tests `PASS`/diagnostic and strict negative fixtures, and requires an exact JSON/Markdown result, transaction, completion marker, bound hash, requested duration, and semantic exercise contract.

The candidate 8.049-second smoke passed 88 cycles, nine restarts and Dives, six saves, 529 queued offline events / two queue reloads / final queue 500, all seven requested projectile-model counts exactly matching executed counts, peak 540 projectiles, and unchanged fingerprint `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e`. Its transaction is `994142d36b9310b4523a7b2f`; the 3,069-byte JSON SHA-256 is `4ed5331ef40095b482a3c15804a34f42e0c7be9fdd615ed125c4a020d652242c`, and the 1,063-byte Markdown/bound SHA-256 is `3ac976b10c77799e9c7ec8930e62d0f329cc36910cc18f6d3bc933f72cca7b85`. The candidate 90.041-second soak passed 1,166 cycles, 117 restarts and Dives, 60 saves / one save reload, 637 queued offline events / three queue reloads / final queue 500, 7/7 models, peak 540, stable-memory delta 90,604 bytes, slope 218,771.80935953 B/min, the same unchanged fingerprint, and zero failures. Its transaction is `98e69a9b42dd1314f6a16cb9`; the 5,486-byte JSON SHA-256 is `0033e18b7730513b977dadb9f275ad919ed24dc6c4e6545d31b1199c3d48e65b`, and the 1,076-byte Markdown/bound SHA-256 is `c6a109f86f8ba63474b4456c3d265111f85759c82e5c6ad86f85efd8833d571c`.

The current candidate 30-minute CI soak in run [`33572931398`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33572931398), job [`100071482078`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33572931398/job/100071482078), passed for 1,800.035 seconds. It completed 27,043 iterations/projectile cycles, 2,705 boss restarts and Dives, 1,353 save writes / 22 save reloads, 3,224 queued offline events / 24 queue reloads / final queue 500, 1,659,358 player and 3,260,252 enemy projectile executions, peak 540 projectiles, 1,597 objects / 32 nodes / zero orphan nodes, 7/7 exact requested-versus-executed models, stable-memory delta 3,296,336 bytes, slope 88,712.5106369138 B/min, and zero failures. Its start/end fingerprint is `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e`; transaction `9f396a0becf39225c7580401` is complete. Artifact `9826413723` is a 9,008-byte ZIP with SHA-256 `1290cf7b8cf81b64dd6f0b43e55739f4f3bbaa24d4b40a083d6dbf1296b03a63`; its 53,728-byte JSON hashes to `be3c3d795d31e9581e6fa108f462f58cd3264d9f24aff4d338a79123e485ed09`, and the 1,091-byte Markdown/bound report hashes to `d24fe59b37296f6006bb27dc18b61f3ff4996bbfdfc354d852af1377c3ab64b3`.

For historical comparison, the previous-source 30-minute CI soak in run [33559947112](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33559947112), job [`100030992601`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33559947112/job/100030992601), passed for 1,800.043 seconds with seed 203541. It completed 26,676 iterations/projectile cycles, 2,668 boss restarts and Dives, 1,335 save writes / 22 save reloads, 3,188 queued offline events / 24 queue reloads / final queue 500, peak 540 projectiles, 7/7 exact requested-versus-executed models, stable-memory delta 3,667,676 bytes, slope 84,517.9971965645 B/min, and zero failures. Its start and end fingerprints both equal prior fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`; transaction `5c047f1a630e8e1de5c5ffff` is complete. Artifact `9822001845` is 9,042 bytes as a ZIP with SHA-256 `f93bd2c76a640c8cc2ccbc80593112752bf625298f00af86037091c667b7d29c`; inside it, the 53,857-byte JSON hashes to `2f8171e8317572f31fd479884edcaa441452082640a9be4f3fe9339da02710b4`, and the 1,091-byte Markdown/bound report hashes to `a508864e78c75981e8221df2c53f0ed97c82501295e999328fa86b78970f1856`. The production fingerprint intentionally excludes `assets/store/gameplay/raw/`: that directory is local-only, non-exported capture provenance rather than executable product source. Neither Linux headless structural soak proves human control feel, browser compatibility, target-device FPS, thermals, battery, GPU behavior, native installation, production signing, background/force-close safety, an update from a previously shipped build, repeated Abyss depths, or physical-device behavior.

## Export Web locally

The checked-in `Web` preset writes a normal export to `../build/web/`. The current candidate's canonical development packages and manifests are retained under `../../build/semantic-qa-1db2d97a/`; the older `e942db6f` package set remains historical evidence only:

```bash
GODOT=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --path . --export-release Web
```

The current local Web export contains `index.html` (2,618 bytes; SHA-256 `752664b9f32004bb50b2b8d629481128d2e26fabb771644da679509a2849f05d`), `index.js` (279,815; `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba`), `index.pck` (629,236; `b573dee37ef910fdbf59110e1dd6667fd70f265b183d57a70eb8ecd487544116`), and `index.wasm` (39,514,754; `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`). Static validation and local HTTP root/privacy/support/WASM/PCK checks passed. In run `33572931398`, CI-served Chromium separately passed the query-gated movement/Dash contract: HTTP 200, live 540×960 canvas, exact run generation 1, 267.402-pixel movement, Dash count 0→1 with charge consumption and durable state, a valid monotonic trace, zero page/crash/network failures, and 3/3/3 synthetic touch events. Artifact `9825704303` is 93,967 bytes with SHA-256 `1ecdfcf7c35dbf14fa61434e4e00cb79b529ea7a93cbc44f1e3cf97799b2def6`; rendered hashes changed from `f80306a8ff8806b9b3cacd5b180db4fa3adc5bc46402d50beafce3811df64678` to `501147ae73482b00c69c619918688a4ab45dacbb27c1b693d385dc0e3c891b00`.

The same run deployed commit `73a3f4aad29a2d3900fe55e94ba4cfde6885d42a` to the public [game](https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/) and passed the public-host semantic smoke: HTTP 200, live 540×960 canvas, exact run-generation transition 0→1, 269.18024587052236-pixel movement, Dash count 0→1 with charge 1→0 and durable state, 3/3/3 synthetic touch events, and zero page, crash, request, network-critical, non-2xx-critical, or critical-subresource failures. Public artifact `9826433759` is 92,257 bytes with ZIP SHA-256 `014fe807c93ed3d03d7c6cfebac201faec2986324f8a576be2fbb6967ae9c020`; its 36,966-byte JSON hashes to `6903baca4574a695eb87681268c0c20f2055dc2dba24099e31188fbbe5753039`, and the retained rendered frames hash to `0da738405c7983f4d795655ada7d31acbbc4d973724b404b5651034300ba3eb9` before and `7ca6ba2e9fc87aa5ac7ea3629138d23d3cd9a7bb24b3abf39c7c839971a09633` after. Breach/Dive/organ return, reload persistence, mobile-browser behavior, human feel, and simulator/physical-device behavior remain unproven by this narrow semantic smoke.

Packaged evidence is development-only:

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
