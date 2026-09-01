# INFINIDIVE QA Matrix

Last verified: 2026-09-01\
Project version: `0.1.0`\
Engine: Godot `4.7.2.stable.official`\
Current quality level: production foundation / playable pre-alpha, not a release candidate

This document separates automated evidence, browser emulation, simulator testing, and physical-device testing. A row marked `PASS` only covers the environment and assertions named in that row. No physical-device testing has been performed yet.

## Status legend

| Status | Meaning |
|---|---|
| PASS | Executed successfully with retained evidence |
| PARTIAL | Some automated or structural evidence exists, but the complete acceptance condition was not exercised |
| NOT RUN | Test has not been executed |
| BLOCKED | A required environment, credential, build, or service is unavailable |
| N/A | Feature is intentionally disabled or absent in this build |

## Current automated evidence

| Evidence | Result |
|---|---|
| Linux headless Godot main suite | `2,631 passed, 0 failed` in `artifacts/headless-tests.xml` |
| Final frozen 13-suite local matrix | Main `2,631/0`; backend/offline `82/0`; permanent upgrades `120/0`; tutorial `198/0`; room mechanics `3,541/0`; compiler `15,515/0`; pure defender effects `354/0`; live defender effects `212/0`; projectile travel `685/0`; live integration `4,131/0`; organ transformations `325/0`; meta goals `111/0`; adaptive audio `505/0` |
| Final frozen matrix total | `28,410 passed, 0 failed` across 13 invocations; editor import and all suites passed the strict wrapper with zero engine `ERROR`, script-error, or parse-error lines. Canonical production fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`; tracked tests/CI fingerprint `e0af48b5b24e2333c928e685eccd12991c22f05d4cd8c37dc1c08f926bcb756b`. The production calculation deliberately excludes `assets/store/gameplay/raw/`, whose continuous provenance capture is local-only, untracked, and absent from every export; all tracked production and exported game inputs remain covered. The JUnit file contains the `2,631/0` main suite. |
| Remote current-source CI | Workflow-evidence commit `1e8b568` is pushed on `infinidive-production`. Actions run `33559947112` completed overall `PASS`, including validation, Web/Android exports, deploy/public-host smoke, and 30-minute long-soak job `100030992601`. Artifact `9822001845` retains the source-bound long-soak evidence. |
| INF-P1-006 six-suite frozen result | Mechanics `3,541/0`; compiler `15,515/0`; pure defender effects `354/0`; live defender effects `212/0`; projectile travel `685/0`; live integration `4,131/0` — `24,438 passed, 0 failed` across six invocations |
| INF-P1-006 contract coverage | All seven travel IDs at 30/60 Hz; player homing at 30/60/120 Hz; lane topology; full digest-bound previews; actual-homing suppression without straightening; swept pre-retirement and first-contact collision; nonlinear/homing subsegments without safe metadata; exact `16/3s` first-exit handling; safe-radius hits; compiler-signed cleanup; pool reuse; bounded fallback; minimum-TTK audit `0` failures |
| Strict harness boundary | The inventory validator discovers 13 standalone suites, one nested relaunch probe, and one soak scene. Every runnable scene gets an isolated data root; process failure, any engine `ERROR`, script/parse error, exact-sentinel/count drift, stale inventory, or invalid/missing soak report pair fails closed. The validator recomputes current production source and requires complete two-phase result/transaction/completion/bound-hash and semantic exercise contracts; self-tests cover `PASS`, partial/source-change `FAIL`, fractional duration, cleanup-pending, stale evidence, and strict negatives. |
| Headless boot smoke | Main project booted with `--quit-after 30` under an isolated XDG data directory, exit 0, and no emitted errors; no renderer/browser/device claim |
| Execution mode | Main is headless, fixed 60 Hz, single-threaded scene tree; room-runtime coverage separately exercises 30/60 Hz and hitch-style deltas |
| Save isolation | Guard test without the flag exited 1 with `0 passed, 1 failed`; the current suite with `INFINIDIVE_TEST_ISOLATED=1` plus temporary `XDG_DATA_HOME` exited 0 with `2,631/0`; no production/player profile used |
| JUnit report | `artifacts/headless-tests.xml` |
| Current-source 30-minute soak | Actions run `33559947112`, job `100030992601`, artifact `9822001845`: `PASS` at `1800.043s`, 26,676 cycles, 2,668 restarts / 2,668 Dives, 1,335 saves / 22 reloads, 3,188 queued events / 24 queue reloads / final 500, 1,636,943 player and 3,216,180 enemy projectile spawns, peak 540, baseline/final nodes 11/10, orphan peak 0, 7/7 travel models, and zero failures. Fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`; transaction `5c047f1a630e8e1de5c5ffff`; JSON `2f8171e8317572f31fd479884edcaa441452082640a9be4f3fe9339da02710b4`; Markdown/bound hash `a508864e78c75981e8221df2c53f0ed97c82501295e999328fa86b78970f1856`. Stable delta 3,667,676 bytes; slope 84,517.9971965645 B/min. |
| Soak reports | `artifacts/soak-30m.json` and `artifacts/soak-30m.md` |
| Soak source-lock smoke | `5.010s`, identical start/end source fingerprint, zero failures (`artifacts/soak-fingerprint-smoke.json`) |
| Current bounded soak | `8.031s`, 86 cycles, 9 boss restarts / 9 Dives, 6 saves, 529 queued offline events / 2 queue reloads / final queue 500, peak 540, 7/7, unchanged fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`, complete transaction `9ac05a1b4bcc696001e5a6e7`, zero failures. JSON `d8d5c6c5b0667f3b53844839f5955841430e85842ea168220c1a0d8ca4b5c1e9`; Markdown/bound hash `9ba26093ba394c70b591130544a21094e719d0801d55755d82fd0e5c93814c27`. |
| Paused breach-entry regression | While `BREACH_OPEN` is paused, `_request_dive()` is rejected and the pause overlay remains authoritative; manual resume restores the legal Dive path | PASS in the `2,631/0` main suite |
| Current 90-second soak | Same transactional/source-lock acceptance as the bounded smoke | PASS — `90.048s`, 1,169 cycles, 117 restarts / 117 Dives, 60 saves / 1 reload, 637 queued offline events / 3 queue reloads / final queue 500, peak 540, 7/7, stable delta 90,040 bytes, slope 218,786.041893738 B/min, complete transaction `26dad83d28067418d76982a3`, zero failures. Fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`; JSON `2bc054556fe9e0c75813feb7e50dfcae5844c8140e4491bfd599e9129309c4c1`; Markdown/bound hash `026962ed338b02db99cfee0ecb08bc16b197c9b2abd1544214e11ed61e69ab83`. |
| Transactional report recovery | Full-schema JSON/Markdown stage and commit as a two-phase pair with JSON-bound Markdown hash; completion is set only after cleanup; stale source/recovery reports are rejected; partial/early and source-change diagnostics persist as `FAIL` | PASS (writer transaction tests and CI `PASS`/diagnostic/negative fixtures; transaction-subsystem red-team found 0 P0/P1/P2) |
| Reproducible command | Shown below |

```bash
qa_data_root=$(mktemp -d)
INFINIDIVE_TEST_ISOLATED=1 \
XDG_DATA_HOME="$qa_data_root" \
  /workspace/scratch/2209a1fdf3a0/.runtime/Godot_v4.7.2-stable_linux.x86_64 \
  --headless \
  --fixed-fps 60 \
  --single-threaded-scene \
  --path . \
  --scene res://tests/TestRunner.tscn
```

The long soak is intentionally separate from the fast CI suite:

```bash
soak_data_root=$(mktemp -d)
INFINIDIVE_SOAK_ISOLATED=1 \
XDG_DATA_HOME="$soak_data_root" \
  /workspace/scratch/2209a1fdf3a0/.runtime/Godot_v4.7.2-stable_linux.x86_64 \
  --headless \
  --max-fps 120 \
  --path . \
  --scene res://tests/soak/SoakTest.tscn \
  -- --duration-seconds=1800 --seed=203541 --report-stem=soak-30m
```

## Automated functional coverage

| ID | Area | Assertions exercised | Status |
|---|---|---|---|
| DATA-001 | Release content manifest | Four bosses, five weapons, at least 24 mutations, 18 upgrades, 30 non-chamber room modules, and 12 organ chambers load and validate | PASS |
| DATA-002 | Stable identifiers | Required data collections contain valid unique IDs and every boss has three distinct organ ability mappings | PASS |
| CONFIG-001 | Portrait project configuration | Canvas-item stretching, expanded aspect handling, portrait orientation, and Web Compatibility renderer are configured | PASS |
| SAFE-001 | Safe-area math | Native top/bottom insets convert to logical coordinates and the fitted design rect remains inside the safe area | PASS |
| ORG-001 | Organ-to-ability mapping | Destroying every organ removes its intact ability; seven loss contracts retain a safer replacement and five disable the system completely | PASS |
| ORG-002 | Isolation | Destroying one organ does not alter unrelated boss abilities | PASS |
| ORG-003 | Idempotency | A destroyed organ cannot apply its effect twice; unknown organ IDs do not mutate state | PASS |
| ORG-004 | Organ order | All six permutations for each of the four bosses reach an all-organs-destroyed state | PASS |
| ORG-005 | Loss-contract catalog | All 12 organs validate unique mechanical variants and unique supported `BossVisual` tokens; the seven-transform/five-disable split is enforced | PASS (325-assertion focused suite) |
| ORG-006 | Exact post-loss mechanics | Straight Hunter salvo, wider/slower Gravity/Vortex rings, longer two-lance Prism warning, permanent Wing safe flank, fractured Halo opening, single unchained Shock arc, and five complete shutdowns match their data | PASS (focused suite) |
| ORG-007 | Live transformed attacks | `RunScene` spawns every degraded contract with its bounded projectile count plus attributable cause/wave identity, and localized EN/HE changed/disabled messages exist | PASS (focused/main suites); human readability/balance not proven |
| RIFT-001 | Friend Rift round trip | Boss, seed, weapon, difficulty, modifiers, score, and time payload can encode/decode deterministically | PASS |
| RIFT-002 | Friend Rift tamper guard | Modified challenge code is rejected | PASS |
| RIFT-003 | Daily seed | Identical UTC date input produces identical seed | PASS |
| RIFT-004 | Malformed Friend Rift input | 16 empty, truncated, overlong, structurally invalid, and correctly checksummed but invalid payloads are rejected | PASS |
| RIFT-005 | Friend Rift fuzz | 160 seeded valid payloads round-trip exactly and 128 seeded raw inputs fail closed | PASS |
| MUT-001 | Mutation offer | Fixed seed produces an identical offer without duplicate choices | PASS |
| MUT-002 | Mutation application | A mutation applies once and its configured stat operation is reflected | PASS |
| UPGRADE-001 | Permanent-effect contract | All 18 launch keys validate, aggregate/clamp, and expose focused behavioral values | PASS (focused suite) |
| UPGRADE-002 | Forge purchase gate | Invalid definitions, maximum levels, cost, and Starting Sheath prerequisite fail closed | PASS (focused suite) |
| TUTORIAL-001 | Tutorial state | Ten events are idempotent/out-of-order safe, serialize/restore, and require all bits for completion | PASS (focused suite) |
| TUTORIAL-002 | Runtime presentation | Live call sites exist for the primary path; replay-on-next-run persists through the Run-to-Nest handoff and completes on Forge | PASS; a real telegraphed volley emits avoided only after it ends without hit or Dash |
| ROOM-001 | Internal generation | Every boss/organ route is deterministic for a fixed seed | PASS |
| ROOM-002 | Layout safety contract | Generated route starts at an entrance, ends at the correct chamber, and every hazard declares a safe rule | PASS |
| ROOM-003 | Hazard contract catalog | All 42 hazard profiles produce deterministic, structurally bounded mechanics metadata; consecutive telegraphs begin only after the previous damaging window and the final clear does not trail exit opening | PASS (`RoomMechanicsTest` frozen `3,541/0`) |
| ROOM-004 | Pure runtime-plan compiler | Every launch room maps through the complete registry into a deterministic, validated, fail-closed plan; source and compiled `safe_lane`/`movement.lane` remain within `lane_count` | PASS — frozen compiler suite `15,515/0` |
| ROOM-005 | Live category/movement execution | `RunScene` exercises all eight categories and all six movement models with category-specific motifs, force fields, structural shapes, projectile travel, defender actors, and a complete frozen preview payload validated before side effects | PASS — frozen live-integration suite `4,131/0` |
| ROOM-006 | Structural collision and presentation parity | Safe-disk clearance holds for compiled and moved motif geometry; box/cell/arc/segment collision is swept under hitch deltas; stroked render width matches collision diameter | PASS — covered by frozen compiler/integration suites; no human/device readability claim |
| ROOM-007 | Projectile threat and safe corridor | Digest-bound previews exclude the protected pocket; all seven travel IDs run at 30/60 Hz; player homing agrees at 30/60/120 Hz; collision sweeps before retirement in first-contact order; nonlinear paths follow subsegments; first exit remains terminal under exact `16/3s` node-link hitch | PASS — frozen `ProjectileTravelModelsTest` `685/0`; no human/device claim |
| ROOM-008 | Defender actor lifecycle and feasibility | Ten archetypes use bounded actor groups separate from transient emitters; all twelve defender-producing profiles have a minimum TTK below their 3.2s/4.0s actor window | PASS — TTK audit 0 failures; human aim/readability not proven |
| ROOM-009 | Defender kill effects and lineage | Pure effect plans validate/cap/deduplicate operations; live compiler-signed source-wave cleanup, same-lineage successor effects/cover, unrelated-lineage survival, expiry, and tracking suppression are exercised. Suppression removes actual-homing owned threats and pending specs instead of straightening them; non-homing and foreign-owned controls survive. | PASS — pure `354/0`, live frozen `212/0` |
| ROOM-010 | Replay, previews, caps, and atomic cleanup | Recorded/replay motifs depend on frozen input history; full projectile previews are built once and digest-bound before side effects; fixed-step results stay deterministic; caps hold; transition/cycle cleanup removes only canonical owner/cycle motifs, emissions, projectiles, actors, and effect state | PASS — frozen live-integration `4,131/0` plus focused ownership/effect suites |
| PROJ-001 | Fast projectile collision | Segment-circle collision catches a projectile that crosses a target between frames | PASS |
| PROJ-002 | Pool lifecycle | Player/enemy projectiles return to reusable pools after hit or clear | PASS |
| PROJ-003 | Pool cap | Exactly the configured player-projectile capacity is accepted and excess allocation is rejected | PASS |
| PROJ-004 | First arena exit | A recorded path that exits and re-enters in one hitch retires at its first boundary crossing and cannot hit after re-entry; a real hit before that first exit remains valid | PASS (frozen travel suite) |
| MOVE-001 | Finger offset | Screen input maps to the intended canvas target with the configured vertical offset | PASS |
| MOVE-002 | Movement and bounds | Dragging closes distance to the target; player and target remain within combat bounds | PASS |
| MOVE-003 | Frame-rate independence | Equivalent one-second movement at 30 and 60 physics steps remains within a 12 px tolerance | PASS |
| COMBAT-001 | Dash invulnerability | Damage is rejected during the dash window and accepted afterwards | PASS |
| COMBAT-002 | Dash charge | A charge cannot be spent twice and returns only after the configured cooldown | PASS |
| COMBAT-003 | Shield | One shield absorbs one hit without reducing hull | PASS |
| SAVE-001 | Atomic generations | A second save rotates the previous valid generation into backup | PASS |
| SAVE-002 | Corruption recovery | Invalid primary JSON recovers the checksum-valid backup | PASS |
| SAVE-003 | Migration | Schema 1 bank, settings, contracts, Abyss unlock, transaction, tutorial, and meta fields migrate into schema 6 defaults; legacy `tutorial_complete=true` maps to `TutorialFlow.FULL_MASK` | PASS for automated source fixtures; installed-app update remains untested |
| SAVE-004 | Reward banking | A valid run banks once; both immediate and old run IDs remain non-bankable after more than 30 subsequent transactions | PASS |
| SAVE-005 | Persistence | Banked currency, unlocks, and processed run ID survive teardown/reload | PASS |
| SAVE-006 | Intentional local reset | Confirmed reset replaces profile/backup with defaults and idempotently removes analytics plus leaderboard primary/backup/temporary files | PASS for service/UI contract; human interaction and forced I/O failure presentation remain untested |
| LOC-001 | Localization completeness | English and Hebrew tables contain identical non-empty keys | PASS |
| LOC-002 | Direction/fallback | English is LTR, Hebrew is RTL, language switch changes copy, and a missing key remains visible | PASS |
| SETTINGS-001 | Required settings | Default save includes the required audio, accessibility, control, language, and privacy settings | PASS |
| ANALYTICS-001 | Event contract | Every required product event exists in the analytics abstraction | PASS |
| ANALYTICS-002 | Privacy opt-out | Opted-out analytics does not enqueue an event; nested/unsupported properties are discarded | PASS |
| BACKEND-001 | Offline result staging | Canonical Daily/Friend summaries remain challenge-separated, duplicates reject, Story/Abyss stay out of the outbox, checksummed backup recovers, and transport fails closed | PASS (focused suite) |
| META-001 | Local goals | Fourteen achievements and nineteen contracts validate; UTC rotation, migration, bounded SHA receipts, fail-closed saturation, idempotent progress, and rewards behave deterministically | PASS (focused suite) |
| AUDIO-001 | Adaptive audio contract | Four boss profiles, nine three-layer states, SFX coloring, cache bounds, invalid-input fallback, headless safety, and rate-limited live `armor_hit`/`organ_damage`/`boss_phase` emission behave deterministically | PASS (focused/main suites); listening and mobile profiling not performed |
| HOOK-001 | Outside-inside-outside | Armor breaks, breach opens, organ is selected, internal route reaches chamber, organ dies, mutation is chosen, and play returns outside | PASS |
| HOOK-002 | Visible mechanical consequence | The destroyed organ remains destroyed; its intact ability is removed and its authored degraded-or-disabled loss contract plus unique exterior state persists after returning outside | PASS |
| HOOK-003 | Transition guards | Duplicate breach/dive requests, invalid organ IDs, and invalid mutation IDs cannot skip or duplicate the state transition | PASS |
| RUN-001 | Full three-organ boss victory | All 24 combinations of four bosses and six organ orders complete three dives, disable the selected abilities, expose the core, win, bank configured rewards once, and retain deterministic identity | PASS |
| RUN-002 | Failure, reward, Forge purchase, retry | Real result/Nest/Forge controls bank a 55-Bio failure, buy Reinforced Hull, start a 110-HP run, bank a second failure, and press instant retry | PASS (main suite) |
| SAVE-007 | Separate-process relaunch | A new Godot process loads the primary profile and verifies Bio-Matter, two total runs, Reinforced Hull level, and both processed run IDs | PASS (main suite) |
| ABYSS-001 | Endless progression | Multiple consecutive Abyss depths with carried state and scaling | NOT RUN |

## Browser and export matrix

| Target | Scope | Status | Notes |
|---|---|---|---|
| Web export artifact | HTML, JavaScript, WASM, PCK presence, excluded tooling/adaptive sources, unresolved-shell token checks, and local HTTP paths | PASS (static/local HTTP and CI export) | Current HTML 2,618 / `65c3d9b290b3b3eb4baab5e8d677edee04ea3d0f4dc8331cf792e275a30c9f61`; JS 279,815 / `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba`; PCK 625,812 / `33283d7cfcf37fc5b1b5ccd5f77254766839bb674f9c8e1bd50cb7c3640ed43d`; WASM 39,514,754 / `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`. Local HTTP paths passed, and Actions run `33557365042` attempt 2 validated/exported the exact-tree commit `67e2c54`. |
| Headless Chromium | Serve export over HTTP and wait for Godot `startGame()` completion | PASS (current CI-served export) | Actions run `33557365042`, attempt 2, exported commit `67e2c54` and booted that output in headless Chrome successfully. This is not touch-gameplay, public-host canvas, Safari, or physical-device evidence. |
| Chromium mobile viewport | Real canvas pointer drag, dash, core hook, and reload persistence | NOT RUN | Requires semantic QA probe or equivalent observable state |
| WebKit mobile viewport | Boot, canvas resize, safe-area layout, and basic pointer path | NOT RUN | Playwright WebKit is not physical Mobile Safari |
| Public GitHub Pages URL | Post-deploy HTTP and runtime smoke at `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` | PASS (HTTP + boot) | Deploy job `100024023277` in Actions run `33557365042` attempt 2 passed. Run `33559947112` bound the deployed artifact to commit `1e8b568`, fetched the live index/privacy/support/PCK/WASM, and booted the public URL with HTTP 200, Godot 4.7.2/WebGL2, a 540×960 canvas, hidden loading status, and zero page/console errors. Artifact `9821030353` retains the evidence. This is not a touch-gameplay, Safari, or physical-device result. |
| Android debug APK | Manifest, permission, alignment, signature, then install/launch/lifecycle smoke | PARTIAL | Current APK `INFINIDIVE-0.1.0-prealpha-debug-e942db6f.apk` is 29,063,530 bytes / `d089cebf2207391634fa6b2719d9b8c0a56e654619c33b05292e47aacc78bfa6`; structural validation passed. No AAB, emulator/device install, or lifecycle result. |
| Android Gradle template path | Verified template install and Gradle project generation | PASS (structural) | Verified installer extracts `android_source.zip`; integrated debug export with `--install-android-build-template` creates `android/build`. This does not prove bundle compilation or signing. |
| Android release AAB | Release export and Play internal-test install | BLOCKED | Separate Gradle/AAB preset exists; artifact still needs resolvable Gradle dependencies, complete SDK/build-tools 36, private signing, and Play access |
| iOS Xcode project | Unsigned iPhone-targeted project structure and compile | PARTIAL / BLOCKED | Unsigned package `INFINIDIVE-0.1.0-prealpha-ios-unsigned-e942db6f.zip` contains current-source PCK 625,908 / `8cf2bd0732b1df958f65958cd45fee65d2387527f6a7cf08b6287dff1f3ccf83`; its headless main-pack probe passed. No Xcode compile/archive, signature, simulator run, install, or TestFlight result. |
| TestFlight archive | Signed installable build | BLOCKED | Requires Apple signing assets/account action |

## Required physical-device matrix

| Device/environment | Required checks | Status |
|---|---|---|
| Small iPhone display | UI clipping, readable text, drag reach, safe path visibility | NOT RUN |
| Large modern iPhone | 9:16 adaptation, HUD reach, sustained frame pacing | NOT RUN |
| iPhone with Dynamic Island | Top safe area, overlays, pause/settings, notification interruption | NOT RUN |
| Mid-range Android | 30/60 FPS behavior, thermals, projectile stress, memory | NOT RUN |
| High-refresh Android | Frame-independent movement, cooldowns, animation pacing | NOT RUN |
| Mobile Safari | Public URL boot, audio unlock, touch drag, reload save | NOT RUN |
| Mobile Chrome | Public URL boot, touch drag, background/resume, reload save | NOT RUN |

No row in this section may be changed to `PASS` without naming the actual device/model, OS version, build identifier, tester, and result evidence.

## Lifecycle, interruption, and offline matrix

| Scenario | Automated evidence | Device evidence | Overall status |
|---|---|---|---|
| Fresh profile | Default profile and isolated save path load during headless suite | None | PARTIAL |
| Upgrade from schema 1 save | Schema migration and nested defaults verified | No installed-app upgrade | PARTIAL |
| Corrupt primary save | Backup recovery verified | No forced-close device exercise | PARTIAL |
| Duplicate reward submission | Immediate and older replayed run IDs rejected after more than 30 later transactions | No background/kill interruption | PARTIAL |
| Airplane mode | Core systems have no required network calls | Not exercised in an installed build | NOT RUN |
| Unstable connection | No online backend connected | Not exercised | NOT RUN |
| Background/resume | Headless application-notification tests verify pause/save locking across focus loss and mobile suspend | No installed-app/native lifecycle exercise | PARTIAL |
| Phone-call interruption | Not automatable in current Linux runner | Not exercised | NOT RUN |
| Low-power mode | Not automatable in current Linux runner | Not exercised | NOT RUN |
| Audio interruption | No audio-session interruption harness | Not exercised | NOT RUN |
| English/Hebrew switch | String parity, direction flag, and fallback verified | Visual layout/clipping not exercised | PARTIAL |
| Web IndexedDB reload | Native `user://` save verified only | Browser reload not exercised | NOT RUN |
| Restore Purchases | Billing is intentionally disabled | None | N/A |

## Performance and soak matrix

| Test | Acceptance target | Status |
|---|---|---|
| Projectile allocation stress | Pool cap respected; no uncontrolled allocation | PASS — current-source 30-minute run completed 26,676 pressure cycles with 1,636,943 player plus 3,216,180 enemy spawns; peak 540 simultaneous |
| Current-source 30-minute headless structural soak | Complete at least 1,800 wall-clock seconds without crash, soft-lock, recorded failure, source drift, or sustained high memory growth | PASS — Actions run `33559947112`, job `100030992601`, artifact `9822001845`; `1800.043s`, fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`, 7/7 travel models, zero failures, and complete bound transaction `5c047f1a630e8e1de5c5ffff` |
| Source-locked transactional soaks | Confirm no source drift, semantic exercise, 7/7 models, complete two-phase pair, and current-source fingerprint | PASS — `8.031s`, `90.048s`, and `1800.043s` pairs share unchanged fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`, complete distinct transactions, and record zero failures |
| Repeated boss restart | At least 100 restarts without retained run nodes/projectiles | PASS — 2,668 restarts; baseline/final nodes 11/10, zero orphan nodes |
| Repeated dive transition | At least 100 transitions without duplicate triggers or retained internal state | PASS — 2,668 complete outside-inside-outside transitions |
| Save stress | Repeated atomic writes plus periodic reload/backup validation | PASS — 1,335 writes and 22 reload checks |
| Offline analytics queue | Persist, cap, reload, and continue while no backend is present | PASS — 3,188 events, 24 reloads, final queue capped at 500 |
| Static memory trend | Measure after a five-minute warm-up | PASS — peak 44,854,607 bytes; +3,667,676 bytes over the stable window; regression slope +84,517.9971965645 B/min |
| Web cold start | Approximately four seconds on representative hardware | NOT RUN |
| Native frame rate | Stable 60 FPS where realistic, graceful 30 FPS fallback | NOT RUN |
| App size | Preferably below approximately 250 MB | NOT RUN |

The soak result is Linux Godot headless structural evidence only. It does not measure GPU rendering, frame pacing, thermals, battery, haptics, native audio, browser behavior, touch feel, Android performance, or iPhone performance.

The current tree passed the complete 13-suite matrix (`28,410/0`) plus source-locked transactional soaks at `8.031s`, `90.048s`, and `1800.043s`. The full-duration pair was produced by Actions run `33559947112`, long-soak job `100030992601`, retained as artifact `9822001845`, and validated against the same canonical production fingerprint with zero failures. The canonical production inventory intentionally omits only the local-only, untracked, non-exported continuous capture under `assets/store/gameplay/raw/`; that provenance file is not game input and cannot affect a shipped build.

## Quality-gate status

| Gate | Status | Evidence still required |
|---|---|---|
| Gate 1 — Control feel | PARTIAL | Mathematical movement/dash behavior passes; real touch comprehension, accidental dash rate, readability, and attributable deaths require human device sessions |
| Gate 2 — Core hook | PASS (automated alpha) | Headless production systems complete the outside-inside-organ-outside sequence; all 12 losses have concrete data-driven mechanics and procedural exterior states, but human/device readability remains untested |
| Gate 3 — Complete run | PARTIAL | All boss/order victories pass, and the combined UI failure/bank/Forge/110-HP/second-failure/instant-retry/separate-process reload path passes; background/force-close, prior-build update, repeated Abyss, and human play remain |
| Gate 4 — Content complete | PARTIAL | Counts, effect contracts, tutorial/meta logic, all boss/order state machines, and authored room-runtime identities exist; human room/boss readability, cosmetics, mode polish, and real-time balance remain incomplete |
| Gate 5 — Release candidate | BLOCKED | Production-signed native exports/installs, semantic touch and Safari/mobile-browser runtime tests, lifecycle tests, target-device performance tests, and P0/P1 closure |
| Gate 6 — Launch ready | BLOCKED | Signed installs, final store assets/listings, legally reviewed public policies/notices, final device install, and store review |

## Open QA risks

| ID | Severity | Risk | Required resolution |
|---|---|---|---|
| QA-RISK-001 | P0 for release | No native build has been installed or exercised on a physical phone | Produce signed/internal builds and complete the physical-device matrix |
| QA-RISK-002 | P1 | Headless touch dispatch reaches the player and controller math passes, but exported browser/native touch delivery and feel are not proven | Add exported-canvas pointer tests and physical touch sessions |
| QA-RISK-003 | P1 | Room compiler/integration checks now exercise safe and unsafe probes, 30/60 Hz travel, hitch-swept geometry, actor windows, and cleanup, while complete-run simulations still accelerate broader combat and neither path proves human survivability, readability, fairness, or balance | Add real-time bot runs plus human sessions on target aspect ratios |
| QA-RISK-004 | P1 before online competition | Friend Rift checksum detects accidental/tampered payload changes but is not server authentication or score verification | Validate seeds, event summaries, rate limits, and idempotency server-side before enabling leaderboards |
| QA-RISK-005 | P1 | Browser `user://` persistence has not been verified through reload or storage failure | Add browser IndexedDB reload/corruption tests |
| QA-RISK-006 | P1 | RTL flag and copy are tested, but Hebrew layout, font glyphs, wrapping, and clipping are not | Run screenshot/manual review at small and large phone sizes |
| QA-RISK-007 | P1 for native performance | The current-source 30-minute Linux headless soak passes, but it does not measure rendering, frame pacing, thermals, battery, haptics, or native lifecycle behavior | Run an installed-build endurance pass on representative Android and iPhone hardware and retain profiler/device evidence |
| QA-RISK-008 | P1 | Organ-loss contracts and procedural render states are automated, but no human/device session proves that each change is immediately readable or balanced | Capture and play all 12 outcomes on target aspect ratios; record attribution, safe-path, and organ-order results |
| QA-RISK-009 | P1 | The 42 rooms now execute authored structural/projectile/movement/defender identities, but code-drawn category/token variation has not been visually reviewed on browsers or phones and automated corridors do not measure player comprehension | Run every category, defender archetype, and tightest travel case at small/large phone sizes; record deaths, missed telegraphs, and path comprehension |

## Next executable QA work

1. Add a semantic public-browser probe and drive real pointer/touch gameplay through movement, Dash, breach, Dive, organ destruction, return, and saved reload; the public-host boot itself now passes.
2. Add a QA-only observable snapshot and drive actual exported-canvas pointer input through the first core hook, all 12 organ-loss states, and representative room cases across all eight categories and ten defender archetypes.
3. Add a previously shipped save fixture, background/force-close reward interruption, and repeated Abyss-depth coverage; the combined UI progression/relaunch smoke now passes.
4. Add real-time attack-pattern safety and balance runs; the completed soak deliberately accelerates combat state transitions.
5. Install the canonical Android debug build, produce a full current-source iOS export/compile/archive, then complete the named physical-device matrix without extrapolating from headless or browser evidence.
