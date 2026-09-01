# INFINIDIVE Architecture

## Scope

This document describes the implemented `0.1.0` Godot project. It distinguishes current runtime behavior from intended release architecture. Systems that do not exist—such as a leaderboard backend, cloud save, billing, ads, or store services—are not represented as connected.

## Runtime composition

`scenes/main/Main.tscn` boots a small coordinator in `scripts/ui/main.gd`. The coordinator owns one top-level view at a time:

```text
Main
  -> NestView
       -> emits a run configuration
  -> RunScene
       -> emits retry or return-to-Nest
```

The scene tree is created in code rather than through large authored `.tscn` hierarchies. Gameplay and UI art are currently procedural Godot drawing and native Controls; no external sprite or audio asset pack is required for the current build.

## Autoload services

Autoload order is declared in `project.godot` and is significant.

| Service | Source | Responsibility | Current boundary |
|---|---|---|---|
| `GameData` | `scripts/services/game_data.gd` | Loads and validates JSON catalogs | Validation checks counts, unique IDs, 12 typed organ-loss contracts/visual tokens, and room safe-rule presence; dedicated runtime suites still distinguish automated contracts from human playability. |
| `SaveManager` | `scripts/services/save_manager.gd` | Owns profile, currency, unlocks, migration, atomic save promotion, backup recovery, and run-id deduplication | Local device storage only; no cloud synchronization. |
| `SettingsManager` | `scripts/services/settings_manager.gd` | Reads persisted settings, applies audio buses and locale, exposes haptics and assist controls | Projectile speed, telegraph multiplier, dash window, and aim assist are exposed and consumed; reduced-motion/damage-flash behavior and real-device presentation still need validation. |
| `LocalizationService` | `scripts/services/localization_service.gd` | English/Hebrew key and catalog-content lookup, locale signal, direction and alignment helpers | English/Hebrew key parity, non-empty values, all boss/organ/weapon/mutation/upgrade/room content, Hebrew glyph coverage, and representative RTL UI are headless-tested; device text fit is not validated. |
| `AnalyticsService` | `scripts/services/analytics_service.gd` | Defines allowed events, sanitizes properties, and persists an opt-in offline queue | The Settings consent control defaults off. No network transport, dashboard, or analytics vendor is connected. |
| `RemoteConfigService` | `scripts/services/remote_config_service.gd` | Loads a bundled, typed feature/limit snapshot with safe defaults | Local file only; no remote fetch or transport, and every online/monetization feature fails closed. |
| `LeaderboardService` | `scripts/services/leaderboard_service.gd` | Validates challenge identity, deduplicates, ranks, and atomically stores bounded offline run summaries | Every completed run calls it after reward banking, but only canonical Daily/Friend challenges enter the outbox. Story/Abyss return `local_only_noncompetitive`. Records remain unverified and local; no identity, credential, HTTP transport, or competitive leaderboard UI exists. |
| `AudioManager` | `scripts/services/procedural_audio.gd` | Generates original PCM effects, pools SFX players, and synthesizes three adaptive music layers | Nine music states, four boss tonal profiles, and rate-limited `armor_hit`, `organ_damage`, and `boss_phase` call sites are wired from `RunScene`; audio quality, first-use generation cost, and transitions remain unvalidated on browsers/devices. |

## Core data

All primary content catalogs are JSON arrays loaded from `data/`.

| Catalog | Current count | Runtime use |
|---|---:|---|
| `bosses.json` | 4 | Stats, organs, abilities, colors, rewards, procedural silhouettes, and 12 loss contracts: seven degraded replacements plus five shutdowns |
| `weapons.json` | 5 | Fire cadence, projectiles, basic behavior, unlock cost, and visuals |
| `mutations.json` | 24 | Seeded offers plus an explicit 42-key effect contract with runtime consumers and headless behavior coverage |
| `upgrades.json` | 18 | Forge display plus an explicit 18-key permanent-effect contract, prerequisite gates, runtime consumers, and focused behavioral tests |
| `rooms.json` | 42 | 30 non-chamber modules and 12 chambers; the generator selects a short deterministic route |

`GameData` returns duplicated dictionaries to prevent callers from mutating the source arrays accidentally.

## Run configuration and determinism

`RunScene.initialize()` accepts a dictionary with these effective fields:

- `boss`
- `weapon`
- `difficulty`
- `seed`
- `mode`
- `modifiers`
- `competitive`
- optional canonical `challenge_id` and `challenge_day_utc`
- `abyss_depth`
- optional `carried_mutations`
- optional `starting_health_ratio`

The run RNG is seeded from `config.seed`. Star placement, boss attack selection, enemy timing, mutation offers, and room selection derive from deterministic RNG seeds. Mutation offers use `seed ^ 0x2f19`; room layouts add phase and organ identity to the base seed.

Determinism currently supports local replay and challenge codes. It is not an anti-cheat system. No server verifies input streams or scores.

## Gameplay state machine

`scripts/gameplay/run_scene.gd` owns the authoritative run state:

```text
INTRO
  -> EXTERIOR
  -> BREACH_OPEN
  -> ORGAN_SELECT
  -> DIVING_IN
  -> INTERNAL_ROOMS
  -> ORGAN_CHAMBER
  -> MUTATION_CHOICE
  -> DIVING_OUT
  -> EXTERIOR (until three organs are destroyed)
  -> CORE
  -> VICTORY

Any active combat state -> DEAD
```

State transitions control projectile clearing, player input, HUD overlays, audio state, rewards, and analytics calls. Organ and mutation choice states pause the run simulation. Application focus loss requests an in-game pause.

### Exterior combat

- Each of three phases has a fresh armor pool.
- Boss attacks begin with a visible telegraph and contain a generated safe gap or lane.
- Intact organ abilities and any surviving degraded replacement contracts are added to the attack pool; fully disabled systems are omitted.
- Breaking armor clears hostile projectiles and opens a breach.
- The player chooses any remaining organ, so all six orders are supported for a three-organ boss.

### Interior route

`RoomGenerator` builds:

1. one entrance;
2. one traversal module when available;
3. one combat module when available;
4. one hazard module when available;
5. the selected organ chamber.

The route is deterministic and structurally validated. `RoomMechanics` maps all 42 authored room/chamber profiles to explicit cadence, telegraph, safe-position, movement, spawn, projectile-life, and projectile-count contracts. Runtime consumes the event schedule, full warning window, authored safe position/gap, active duration, projectile lifetime, spawn count, maximum-active bound, and wave-group cleanup. The focused playback suite exercises every contract at normal and hitch timing, checks warning-before-damage, matching wall gaps, non-overlapping chamber waves, bounded defenders/projectiles, and transition cleanup. Presentation still reduces the four declared families to three broad geometries—ring, spawn, and a vertical gap wall shared by lane/sweep—and uses one generic defender. Named pattern and movement-model IDs are not rendered as 42 bespoke spatial modules, and the automated contract/playerless playback does not prove human reachability or visual fidelity.

### Organ change

`OrganAbilityMap` maps each organ to one exterior ability and one required data-driven loss contract. Destruction is idempotent and always removes the intact ability. Seven loss contracts remain runtime-selectable as safer `aimed_fan`, `ring`, or `lane` replacement patterns with bounded projectile counts, speeds, damage, readable gaps, and telegraphs that cannot be shorter than the intact warning. Five loss contracts seal the system and remove it from the attack pool entirely. The legacy `enabled` field continues to mean “intact ability,” while `runtime_enabled`, `status`, `variant`, `strength`, `telegraph_multiplier`, and `pattern` describe the actual post-loss state.

Every launch organ owns a distinct mechanical variant and `visual_token`. `RunScene` consumes the transformed attack contract and preserves cause/wave identity for damage attribution; `BossVisual` draws all 12 specific exterior states; the HUD selects localized English/Hebrew transformed-versus-disabled feedback. A dedicated 325-assertion suite validates the full catalog, seven/five split, exact described replacement patterns, validation guardrails, live `RunScene` projectile consumption, readable ring telegraph alignment, unique visuals, isolation, and idempotency. This is logic/render-path evidence, not human readability, fairness, or target-device visual QA.

### Final core and rewards

After all three organs are destroyed, the run returns to a final exterior core-health phase. `SaveManager.bank_run()` deduplicates the result by `run_id`, awards retained Bio-Matter, awards Story-mode Core Shards on victory, records clears, unlocks later bosses/weapons, and advances the Nest stage.

## Player, weapons, and projectiles

`PlayerController` owns touch tracking, smoothing, bounds, health, shield hits, dash charges, invulnerability, and the craft drawing. The default touch target is offset upward by 82 pixels.

`ProjectilePool` uses reusable dictionaries with hard limits of 190 player projectiles and 350 hostile projectiles. Segment-to-circle collision prevents fast shots from tunneling through round targets.

`RunScene` currently implements:

- pulse auto-fire;
- scatter projectile spread and short lifetime;
- rail piercing;
- three-hop bounded arc-chain behavior;
- orbitals that consume hostile shots and apply proximity damage.

Rail Spine can still miss multiple collinear targets crossed in one physics step because the pool resolves one collision per projectile per step; this is documented in `KNOWN_ISSUES.md`.

## Mutation and permanent-stat architecture

`MutationEngine` is data-driven:

- keys ending in `_mul` multiply a run stat;
- keys ending in `_add` add to a run stat;
- all other keys become behavior flags;
- selected IDs cannot be applied twice;
- offers exclude already-selected IDs.

This keeps definition authoring separate from offer logic, while explicit contracts reject unknown or unwired content. All 42 current mutation effect keys have runtime consumers and behavioral coverage. `PermanentUpgradeEngine` similarly validates all 18 permanent-effect keys, aggregates/clamps their values, rejects invalid requirements, and supplies `RunScene` and the Forge purchase gate. Focused tests exercise each effect and prerequisite. These tests establish code behavior, not human balance or game feel.

## Tutorial and meta-goal architecture

`TutorialFlow` owns a versioned ten-step comprehension bitmask plus a separate presentation-only replay mask. Gameplay emits observed movement, fire, Dash or avoided-telegraph defense, armor, Dive, organ, mutation, exterior-change, phase/death, and Forge events; completed steps are idempotent and persisted. `RunScene` considers a real telegraphed volley avoided only after all of its projectiles are gone, the player took no hit, and no Dash occurred since the telegraph began. Replay requests reset only presentation, survive the `RunScene` to Nest handoff, and complete on the later Forge event without erasing comprehension history.

`MetaGoalService` validates 14 achievement definitions and 19 contract definitions, normalizes/migrates profile state, applies idempotent local events, and deterministically selects one hunt, one build, and one skill contract for each UTC day. Exact-once reward defense uses bounded SHA-256 event receipts and a durable reward ledger; at the 4,096-receipt cap, new goal-changing events fail closed instead of evicting prior receipts. The caller persists pending changes in the versioned profile. The Rift Terminal and Trophy Chamber render these local goals. No account, remote rotation authority, or online claim verification exists.

## Save integrity

The current save schema is `6`.

```text
profile dictionary
  -> JSON payload string
  -> SHA-256 checksum envelope
  -> temporary file
  -> previous primary rotated to backup
  -> temporary promoted to primary
```

Load order is primary, backup, then defaults. Migrations cover earlier `bank` data, contracts, Abyss unlock, transaction, tutorial, and meta-goal state. Missing nested defaults are merged recursively. Legacy `tutorial_complete=true` maps to `TutorialFlow.FULL_MASK`, while replay presentation remains separate. The latest main headless test deliberately corrupts the primary and verifies restoration from the prior backup.

This is local integrity and crash recovery, not encryption or cloud conflict resolution. Settings exposes Reset Progress. A successful reset persists defaults, replaces the rotated pre-reset backup with a clean-default recovery generation, and calls idempotent local-data cleanup on both `AnalyticsService` and `LeaderboardService`; the latter removes its primary, backup, and temporary outbox files. The flow does not create a cloud-side deletion request because no backend or cloud record exists.

## Local challenge modes

- **Daily Rift:** derives a stable UTC date seed and selects a deterministic boss and weapon.
- **Friend Rift:** encodes boss, seed, weapon, difficulty, modifiers, targets, and a short checksum into an `ID1` code.
- **Abyss Loop:** advances depth after a victory when the player selects retry, rotates bosses, carries selected mutations, and scales HP, damage, and projectile speed.

`RemoteConfigService` loads only a bundled JSON snapshot and fails closed: it has no HTTP client, provider, or endpoint and all online/monetization flags default off. After every completed run, `RunScene._complete_run()` calls `_submit_result_offline()` after reward banking. `LeaderboardService` validates the whole summary. Story/Abyss calls return `local_only_noncompetitive` and do not enter the upload outbox. Daily/Friend calls must carry a canonical challenge ID derived from the UTC day or Friend payload; accepted summaries are deduplicated, checksummed, and stored atomically without mixing different challenges. They still cannot upload: `flush_pending()` deterministically reports that transport is disabled or unavailable. There is no backend, account system, remote daily configuration, rate limiting, server-side score validation, or competitive leaderboard UI.

## Rendering, UI, and audio

- Rendering uses Godot's GL Compatibility path and procedural `_draw()` methods.
- The logical portrait viewport is `540 x 960` with `canvas_items` stretching.
- HUD and Nest Controls use the shared safe-area adapter, but still contain many fixed logical coordinates inside the fitted design surface.
- Boss silhouettes are distinct procedural drawings; all 12 organ losses have unique exterior procedural states, while the internal organ drawing remains shared and palette-driven.
- Audio is generated at runtime as mono PCM, with a 12-player SFX pool and three adaptive music players. Nine state profiles and four boss profiles alter register, tempo, intervals, timbre, layer gain, and selected SFX pitch. Live armor, organ, and phase cues use per-ID rate limiting.

## Testing and export boundary

`tests/test_runner.gd` is a custom headless suite. It must run with `INFINIDIVE_TEST_ISOLATED=1` and an isolated temporary `XDG_DATA_HOME`; the guard was exercised both ways, exiting 1 with `0/1` when omitted and exiting 0 with `2,538/0` when isolated. Seven focused suites also pass: backend/offline 82, permanent upgrades 120, tutorial 198, room mechanics 2,583, meta goals 111, adaptive audio 505, and organ transformations 325, for 6,462 assertions across eight invocations with zero failures. Coverage includes data integrity, all boss/organ orders and loss variants, malformed and fuzzed challenge codes, mutation/weapon/permanent-effect behavior, tutorial contracts, real no-hit/no-Dash telegraph avoidance and cross-scene replay, localization/RTL widgets, analytics opt-out, complete local Reset Progress cleanup, canonical challenge identity and offline/config boundaries, safe-area math, room playback invariants, meta goals, adaptive-audio contracts and rate-limited live cue call sites, projectile/movement/dash/shield behavior, save recovery/migration/banking, the outside-inside-outside hook, 24 complete deterministic victories, and a combined UI failure/bank/Forge/110-HP/second-failure/instant-retry flow whose saved profile is verified from a separate Godot process. A current-tree 90.02-second structural soak passed 1,563 pressure/projectile cycles, 157 restarts, 157 Dive transitions, 78 save writes, and 676 offline events with peak 540 projectiles, unchanged source fingerprint, and zero failures. It does not prove human control feel, browser/device presentation, target-device performance, background/force-close behavior, migration from a previously shipped fixture, repeated Abyss depths, or native installation; the older 30-minute soak retains its concurrent-edit caveat.

`export_presets.cfg` defines Web, Android debug APK, a separate Gradle Android AAB, and iOS outputs. Both Android presets request only the normal `android.permission.VIBRATE` permission required by optional haptics. The verified CI installer extracts `android_source.zip`; a clean combined debug export invokes `--install-android-build-template` and creates `android/build`, proving Gradle project generation without proving an AAB. The current-working-tree Web export under `../../build/web/` passes static validation with recorded HTML/PCK/WASM hashes in `PROJECT_STATUS.md`. The current debug APK is 28,878,673 bytes with recorded SHA-256 and passes structural validation; the local exporter warned of build-tools 34.0.4 fallback while targeting 36. It uses the Debug signer and has not been installed; no AAB exists because complete build-tools 36 and release signing remain unavailable. Full current-tree iOS project export failed because the checked-in preset has a blank Development Team. `--export-pack iOS` refreshed only the current PCK inside the retained earlier 47-file scaffold; the unchanged pbxproj/plist and refreshed PCK hashes are recorded in `PROJECT_STATUS.md`. This is not a full current Xcode export, and nothing has been compiled, archived, signed, simulator-run, or installed.

The committed workflow at `../.github/workflows/infinidive-ci.yml` imports, tests, exports Web and Android debug, browser-smoke-tests the Web export, and attempts Pages deployment on `infinidive-production`. Actions run 33514397476 validated current commit `8e4be78267a043072827963d6492c7964239ae94`: all eight suites, Web export/Chromium boot, and Android debug with build-tools 36 passed. Deploy job 99878161111 failed exactly at Get Pages `Not Found` / Create Pages `Resource not accessible by integration`. The game, support, and privacy URLs remain HTTP 404 with no canvas, so no public-host success is recorded.

## Current architectural risks

- `RunScene` is the central gameplay orchestrator and is already the largest script; boss patterns, rewards, modes, tutorial events, and mutation consumers should be separated before content expansion.
- Mutation and permanent-effect contracts are complete, but their balance and combined feel have not been human-tested.
- Room-contract timing, gap consistency, active caps, cleanup, and hitch playback are automated, while runtime presentation still collapses them to three broad execution geometries with a generic defender; human reachability remains untested.
- The implemented safe-area layer still wraps fixed-coordinate UI; adaptive layout and real notch/device QA remain necessary.
- A remote leaderboard/config transport, authentication, server verification, and cloud save do not exist; any future adapters must remain optional so offline play stays authoritative.
