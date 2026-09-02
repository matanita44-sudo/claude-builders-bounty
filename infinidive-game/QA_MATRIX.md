# INFINIDIVE QA Matrix

Last verified: 2026-09-02\
Project version: `0.1.0`\
Engine: Godot `4.7.2.stable.official`\
Current quality level: production foundation / playable pre-alpha, not a release candidate

This document separates automated evidence, browser emulation, simulator testing, and physical-device testing. A row marked `PASS` only covers the environment and assertions named in that row. No physical-device testing has been performed yet.

> **Validated candidate:** source commit `73a3f4aad29a2d3900fe55e94ba4cfde6885d42a`, production fingerprint `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e`, tests/CI fingerprint `ff2530d3aad779a21a3b775e8d973ba1b3e3c37a86b5b97cea133801c954dc59`, editor plus 13 suites `28,410/0`, source-locked soaks at 8.049, 90.041, and 1,800.035 seconds, Web export, Android structural validation, CI-served semantic Chromium, deployment, and public-host semantic Chromium all pass in Actions run `33572931398`. This remains a playable pre-alpha: the browser semantic scope stops after movement/Dash, and no native install, physical-device, Mobile Safari/Chrome, or human control-feel result exists. Rows tied to `e942db6f`, run `33565500042`, or artifact `9822001845` remain explicitly historical prior-source evidence.

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
| Current candidate matrix total | `28,410 passed, 0 failed` across 13 invocations; editor import and all suites passed the strict wrapper with zero engine `ERROR`, script-error, or parse-error lines. Candidate production fingerprint `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e`; tracked tests/CI fingerprint `ff2530d3aad779a21a3b775e8d973ba1b3e3c37a86b5b97cea133801c954dc59`. The production calculation deliberately excludes `assets/store/gameplay/raw/`, whose continuous provenance capture is local-only, untracked, and absent from every export; all tracked production and exported game inputs remain covered. The JUnit file contains the `2,631/0` main suite. |
| Current candidate CI | PASS for the named automated workflow scope — source commit `73a3f4aad29a2d3900fe55e94ba4cfde6885d42a`; Actions run `33572931398`. Validate job `100070643207`, Web-export job `100071482044`, Android-debug job `100071482096`, long-soak job `100071482078`, deploy job `100078099551`, and public-smoke job `100078147875` all passed. This does not upgrade native/device/human rows. |
| Historical deployed CI baseline | Prior runtime commit `380b6d4b632e9d507ea42075714d0f18d6cdb74f` was deployed by Actions run `33565500042`, including deploy job `100049011404` and public-smoke job `100049076641`. Its optional long-soak job skipped after validation accepted the then-current `e942db6f` 30-minute pair; artifact `9822001845` remains historical prior-source endurance evidence only. |
| INF-P1-006 six-suite frozen result | Mechanics `3,541/0`; compiler `15,515/0`; pure defender effects `354/0`; live defender effects `212/0`; projectile travel `685/0`; live integration `4,131/0` — `24,438 passed, 0 failed` across six invocations |
| INF-P1-006 contract coverage | All seven travel IDs at 30/60 Hz; player homing at 30/60/120 Hz; lane topology; full digest-bound previews; actual-homing suppression without straightening; swept pre-retirement and first-contact collision; nonlinear/homing subsegments without safe metadata; exact `16/3s` first-exit handling; safe-radius hits; compiler-signed cleanup; pool reuse; bounded fallback; minimum-TTK audit `0` failures |
| Strict harness boundary | The inventory validator discovers 13 standalone suites, one nested relaunch probe, and one soak scene. Every runnable scene gets an isolated data root; process failure, any engine `ERROR`, script/parse error, exact-sentinel/count drift, stale inventory, or invalid/missing soak report pair fails closed. The validator recomputes current production source and requires complete two-phase result/transaction/completion/bound-hash and semantic exercise contracts; self-tests cover `PASS`, partial/source-change `FAIL`, fractional duration, cleanup-pending, stale evidence, and strict negatives. |
| Headless boot smoke | Main project booted with `--quit-after 30` under an isolated XDG data directory, exit 0, and no emitted errors; no renderer/browser/device claim |
| Execution mode | Main is headless, fixed 60 Hz, single-threaded scene tree; room-runtime coverage separately exercises 30/60 Hz and hitch-style deltas |
| Save isolation | Guard test without the flag exited 1 with `0 passed, 1 failed`; the current suite with `INFINIDIVE_TEST_ISOLATED=1` plus temporary `XDG_DATA_HOME` exited 0 with `2,631/0`; no production/player profile used |
| JUnit report | `artifacts/headless-tests.xml` |
| Current candidate 30-minute soak | Actions run `33572931398`, job `100071482078`, artifact `9826413723`: PASS at `1800.035s`, 27,043 cycles, 2,705 restarts / 2,705 Dives, 1,353 saves / 22 reloads, 3,224 queued events / 24 queue reloads / final queue 500, 1,659,358 player and 3,260,252 enemy projectile spawns, peak 540, peak objects/nodes/orphans 1,597/32/0, baseline/final nodes 11/10, 7/7 travel models, and zero failures. Fingerprint `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e`; transaction `9f396a0becf39225c7580401`; JSON `be3c3d795d31e9581e6fa108f462f58cd3264d9f24aff4d338a79123e485ed09`; Markdown/bound hash `d24fe59b37296f6006bb27dc18b61f3ff4996bbfdfc354d852af1377c3ab64b3`. Stable delta 3,296,336 bytes; slope 88,712.5106369138 B/min. The downloaded 9,008-byte evidence ZIP hashes to `1290cf7b8cf81b64dd6f0b43e55739f4f3bbaa24d4b40a083d6dbf1296b03a63`. |
| Prior-source 30-minute soak | Actions run `33559947112`, job `100030992601`, artifact `9822001845`: `PASS` at `1800.043s`, 26,676 cycles, 2,668 restarts / 2,668 Dives, 1,335 saves / 22 reloads, 3,188 queued events / 24 queue reloads / final 500, 1,636,943 player and 3,216,180 enemy projectile spawns, peak 540, baseline/final nodes 11/10, orphan peak 0, 7/7 travel models, and zero failures. Fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`; transaction `5c047f1a630e8e1de5c5ffff`; JSON `2f8171e8317572f31fd479884edcaa441452082640a9be4f3fe9339da02710b4`; Markdown/bound hash `a508864e78c75981e8221df2c53f0ed97c82501295e999328fa86b78970f1856`. Stable delta 3,667,676 bytes; slope 84,517.9971965645 B/min. This is not evidence for candidate `1db2d97a`. |
| Soak reports | `artifacts/soak-30m.json` and `artifacts/soak-30m.md` |
| Soak source-lock smoke | `5.010s`, identical start/end source fingerprint, zero failures (`artifacts/soak-fingerprint-smoke.json`) |
| Current bounded soak | `8.049s`, 88 cycles, 9 boss restarts / 9 Dives, 6 saves, 529 queued offline events / 2 queue reloads / final queue 500, peak 540, 7/7, unchanged fingerprint `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e`, complete transaction `994142d36b9310b4523a7b2f`, zero failures. JSON `4ed5331ef40095b482a3c15804a34f42e0c7be9fdd615ed125c4a020d652242c`; Markdown/bound hash `3ac976b10c77799e9c7ec8930e62d0f329cc36910cc18f6d3bc933f72cca7b85`. |
| Paused breach-entry regression | PASS in the `2,631/0` main suite — while `BREACH_OPEN` is paused, `_request_dive()` is rejected and the pause overlay remains authoritative; manual resume restores the legal Dive path. |
| Current 90-second soak | PASS — same transactional/source-lock acceptance as the bounded smoke; `90.041s`, 1,166 cycles, 117 restarts / 117 Dives, 60 saves / 1 reload, 637 queued offline events / 3 queue reloads / final queue 500, peak 540, 7/7, stable delta 90,604 bytes, slope 218,771.80935953 B/min, complete transaction `98e69a9b42dd1314f6a16cb9`, zero failures. Fingerprint `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e`; JSON `0033e18b7730513b977dadb9f275ad919ed24dc6c4e6545d31b1199c3d48e65b`; Markdown/bound hash `c6a109f86f8ba63474b4456c3d265111f85759c82e5c6ad86f85efd8833d571c`. |
| Transactional report recovery | PASS — full-schema JSON/Markdown stage and commit as a two-phase pair with JSON-bound Markdown hash; completion is set only after cleanup; stale source/recovery reports are rejected; partial/early and source-change diagnostics persist as `FAIL`. Writer transaction tests plus CI `PASS`/diagnostic/negative fixtures passed; transaction-subsystem red-team found 0 P0/P1/P2. |
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
| SAVE-003 | Migration | The checked-in `save_schema_1_prealpha.json` fixture and inline malformed/legacy cases migrate bank, settings, contracts, Abyss unlock, transaction, tutorial, and meta fields into schema 6 defaults; legacy `tutorial_complete=true` maps to `TutorialFlow.FULL_MASK` | PASS for source-level fixture migration; installed-app update remains untested |
| SAVE-004 | Reward banking | A valid run banks once; immediate/old run IDs remain non-bankable after more than 30 later transactions, and a fresh process rejects a completed result replay after synchronous suspend/close notification saves | PASS (headless/separate-process); native kill timing remains untested |
| SAVE-005 | Persistence | Banked currency, unlocks, and processed run ID survive teardown/reload | PASS |
| SAVE-006 | Intentional local reset | Confirmed reset replaces profile/backup with defaults and idempotently removes analytics plus leaderboard primary/backup/temporary files | PASS for service/UI contract; human interaction and forced I/O failure presentation remain untested |
| LOC-001 | Localization completeness | English and Hebrew tables contain identical non-empty keys | PASS |
| LOC-002 | Direction/fallback | English is LTR, Hebrew is RTL, language switch changes copy, and a missing key remains visible | PASS |
| SETTINGS-001 | Required settings | Default save includes the required audio, accessibility, control, language, and privacy settings | PASS |
| SETTINGS-002 | Accessibility effects | Reduced Motion freezes decorative boss motion, uses a stable Dive frame, and removes toast fading while retaining hit timing; damage-flash intensity spans no highlight to full highlight | PASS (headless behavior); browser/device/human comfort not run |
| ANALYTICS-001 | Event contract | Every required product event exists in the analytics abstraction | PASS |
| ANALYTICS-002 | Privacy opt-out | Opted-out diagnostics do not enqueue; disabling in Settings persists opt-out and deletes queued data; disabled boot retries legacy queue deletion; nested/unsupported properties are discarded | PASS; forced filesystem-failure presentation not run |
| BACKEND-001 | Offline result staging | Canonical Daily/Friend summaries remain challenge-separated, duplicates reject, Story/Abyss stay out of the outbox, checksummed backup recovers, and transport fails closed | PASS (focused suite) |
| META-001 | Local goals | Fourteen achievements and nineteen contracts validate; UTC rotation, migration, bounded SHA receipts, fail-closed saturation, idempotent progress, and rewards behave deterministically | PASS (focused suite) |
| AUDIO-001 | Adaptive audio contract | Four boss profiles, nine three-layer states, SFX coloring, cache bounds, invalid-input fallback, headless safety, and rate-limited live `armor_hit`/`organ_damage`/`boss_phase` emission behave deterministically | PASS (focused/main suites); listening and mobile profiling not performed |
| HOOK-001 | Outside-inside-outside | Armor breaks, breach opens, organ is selected, internal route reaches chamber, organ dies, mutation is chosen, and play returns outside | PASS |
| HOOK-002 | Visible mechanical consequence | The destroyed organ remains destroyed; its intact ability is removed and its authored degraded-or-disabled loss contract plus unique exterior state persists after returning outside | PASS |
| HOOK-003 | Transition guards | Duplicate breach/dive requests, invalid organ IDs, and invalid mutation IDs cannot skip or duplicate the state transition | PASS |
| RUN-001 | Full three-organ boss victory | All 24 combinations of four bosses and six organ orders complete three dives, disable the selected abilities, expose the core, win, bank configured rewards once, and retain deterministic identity | PASS |
| RUN-002 | Failure, reward, Forge purchase, retry | Real result/Nest/Forge controls bank a 55-Bio failure, buy Reinforced Hull, start a 110-HP run, bank a second failure, and press instant retry | PASS (main suite) |
| SAVE-007 | Separate-process relaunch | A new Godot process loads the primary profile and verifies Bio-Matter, two total runs, Reinforced Hull level, and both processed run IDs | PASS (main suite) |
| ABYSS-001 | Endless progression | Five consecutive Abyss victory/continue cycles retain the mutation build and choice count, apply bounded repair, rotate bosses, derive deterministic seeds, preserve every reward receipt, and strictly increase health/damage/projectile-speed scaling | PASS (headless continuation contract); real-time and device play remain untested |

## Browser and export matrix

| Target | Scope | Status | Notes |
|---|---|---|---|
| Web export artifact | HTML, JavaScript, WASM, PCK presence, excluded tooling/adaptive sources, unresolved-shell token checks, and local HTTP paths | PASS (candidate static/local HTTP and CI export) | Candidate package `INFINIDIVE-0.1.0-prealpha-web-1db2d97a.zip` is 11,022,194 bytes / `a8504d0c0630dced1c3892c971a0d3f9be67844250927b8bf9a80340ebc98e4f` and passes archive integrity, static validation, and local HTTP 200 for root, privacy, support, PCK, and WASM. Export members: HTML 2,618 / `752664b9f32004bb50b2b8d629481128d2e26fabb771644da679509a2849f05d`; JS 279,815 / `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba`; PCK 629,236 / `b573dee37ef910fdbf59110e1dd6667fd70f265b183d57a70eb8ecd487544116`; WASM 39,514,754 / `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`. Actions run `33572931398` Web-export job `100071482044` passed for source commit `73a3f4a`. |
| Headless Chromium | Serve the candidate export over HTTP and wait for Godot boot/start completion | PASS (candidate CI-served browser) | Actions run `33572931398` served the exported candidate and completed its browser smoke at HTTP 200 with a live 540×960 canvas, zero page errors, crashes, failed requests, or critical failures. Artifact `9825704303` retains the trace and stage screenshots; semantic assertions are itemized below. This is headless Chromium evidence, not Mobile Safari/Chrome or physical-device evidence. |
| Chromium mobile viewport — historical synthetic delivery | Boot, start tap, drag, Dash-coordinate tap, canvas touch-event delivery, and post-input render change | PASS (historical prior source) | Prior runtime commit `380b6d4b632e9d507ea42075714d0f18d6cdb74f`, Actions run `33565500042`, public-smoke job `100049076641`: HTTP 200, 540×960 canvas, zero page errors, and canvas `touchstart` / `touchmove` / `touchend` counts `3/3/3`. Before SHA-256 `31212c7891fccbb64e3993062614178a854ac29b185878ee1a5db2963ccf2e23` differs from after SHA-256 `94e6d2654a466e0ecb37670e6621d2b873eb5c9c56c39a5565ea2f38afa0b6d8`. This is historical synthetic delivery/render evidence for prior source, not semantic candidate, mobile Safari/Chrome, or physical touch evidence. |
| Chromium semantic gameplay | Assert exact run start, movement, and Dash from query-gated observable game state | PASS (candidate CI-served and public-host; partial gameplay scope) | CI-served artifact `9825704303` passed at HTTP 200 on a live 540×960 canvas with zero page errors/crashes/network/critical failures: exact Nest `0` → run `1`, `EXTERIOR`, controls active, valid numerics, movement `false` → `true` over `267.402052688428` px, Dash count `0` → `1`, charge `1` → `0`, durable acceptance, monotonic revision/elapsed trace, and canvas touch events `3/3/3`. Public-host artifact `9826433759` independently passed the same contract at the deployed URL with `269.18024587052236` px movement, Dash `0` → `1`, charge `1` → `0`, touch events `3/3/3`, and zero page/crash/network/critical errors. Public report is 36,966 bytes / `6903baca4574a695eb87681268c0c20f2055dc2dba24099e31188fbbe5753039`; before/final frame hashes are `0da738405c7983f4d795655ada7d31acbbc4d973724b404b5651034300ba3eb9` and `7ca6ba2e9fc87aa5ac7ea3629138d23d3cd9a7bb24b3abf39c7c839971a09633`. Breach/Dive/organ return and browser-save reload remain untested. |
| WebKit mobile viewport | Boot, canvas resize, safe-area layout, and basic pointer path | NOT RUN | Playwright WebKit is not physical Mobile Safari |
| Public GitHub Pages URL | Post-deploy HTTP, runtime, and semantic canvas-input smoke at `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` | PASS (current candidate, headless Chromium) | Actions run `33572931398` deployed source commit `73a3f4aad29a2d3900fe55e94ba4cfde6885d42a` in job `100078099551`; public-smoke job `100078147875` passed at HTTP 200 with a live 540×960 canvas, zero page/crash/network/critical errors, exact run generation, `269.18024587052236` px movement, Dash `0` → `1`, charge `1` → `0`, and canvas touch events `3/3/3`. Artifact `9826433759` is 92,257 bytes with downloaded ZIP SHA-256 `014fe807c93ed3d03d7c6cfebac201faec2986324f8a576be2fbb6967ae9c020`. This is synthetic headless Chromium evidence for movement/Dash only, not Mobile Safari/Chrome, physical touch, the full core hook, or persistence. Historical prior-source public evidence remains retained in the dedicated row above. |
| Android debug APK | Manifest, permission, architecture, alignment, signature, then install/launch/lifecycle smoke | PARTIAL | Candidate APK `INFINIDIVE-0.1.0-prealpha-debug-1db2d97a.apk` is 29,063,530 bytes / `e3418d97a535cf4e36bb7c1cf05e4f7db4e722a774409e29df6f80b33786cf03`; its `.idsig` is 234,930 bytes / `d4a223d9647ea9321ea5ddc609eb073f5fd02ed08cd406d22b2e6872518b8381`. Local validation passed arm64, package/version/SDK, ZIP alignment, adaptive icon, exact `VIBRATE` permission, and debug v2/v3 signature; Actions run `33572931398` Android-debug job `100071482096` passed. No AAB, emulator/device install, launch, or lifecycle result. |
| Android Gradle template path | Verified template install and Gradle project generation | PASS (structural) | Verified installer extracts `android_source.zip`; integrated debug export with `--install-android-build-template` creates `android/build`. This does not prove bundle compilation or signing. |
| Android release AAB | Release export and Play internal-test install | BLOCKED | Separate Gradle/AAB preset exists; artifact still needs resolvable Gradle dependencies, complete SDK/build-tools 36, private signing, and Play access |
| iOS Xcode project | Unsigned iPhone-targeted scaffold and current candidate PCK | PARTIAL / BLOCKED | Candidate unsigned scaffold `INFINIDIVE-0.1.0-prealpha-ios-unsigned-1db2d97a.zip` is 98,500,694 bytes / `54bb7d9f866608773470c90f8b8d953b4668f2bc3914086e2e96e131b0f85b9d`. Its current candidate PCK is 629,332 bytes / `8133fcd7ebbb071b20f30ca65a43cb35488b6fff2335915ef47d710693c33a88`; archive integrity, embedded-PCK parity, and Linux headless `--main-pack` boot passed with no errors. The scaffold was retained and only the candidate PCK refreshed; no Xcode compile/archive, signature, simulator run, install, or TestFlight result. |
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
| Upgrade from schema 1 save | Checked-in schema-1 pre-alpha fixture migration and nested defaults verified | No installed-app upgrade | PARTIAL |
| Corrupt primary save | Backup recovery verified | No forced-close device exercise | PARTIAL |
| Duplicate reward submission | Immediate/old IDs reject, and a fresh process rejects the same completed result after headless suspend/close notification saves without mutating reward totals | No native background/kill interruption | PARTIAL |
| Airplane mode | Core systems have no required network calls | Not exercised in an installed build | NOT RUN |
| Unstable connection | No online backend connected | Not exercised | NOT RUN |
| Background/resume | Headless application notifications verify pause/save locking; a banked result remains frozen, persists its reward/receipt, and rejects replay after process relaunch | No installed-app/native lifecycle exercise | PARTIAL |
| Phone-call interruption | Not automatable in current Linux runner | Not exercised | NOT RUN |
| Low-power mode | Not automatable in current Linux runner | Not exercised | NOT RUN |
| Audio interruption | No audio-session interruption harness | Not exercised | NOT RUN |
| English/Hebrew switch | String parity, direction flag, and fallback verified | Visual layout/clipping not exercised | PARTIAL |
| Web IndexedDB reload | Native `user://` save verified only | Browser reload not exercised | NOT RUN |
| Restore Purchases | Billing is intentionally disabled | None | N/A |

## Performance and soak matrix

| Test | Acceptance target | Status |
|---|---|---|
| Projectile allocation stress | Pool cap respected; no uncontrolled allocation | PASS (current candidate structural) — the 30-minute run completed 27,043 pressure cycles with 1,659,358 player plus 3,260,252 enemy spawns; peak simultaneous count stayed at 540 and zero failures were recorded. |
| Candidate 30-minute headless structural soak | Complete at least 1,800 wall-clock seconds without crash, soft-lock, recorded failure, source drift, or sustained high memory growth | PASS — Actions run `33572931398`, job `100071482078`, artifact `9826413723` completed `1800.035s` at fingerprint `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e` with zero failure/source drift, complete report transaction `9f396a0becf39225c7580401`, stable delta 3,296,336 bytes, and slope 88,712.5106369138 B/min. This is Linux headless structural evidence only. |
| Source-locked transactional soaks | Confirm no source drift, semantic exercise, 7/7 models, complete two-phase pair, and current-source fingerprint | PASS (current candidate structural scope) — the 8.049-second, 90.041-second, and 1,800.035-second pairs share unchanged fingerprint `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e`, complete distinct transactions and bound hashes, exercise 7/7 models, and record zero failures. Prior `1800.043s` evidence at fingerprint `e942db6f` remains historical only. |
| Repeated boss restart | At least 100 restarts without retained run nodes/projectiles | PASS (current candidate structural) — 2,705 restarts; baseline/final nodes 11/10, peak nodes 32, peak orphan nodes 0 |
| Repeated dive transition | At least 100 transitions without duplicate triggers or retained internal state | PASS (current candidate structural) — 2,705 complete outside-inside-outside transitions |
| Save stress | Repeated atomic writes plus periodic reload/backup validation | PASS (current candidate structural) — 1,353 writes and 22 reload checks |
| Offline analytics queue | Persist, cap, reload, and continue while no backend is present | PASS (current candidate structural) — 3,224 events, 24 reloads, final queue capped at 500 |
| Static memory trend | Measure after a five-minute warm-up | PASS (current candidate Linux headless structural) — peak 44,868,251 bytes; +3,296,336 bytes over the stable window; regression slope +88,712.5106369138 B/min |
| Web cold start | Approximately four seconds on representative hardware | NOT RUN |
| Native frame rate | Stable 60 FPS where realistic, graceful 30 FPS fallback | NOT RUN |
| App size | Preferably below approximately 250 MB | NOT RUN |

The soak result is Linux Godot headless structural evidence only. It does not measure GPU rendering, frame pacing, thermals, battery, haptics, native audio, browser behavior, touch feel, Android performance, or iPhone performance.

The current tree passed the complete 13-suite matrix (`28,410/0`) plus source-locked transactional soaks at `8.049s`, `90.041s`, and `1800.035s`, all at fingerprint `1db2d97a` with zero failures. The current full-duration pair came from Actions run `33572931398`, long-soak job `100071482078`, and artifact `9826413723`. The retained `1800.043s` pair from prior-source run `33559947112`, job `100030992601`, and artifact `9822001845` remains historical. The canonical production inventory intentionally omits only the local-only, untracked, non-exported continuous capture under `assets/store/gameplay/raw/`; that provenance file is not game input and cannot affect a shipped build.

## Quality-gate status

| Gate | Status | Evidence still required |
|---|---|---|
| Gate 1 — Control feel | PARTIAL | Mathematical movement/dash behavior passes; real touch comprehension, accidental dash rate, readability, and attributable deaths require human device sessions |
| Gate 2 — Core hook | PASS (automated alpha) | Headless production systems complete the outside-inside-organ-outside sequence; all 12 losses have concrete data-driven mechanics and procedural exterior states, but human/device readability remains untested |
| Gate 3 — Complete run | PARTIAL | All boss/order victories, combined UI progression/relaunch, source-fixture migration, headless suspend-adjacent reward replay defense, and five repeated Abyss continuations pass; native background/force-close timing, installed prior-build update, and human play remain |
| Gate 4 — Content complete | PARTIAL | Counts, effect contracts, tutorial/meta logic, all boss/order state machines, and authored room-runtime identities exist; human room/boss readability, cosmetics, mode polish, and real-time balance remain incomplete |
| Gate 5 — Release candidate | BLOCKED | Production-signed native exports/installs, Mobile Safari/Chrome and physical-touch runtime tests, lifecycle tests, target-device performance tests, and P0/P1 closure |
| Gate 6 — Launch ready | BLOCKED | Signed installs, final store assets/listings, legally reviewed public policies/notices, final device install, and store review |

## Open QA risks

| ID | Severity | Risk | Required resolution |
|---|---|---|---|
| QA-RISK-001 | P0 for release | No native build has been installed or exercised on a physical phone | Produce signed/internal builds and complete the physical-device matrix |
| QA-RISK-002 | P1 | The corrected query-gated movement/Dash probe passes against both CI-served and deployed public-host Chromium with exact run-generation, movement, Dash, validity, and monotonic-trace assertions. Native delivery, Mobile Safari/Chrome, accidental activation, and physical touch feel remain unproven. | Run the same contract in mobile browsers where automation is reliable, then complete physical touch sessions. |
| QA-RISK-003 | P1 | Room compiler/integration checks now exercise safe and unsafe probes, 30/60 Hz travel, hitch-swept geometry, actor windows, and cleanup, while complete-run simulations still accelerate broader combat and neither path proves human survivability, readability, fairness, or balance | Add real-time bot runs plus human sessions on target aspect ratios |
| QA-RISK-004 | P1 before online competition | Friend Rift checksum detects accidental/tampered payload changes but is not server authentication or score verification | Validate seeds, event summaries, rate limits, and idempotency server-side before enabling leaderboards |
| QA-RISK-005 | P1 | Browser `user://` persistence has not been verified through reload or storage failure | Add browser IndexedDB reload/corruption tests |
| QA-RISK-006 | P1 | RTL flag and copy are tested, but Hebrew layout, font glyphs, wrapping, and clipping are not | Run screenshot/manual review at small and large phone sizes |
| QA-RISK-007 | P1 for native performance | The current candidate passes a source-locked 30-minute Linux headless soak, but that run does not measure rendering, frame pacing, thermals, battery, haptics, or native lifecycle behavior | Run installed-build endurance passes on representative Android and iPhone hardware with profiler/device evidence |
| QA-RISK-008 | P1 | Organ-loss contracts and procedural render states are automated, but no human/device session proves that each change is immediately readable or balanced | Capture and play all 12 outcomes on target aspect ratios; record attribution, safe-path, and organ-order results |
| QA-RISK-009 | P1 | The 42 rooms now execute authored structural/projectile/movement/defender identities, but code-drawn category/token variation has not been visually reviewed on browsers or phones and automated corridors do not measure player comprehension | Run every category, defender archetype, and tightest travel case at small/large phone sizes; record deaths, missed telegraphs, and path comprehension |

## Next executable QA work

1. Extend the current CI/public semantic probe through breach, Dive, organ destruction, return, saved reload, all 12 organ-loss states, and representative room cases across all eight categories and ten defender archetypes.
2. Install a prior TestFlight build and current update on-device, then exercise real background/force-close reward timing; source-fixture migration, fresh-process replay defense, and repeated Abyss continuation now pass headlessly.
3. Add real-time attack-pattern safety and balance runs; the completed soak deliberately accelerates combat state transitions.
4. Install the canonical Android debug build, produce a full current-source iOS export/compile/archive, then complete the named physical-device matrix without extrapolating from headless or browser evidence.
