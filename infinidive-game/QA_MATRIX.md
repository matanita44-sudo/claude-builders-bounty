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
| Linux headless Godot suite | `2,538 passed, 0 failed` on the current working tree |
| Focused headless suites | Backend/offline `82/0`; permanent upgrades `120/0`; tutorial `198/0`; room mechanics `2,583/0`; meta goals `111/0`; adaptive audio `505/0`; organ transformations `325/0` |
| Eight-suite local total | `6,462 passed, 0 failed`; the retained JUnit file below contains only the 2,538-assertion main suite |
| Headless boot smoke | Main project booted with `--quit-after 3`, exit 0, and no emitted errors; no renderer/browser/device claim |
| Execution mode | Headless, fixed 60 Hz, single-threaded scene tree |
| Save isolation | Guard test without the flag exited 1 with `0 passed, 1 failed`; the same suite with `INFINIDIVE_TEST_ISOLATED=1` plus temporary `XDG_DATA_HOME` exited 0 with `2,538/0`; no production/player profile used |
| JUnit report | `artifacts/headless-tests.xml` |
| 30-minute soak result | `PASS` for the process snapshot loaded at soak start — `1800.019s`, seed `203541`, zero recorded failures |
| Soak reports | `artifacts/soak-30m.json` and `artifacts/soak-30m.md` |
| Soak source-lock smoke | `5.010s`, identical start/end source fingerprint, zero failures (`artifacts/soak-fingerprint-smoke.json`) |
| Current-tree short soak | `90.02s`, 1,563 iterations/projectile cycles, 157 boss restarts, 157 Dive transitions, 78 save writes, 676 offline events, peak 540 projectiles, identical start/end fingerprint, zero failures (`artifacts/soak-current-90s.json`) |
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
| ROOM-003 | Hazard contract catalog | All 42 hazard profiles produce deterministic, structurally bounded metadata across focused seeds | PASS (focused suite) |
| ROOM-004 | Runtime hazard playback | Every contract gives a full warning before activation, warning/projectiles share the safe gap, active waves clean up, caps hold, and hitch playback stays deterministic | PASS (focused suite); named movement/pattern visuals and human reachability are not proven |
| PROJ-001 | Fast projectile collision | Segment-circle collision catches a projectile that crosses a target between frames | PASS |
| PROJ-002 | Pool lifecycle | Player/enemy projectiles return to reusable pools after hit or clear | PASS |
| PROJ-003 | Pool cap | Exactly the configured player-projectile capacity is accepted and excess allocation is rejected | PASS |
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
| Web export artifact | HTML, JavaScript, WASM, PCK presence, excluded tooling/adaptive sources, and unresolved-shell token checks | PASS (current local static + older remote) | Current-working-tree static validation passes: HTML 2,618 / `190b5852ff3c94b4d2e6ce2849bdbc92cb64e77c6cb972d35165b9cf544713b5`; PCK 440,384 / `f9acf67d893ab6513f2b7fde450fcd2129331ba8252b3464132d94892b85b9d4`; WASM 39,514,754 / `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`. Actions run [33498494206](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33498494206) remains runtime evidence only for older commit `374bdb5cb8de7f4622917a343e379ff4cfd26232`. |
| Headless Chromium | Serve export over HTTP and wait for Godot `startGame()` completion | PASS (CI boot smoke) | HTTP 200; Godot 4.7.2; WebGL2; canvas 540×960; loading status hidden; no Playwright page errors. This is browser boot automation, not touch-gameplay, public-host, or physical-device evidence. |
| Chromium mobile viewport | Real canvas pointer drag, dash, core hook, and reload persistence | NOT RUN | Requires semantic QA probe or equivalent observable state |
| WebKit mobile viewport | Boot, canvas resize, safe-area layout, and basic pointer path | NOT RUN | Playwright WebKit is not physical Mobile Safari |
| Public GitHub Pages URL | Post-deploy HTTP and runtime smoke at `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` | BLOCKED / FAIL-CLOSED | Rerun job 99862926627 again failed because `Create Pages site` returned `Resource not accessible by integration`; direct game/support/privacy checks return HTTP 404 and no canvas. |
| Android debug APK | Manifest, permission, alignment, signature, then install/launch/lifecycle smoke | PARTIAL | Current local artifact is 28,878,673 bytes / SHA-256 `2d3d5fa6f283381fd31aa1702df2cc697c80f12d0d7a96e6c1e22b59c33cdcef` and passes arm64, identity/version, min 24/target 36, exact `android.permission.VIBRATE`, zip alignment, Debug v2/v3, and adaptive-icon validation. Export warned of installed build-tools 34.0.4 fallback while targeting 36. No emulator/device install occurred; it is not an AAB. |
| Android Gradle template path | Verified template install and Gradle project generation | PASS (structural) | Verified installer extracts `android_source.zip`; integrated debug export with `--install-android-build-template` creates `android/build`. This does not prove bundle compilation or signing. |
| Android release AAB | Release export and Play internal-test install | BLOCKED | Separate Gradle/AAB preset exists; artifact still needs resolvable Gradle dependencies, complete SDK/build-tools 36, private signing, and Play access |
| iOS Xcode project | Unsigned iPhone-targeted project structure and compile | PARTIAL | Full current-tree export failed because the Development Team is blank. `--export-pack iOS` refreshed only the retained 47-file scaffold's PCK to 440,480 bytes / `ac426ba74dd8993ea129448d2258d4f1b36ea3ee2fd48c28fd342bda53401db6`; unchanged pbxproj/plist hashes remain recorded. This is not a full current Xcode export, and no Xcode compile occurred. |
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
| Background/resume | No automated lifecycle harness | Not exercised | NOT RUN |
| Phone-call interruption | Not automatable in current Linux runner | Not exercised | NOT RUN |
| Low-power mode | Not automatable in current Linux runner | Not exercised | NOT RUN |
| Audio interruption | No audio-session interruption harness | Not exercised | NOT RUN |
| English/Hebrew switch | String parity, direction flag, and fallback verified | Visual layout/clipping not exercised | PARTIAL |
| Web IndexedDB reload | Native `user://` save verified only | Browser reload not exercised | NOT RUN |
| Restore Purchases | Billing is intentionally disabled | None | N/A |

## Performance and soak matrix

| Test | Acceptance target | Status |
|---|---|---|
| Projectile allocation stress | Pool cap respected; no uncontrolled allocation | PASS — 32,388 pressure cycles, 5,892,105 total spawns, peak 540 simultaneous |
| 30-minute headless structural soak | Complete at least 1,800 wall-clock seconds without crash, soft-lock, recorded failure, or sustained high memory growth | PASS (loaded snapshot) — 1,800.019 seconds, zero failures |
| Current-tree source-locked soak | Confirm no source drift and exercise repeated pressure/restart/Dive cycles | PASS — 90.02 seconds, 1,563 cycles, 157 restarts, 157 Dive transitions, 78 save writes, 676 offline events, peak 540 projectiles, unchanged fingerprint, zero failures |
| Repeated boss restart | At least 100 restarts without retained run nodes/projectiles | PASS — 3,239 restarts; baseline/final nodes 9/8, zero orphan nodes |
| Repeated dive transition | At least 100 transitions without duplicate triggers or retained internal state | PASS — 3,239 complete outside-inside-outside transitions |
| Save stress | Repeated atomic writes plus periodic reload/backup validation | PASS — 1,620 writes and 27 reload checks |
| Offline analytics queue | Persist, cap, reload, and continue while no backend is present | PASS — 3,759 events, 29 reloads, final queue capped at 500 |
| Static memory trend | Measure after a five-minute warm-up | PASS — peak 38.35 MB; +3.62 MB over stable window; regression slope +0.140 MB/min |
| Web cold start | Approximately four seconds on representative hardware | NOT RUN |
| Native frame rate | Stable 60 FPS where realistic, graceful 30 FPS fallback | NOT RUN |
| App size | Preferably below approximately 250 MB | NOT RUN |

The soak result is Linux Godot headless structural evidence only. It does not measure GPU rendering, frame pacing, thermals, battery, haptics, native audio, browser behavior, touch feel, Android performance, or iPhone performance.

Production files were edited by other active workstreams while the 30-minute process was already running. Godot had loaded its scripts and resources at process start, so that retained report validates only its loaded snapshot. The current working tree later passed the isolated fast headless suite (`2,538 passed, 0 failed`) and a separate 90.02-second soak with an unchanged source fingerprint and zero failures. Release Candidate evidence still requires repeating the full 30-minute soak after code freeze or against an exact recorded commit hash.

## Quality-gate status

| Gate | Status | Evidence still required |
|---|---|---|
| Gate 1 — Control feel | PARTIAL | Mathematical movement/dash behavior passes; real touch comprehension, accidental dash rate, readability, and attributable deaths require human device sessions |
| Gate 2 — Core hook | PASS (automated alpha) | Headless production systems complete the outside-inside-organ-outside sequence; all 12 losses have concrete data-driven mechanics and procedural exterior states, but human/device readability remains untested |
| Gate 3 — Complete run | PARTIAL | All boss/order victories pass, and the combined UI failure/bank/Forge/110-HP/second-failure/instant-retry/separate-process reload path passes; background/force-close, prior-build update, repeated Abyss, and human play remain |
| Gate 4 — Content complete | PARTIAL | Counts, effect contracts, tutorial/meta logic, and all boss/order state machines pass; room/boss fidelity, cosmetics, mode polish, and real-time balance remain incomplete |
| Gate 5 — Release candidate | BLOCKED | Native exports, browser runtime smoke, lifecycle tests, performance tests, and P0/P1 closure |
| Gate 6 — Launch ready | BLOCKED | Signed installs, store assets/listings, public policies, final device install, and store review |

## Open QA risks

| ID | Severity | Risk | Required resolution |
|---|---|---|---|
| QA-RISK-001 | P0 for release | No native build has been installed or exercised on a physical phone | Produce signed/internal builds and complete the physical-device matrix |
| QA-RISK-002 | P1 | Headless touch dispatch reaches the player and controller math passes, but exported browser/native touch delivery and feel are not proven | Add exported-canvas pointer tests and physical touch sessions |
| QA-RISK-003 | P1 | Complete-run simulations deliberately accelerate transitions and apply deterministic lethal damage; they do not prove that live boss patterns are survivable, fair, or balanced | Add bot/real-time runs, attack-pattern safety checks, and human sessions |
| QA-RISK-004 | P1 before online competition | Friend Rift checksum detects accidental/tampered payload changes but is not server authentication or score verification | Validate seeds, event summaries, rate limits, and idempotency server-side before enabling leaderboards |
| QA-RISK-005 | P1 | Browser `user://` persistence has not been verified through reload or storage failure | Add browser IndexedDB reload/corruption tests |
| QA-RISK-006 | P1 | RTL flag and copy are tested, but Hebrew layout, font glyphs, wrapping, and clipping are not | Run screenshot/manual review at small and large phone sizes |
| QA-RISK-007 | P1 for RC evidence | The 90-second current-tree soak is fingerprint-clean, but the only completed 30-minute soak loaded a snapshot while production files were being edited concurrently | Re-run the full 30-minute soak after code freeze and record the exact commit hash |
| QA-RISK-008 | P1 | Organ-loss contracts and procedural render states are automated, but no human/device session proves that each change is immediately readable or balanced | Capture and play all 12 outcomes on target aspect ratios; record attribution, safe-path, and organ-order results |

## Next executable QA work

1. Resolve GitHub Pages site-creation/Actions permissions, rerun deployment, and repeat the HTTP/runtime smoke against the public URL; current game/support/privacy checks are HTTP 404.
2. Add a QA-only observable snapshot and drive actual exported-canvas pointer input through the first core hook and all 12 organ-loss states.
3. Add a previously shipped save fixture, background/force-close reward interruption, and repeated Abyss-depth coverage; the combined UI progression/relaunch smoke now passes.
4. Add real-time attack-pattern safety and balance runs; the completed soak deliberately accelerates combat state transitions.
5. Re-run the 30-minute soak after code freeze against the exact release-candidate commit.
6. Export/install Android and current-tree iOS builds, then complete the named physical-device matrix without extrapolating from headless or browser evidence.
