# INFINIDIVE Known Issues

This list records observed gaps in version `0.1.0`. “Open” means the issue is not fixed or not proven fixed. Passing headless suites cover only their named automated assertions; they are not human, browser, simulator, or device evidence.

## Severity definitions

- **P0:** data loss, security failure, launch-blocking crash, or main-path soft lock.
- **P1:** release-blocking gameplay, truthfulness, accessibility, platform, or major content defect.
- **P2:** important polish, maintainability, fidelity, or secondary-flow defect.

No P0 is currently known from the automated suite; physical-device and human end-to-end playtesting have not occurred, so this is not a release-quality absence-of-defects claim.

## Resolved in the current working tree

- The prior public-smoke false-green gap is resolved: the QA bridge is exact-query gated and read-only and exposes only the bounded fields needed to prove the outside-inside-outside hook. Bright candidate `a550ca8` passed both CI-served and deployed-public paths in Actions run `33594396541`. Public artifact `9833689840` records HTTP 200, a live 540×960 canvas, the complete hook, same-context primary-save reload, and zero page, crash, or request failures. Mobile Safari/Chrome, native installation, physical-device behavior, and human control feel remain open.

- All 42 mutation effect keys now pass an explicit effect contract and have runtime consumers; representative contextual behaviors are covered headlessly. Human balance and feel remain unverified.
- Maximum-health and live dash mutation state is derived from an immutable run base, so later mutation selections no longer reapply structural hull effects.
- Arc Swarm now uses three bounded hops, Scatter Maw uses distance falloff, and Void/Hungry Orbitals absorb projectiles and grow as authored. Their balance still needs human playtesting.
- Mutation rerolls and live Bio-Matter magnet/pickup behavior are implemented.
- Victory results use localized victory-specific copy instead of the former failure sentence.
- All 18 permanent-upgrade effect keys have explicit validation, runtime consumers, prerequisite-aware Forge gates, and focused engine tests.
- Competitive runs now retain only Rift Dividend as a winning-run Bio-Matter modifier while normalizing combat-affecting permanent stats; losses are not multiplied. Warm Chamber's first window pauses through the intro.
- The ten-step tutorial observes real gameplay/Forge events; replay presentation now persists from `RunScene` to the Nest and completes on the Forge step.
- The AION story layer is integrated and public in `a550ca8`: the first eligible CRONUS Story launch presents the skippable English-first prologue, first movement awakens AION SPARK on the unarmed Keeper, fresh Story chapters present their intro, the first breach shows its nonmodal AION line, and an explicit first-Story-clear result gates shard restoration. Schema-7 exact-once receipts prevent repeats across retry/reload. Remote Story Service `164/0` and Story Presentation `280/0` pass; public/browser automation proves the gameplay path, while human pacing/comprehension and device presentation remain unverified.
- INF-P1-006 is resolved in code: all 42 room records compile through a fail-closed registry; source and compiled lanes are bounded by `lane_count`; digest-bound previews precede side effects; actual-homing suppression removes rather than straightens threats; player homing agrees at 30/60/120 Hz; collision sweeps before retirement in first-contact order; nonlinear paths retain subsegments; and first exit is terminal under exact extreme hitch cases. The final room-runtime result is 24,438/0: mechanics 3,541, compiler 15,515, pure/live effects 354/212, projectile travel 685, integration 4,131. Human readability, reachability, variety, and balance remain release-validation gaps.
- The former CI false-green gap is resolved: all 23 test scenes are inventoried. Candidate `a550ca8` passed remote `28,949/0`; hardening checkpoint `e7275f5` passed remote Validate plus its Web/Android/iOS-scaffold/30-minute-soak jobs. The current tree passes local `40,709/0` across 21 suites, editor/import, exact sentinels, and zero unexpected engine/script/parse errors; inventory is 23 scenes / 21 standalone suites / one nested / one soak. Its latest capture fixes still need committed remote evidence.
- Soak reports now stage and commit JSON/Markdown symmetrically under one transaction, cross-validate transaction/result parity, recover valid mixed primary/backup generations, and restore the previous complete pair byte-for-byte when JSON or Markdown open/write/verify/first-commit/second-commit failure injection fires. CI self-tests malformed pairs and requires 7/7 requested model counts to match executed counts.
- Current deployed-candidate run `33594396541` completed successfully, including source-bound long-soak job `100135598119`. Artifact `9833647628` (9,281-byte ZIP; `4607d9dfb3e5c0fdb53dd2666a10922fd6b90a7ace18ef6db0236a15ef8ac245`) records 1,800.026 seconds, unchanged production fingerprint `a0e456bc31c947cb1db2330e40b5069a323168b2b0ac1df553143bf9e9eb9a2c`, 25,109 cycles, 2,511 restarts/Dives, zero failures, and zero orphan nodes. This is Linux-headless structural evidence, not target-device performance or human-play evidence.
- Run `33559947112` completed successfully, including source-bound long-soak job `100030992601`. Its retained artifact `9822001845` (9,042-byte ZIP; `f93bd2c76a640c8cc2ccbc80593112752bf625298f00af86037091c667b7d29c`) records 1,800.043 seconds, seed 203541, unchanged start/end production fingerprint, 26,676 iterations/cycles, 2,668 restarts/Dives, 1,335 save writes / 22 save reloads, 3,188 queue events / 24 queue reloads / final 500, peak 540, stable delta 3,667,676 bytes, slope 84,517.9971965645 B/min, exact 7/7 model coverage, complete transaction `5c047f1a630e8e1de5c5ffff`, and zero failures. This is Linux headless structural evidence, not target-device performance or human-play evidence.
- Runtime-evidence commit `380b6d4b632e9d507ea42075714d0f18d6cdb74f` passed run `33565500042`: validation, Web export/CI Chrome, Android debug, deploy job `100049011404`, and public-smoke job `100049076641` all passed; long-soak skipped by design after Validate accepted the then-current `e942db6f` 30-minute report. Public artifact `9823113363` (90,667 bytes; `5038d055d8cf723b479424b4d099d0e3c036bb4e9eb325cb9c1ee6e00b750985`) records HTTP 200, a live 540×960 canvas, zero errors, 3/3/3 synthetic touch start/move/end events, and distinct before/after hashes `31212c7891fccbb64e3993062614178a854ac29b185878ee1a5db2963ccf2e23` / `94e6d2654a466e0ecb37670e6621d2b873eb5c9c56c39a5565ea2f38afa0b6d8`; the final screenshot visibly shows gameplay and Phase 89%. This closes only synthetic canvas-event delivery, continued live execution, and rendered-frame change—not semantic whole-path acceptance, mobile-browser/device behavior, or human feel.
- Four Titan tonal identities and nine three-layer music states are wired through `RunScene` using 123 deterministic pre-rendered original resources; device/browser listening QA remains open.
- Projectile speed, telegraph, dash-window, and aim-assist settings are exposed and consumed.
- `EVENT_TELEGRAPH_AVOIDED` is emitted from a real completed projectile volley only when the player took no hit and did not Dash after its telegraph began.
- Legacy `tutorial_complete=true` now migrates to `TutorialFlow.FULL_MASK`, with replay presentation kept separate.
- Reset Progress now replaces profile/backup defaults and idempotently clears the analytics queue plus leaderboard primary, backup, and temporary files.
- `armor_hit`, `organ_damage`, and `boss_phase` cues now have rate-limited live gameplay call sites.
- INF-P1-005 is resolved in code: all 12 organs declare validated post-loss contracts, seven intact attacks become safer authored replacements, five are fully disabled, all 12 publish unique procedural exterior states, and English/Hebrew result messages distinguish transformed from disabled systems. The 7,354-assertion organ suite verifies contracts, strict intact tuning, exact replacement patterns, readable ring telegraph alignment, live attack consumption, visual-token support, isolation, and idempotency; the 1,045-assertion attack-spec suite independently verifies Factory behavior. Human readability/balance still requires target-device play.
- Story and Abyss results no longer expose misleading Friend Rift codes. Story can use permanent upgrades and personal Assist settings that fixed competitive rules disable; Abyss additionally carries depth, cumulative score, mutations, restored health, and choice position. ID1 cannot reconstruct either ruleset, so only completed Daily/Friend results can be shared. Focused main/localized-layout assertions cover rejection, honest UI, source binding, and the valid live share path.
- INF-P1-014 is resolved: player-projectile segment intersections are gathered and sorted nearest-to-farthest, Rail Spine applies each hit until pierce is exhausted, duplicate target IDs remain excluded, and the main headless suite covers three collinear targets crossed in one physics step with per-hit damage falloff.
- The combined progression smoke now uses real result/Nest/Forge controls to fail, bank the 55 Bio-Matter floor, buy Reinforced Hull, verify a 110-HP new run, fail again, instant-retry, and reload the durable profile from a separate Godot process. Main-suite execution is isolated behind `INFINIDIVE_TEST_ISOLATED=1` plus a temporary `XDG_DATA_HOME` so it cannot target an ordinary player profile.
- The paused-breach soft-lock path is resolved: `_request_dive()` rejects input while `BREACH_OPEN` is paused, the pause overlay remains authoritative, and a manual resume restores the legal Dive action. This is headless regression evidence, not physical lifecycle QA.

## Open P1 issues

### INF-P1-006 — Authored room runtime lacks human/device validation

**Status:** Runtime implementation resolved; release validation open

The former count-versus-runtime defect is fixed in code: named structural, projectile, movement, defender, and kill-effect identities execute through validated plans rather than the former generic executor. Automated schedule, geometry, preview-integrity, curved-travel, actor-window, signed ownership, replay, cap, suppression, and cleanup checks cover the current headless paths. No person has yet played all categories/archetypes at target aspect ratios, and no browser or physical-device session establishes that the safe-rule copy, telegraphs, code-drawn motifs, defender priorities, and required movement are immediately understandable or comfortably reachable.

**Risk:** mathematically safe and mechanically differentiated plans can still be visually confusing, physically uncomfortable, or poorly paced on a phone.

**Required fix:** run player-driven sessions over all eight runtime categories, six movement models, ten defender archetypes, and the tightest 30/60 Hz travel cases on small and large phone layouts. Record path comprehension, missed telegraphs, damage causes, target priority, and completion before closing the release-validation portion of INF-P1-006.

### INF-P1-007 — Tutorial comprehension and gating are unvalidated

**Status:** Open

The event-driven tutorial tracks ten steps and sets `tutorial_complete` only after all ten are understood. Replay can be requested for the next run; its presentation state persists through the Run-to-Nest boundary and the Forge purchase completes the tenth replay step. The defense step now accepts either a live Dash or a real telegraphed volley that ends without a hit or Dash. The integrated AION prologue, unarmed first movement, Spark awakening, chapter intro, nonmodal first-breach line, and first-clear victory beat have automated presentation/decision coverage, but their pacing and comprehension have not been tested with people. The tutorial remains observational rather than gated.

**Required fix:** add targeted coachmarks/gates where observation alone is insufficient, then validate opening-story pacing, first-breach readability, Spark comprehension, control comprehension, and time-to-first-Dive with real testers.

### INF-P1-008 — Safe-area implementation is not device/browser validated

**Status:** Open

`SafeAreaHelper` is wired to the Nest and run HUD. It converts native `DisplayServer` safe rectangles on iOS/Android and Web CSS `env(safe-area-inset-*)` values into logical coordinates; deterministic math assertions pass. However, the UI still fits a largely fixed `540 x 960` design surface inside that safe rectangle. There is no mobile Safari/Chrome, simulator, notch/Dynamic Island, small-phone, large-phone, or physical-device layout evidence.

**Required fix:** validate real insets and viewport changes on supported browsers/devices, then replace fixed-coordinate sections that letterbox, clip, or produce poor touch ergonomics with adaptive containers.

### INF-P1-009 — Accessibility behavior is partial; localized layouts lack device validation

**Status:** Open

- English/Hebrew key parity, non-empty values, all launch-catalog translations, fallback Hebrew glyph coverage, and representative Nest/run RTL widgets pass headless tests. Text fit, clipping, visual order, and live language switching have not been validated in browsers, simulators, or devices.
- `damage_flash` now controls the player's damage-highlight blend from no color change through the full white highlight, with focused headless assertions. The fixed feedback duration and visual comfort still need human/device validation.
- Projectile-speed, telegraph, dash-window, and aim-assist controls are exposed and consumed, but have not been device/human validated.
- The analytics toggle now truthfully says it saves local diagnostics on this device in English and Hebrew. Turning it off persists opt-out before deleting the queue; cleanup is idempotent, reports failure, and retries at the next boot. No sharing transport exists.
- Reduced Motion now suppresses world shake and player motion trails, freezes decorative Nest/boss/background pulses and rotations, replaces the full-screen Dive sweep with a stable tunnel frame, and removes toast opacity sweeps. Telegraph progression, hazards, the player craft, and orbitals still move because their position communicates gameplay state. Behavioral assertions pass, but comfort/readability have not been device/human validated.

**Required fix:** run localized browser/simulator/device layout QA, verify the settings' visual effect and comfort with people who use motion/flash accommodations, and exercise forced-I/O cleanup failure presentation. Keep necessary gameplay motion attributable and readable rather than suppressing hazard or weapon position.

### INF-P1-010 — Touch/mobile-browser/native-install validation is incomplete

**Status:** Open

Candidate `a550ca8` retains deployed public evidence. The signed workflow's byte-identical default-branch registration is complete through PR #1 / merge `4bbdbb3`; branch/tag protection, the `app-store-production` environment, and Apple credentials remain unconfigured. Hardening run `33668271115` passed unsigned-scaffold validation and Xcode 26 compiled unsigned Release x86_64 Simulator and arm64 iPhoneOS builds, then failed during screenshot-loop transport timing. Debug run `33668271147` compiled/launched and captured the current-bright Nest, then failed at the Titan snapshot when a nullable value reached `String()`. Both capture defects are fixed locally with regression coverage and await rerun. The regenerated local scaffold declares exact `CFBundleLocalizations = [en, he]` and passes metadata/icons/launch/privacy validation. Automated upload remains hard-blocked pending protected Xcode 26 `altool` JSON-schema calibration. No release AAB, signed iOS archive, physical-device install, TestFlight upload, Mobile Safari/Chrome run, or store result exists.

Historical evidence remains separate: commits `380b6d4b`, `73a3f4a`, and `e9e7a50` retain earlier bounded evidence and are not substituted for current candidate `a550ca8`.

**Required fix:** commit and remotely validate the local capture fixes through a complete Xcode 26 Simulator install/launch/capture/terminate artifact, then repeat the complete flow in declared Mobile Safari/Chrome targets. Configure branch/tag protection and the protected release environment, supply the Apple Team/signing configuration securely, archive/upload to TestFlight, and run physical-device QA without claiming unperformed coverage.

### INF-P1-011 — Online systems are absent

**Status:** Open

Daily and Friend Rifts work locally through deterministic seeds/codes. Accepted Daily/Friend results are separated by canonical challenge IDs and queue validated, checksummed, unverified local summaries; Story/Abyss results do not consume the outbox. Friend target outcome is displayed locally. There is no player-facing ranking call site and still no anonymous authentication, backend transport, server-side score validation, rate limiting, moderation, fetched remote configuration, competitive online leaderboard UI, or cloud save.

**Required fix:** add an honest local/online UI only when its scope is clear, then add an optional authenticated backend adapter with RLS, rate limiting, moderation, and server validation without making core play depend on network availability. Treat every locally queued score as unverified.

### INF-P1-012 — Installed-update, background, and repeated-Abyss coverage is incomplete

**Status:** Open

The main headless suite completes all four bosses through all six organ orders, destroys each final core, verifies rewards, and prevents duplicate banking. A checked-in schema-1 fixture migrates to schema 7, including the versioned Story receipt ledger; valid pre-release receipts survive and malformed current ledgers recover safely. Simulated application pause and close persist a banked result synchronously, a fresh process rejects replay with exact totals, an injected save failure blocks navigation until exact-once reward banking succeeds, and five consecutive Abyss continuations preserve build/repair/depth/scaling without Story-shard leakage. Remaining gaps are an installed update from a prior TestFlight/App Store build and native interruption timing around combat/reward writes.

**Required fix:** run installed prior-build update, iOS background/resume/force-close/audio-interruption, and final exact-once reward tests on TestFlight. Keep destructive headless tests isolated.

### INF-P1-013 — Store and release deliverables are incomplete

**Status:** Open

Implementation-aligned privacy/store drafts and original brand sources exist. Existing real-runtime stills and trailers show the superseded dark identity and are historical provenance only and explicitly barred from submission. The bright game and legal-page set, including rebuilt Notices and Draft Terms, are deployed from `e7275f5`; the latest complete public gameplay proof remains `a550ca8` because the later public job failed during trailer input. The reproducible bright browser-trailer correction remains local. No release artifact is store-approved, and final legal/product review has not occurred. There is still no signed iOS archive, TestFlight/physical-device test, complete accepted-dimension native current-identity screenshot set, approved current App Preview, final-binary notice/privacy audit, submitted age/privacy forms, or completed store listing.

**Required fix:** export and deploy the current pivot, complete final-code and legal review of the privacy/support drafts, then publish and verify any required corrections; recapture every store screenshot/poster/trailer from verified bright Greek-mythic release-candidate gameplay; complete native signing, installed QA, store forms, listings, and submissions with truthful evidence.

## Open P2 issues

### INF-P2-002 — Difficulty tiers are primarily scalar

Diver, Deep, and Abyss alter HP, damage, projectile speed, and rewards. They do not yet introduce documented new patterns or organ behaviors as required for mature difficulty tiers.

### INF-P2-003 — Friend Rift checksum is integrity-only

The short checksum catches accidental/tampered text when the checksum is not recomputed, but it is not a signature. Anyone who knows the public encoding algorithm can generate a valid code. This is acceptable offline but cannot secure competitive score submission.

### INF-P2-004 — Result-card export and replay highlight remain incomplete

The runtime now renders a localized graphical post-run result card with boss, weapon, mutations, score/time/depth, destroyed organs, and privacy-safe Friend Rift code. Share still copies the challenge code; it does not export the card as an image/video or create a deterministic highlight replay.

### INF-P2-005 — Analytics never leaves the device

The abstraction and event allowlist exist, but default opt-in is false and no transport/query dashboard exists. Retention or balance metrics cannot be claimed.

### INF-P2-006 — `RunScene` is becoming monolithic

The script coordinates combat, boss patterns, rooms, rewards, modes, analytics, draw effects, and mutation consumption. Split boss-pattern execution, reward calculation, mode progression, tutorial flow, and effect consumers before expanding content.

### INF-P2-007 — Adaptive audio lacks mobile profiling and final mix validation

Four Titan profiles, nine three-layer music states, and rate-limited live `armor_hit`, `organ_damage`, and `boss_phase` cues are wired through 123 deterministic pre-rendered original resources. Runtime lazy-loading removes first-use PCM synthesis from combat transitions, and reproducibility/audio-contract tests pass. Transitions still restart/fade layers rather than true crossfading between two complete state sets. No browser/device loudness, interruption, mastering, or listening QA exists.

**Required fix:** profile lazy-load and concurrent playback on target phones, evaluate true state-to-state crossfades, then mix/listen-test every Titan/state across speaker, headphones, interruption, background/resume, and low-power conditions.

### INF-P2-008 — Bio-Matter pickups are not pooled

Runtime pickups are lightweight dictionaries in a dynamic array rather than a bounded reusable pool. Profile their allocation and collection behavior during long/high-kill runs; pool or cap them if they create frame-time or memory pressure.

### INF-P2-009 — Declared keyboard/controller actions are not consumed

`project.godot` defines Space/controller dash and Escape/controller pause InputMap actions, but gameplay scripts do not call `Input.is_action*` for them. Mouse-emulated touch and on-screen buttons work, but the declared keyboard/controller shortcuts currently do not.
