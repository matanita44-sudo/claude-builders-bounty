# INFINIDIVE Known Issues

This list records observed gaps in version `0.1.0`. “Open” means the issue is not fixed or not proven fixed. Passing headless suites cover only their named automated assertions; they are not human, browser, simulator, or device evidence.

## Severity definitions

- **P0:** data loss, security failure, launch-blocking crash, or main-path soft lock.
- **P1:** release-blocking gameplay, truthfulness, accessibility, platform, or major content defect.
- **P2:** important polish, maintainability, fidelity, or secondary-flow defect.

No P0 is currently known from the automated suite; physical-device and human end-to-end playtesting have not occurred, so this is not a release-quality absence-of-defects claim.

## Resolved in the current working tree

- All 42 mutation effect keys now pass an explicit effect contract and have runtime consumers; representative contextual behaviors are covered headlessly. Human balance and feel remain unverified.
- Maximum-health and live dash mutation state is derived from an immutable run base, so later mutation selections no longer reapply structural hull effects.
- Arc Swarm now uses three bounded hops, Scatter Maw uses distance falloff, and Void/Hungry Orbitals absorb projectiles and grow as authored. Their balance still needs human playtesting.
- Mutation rerolls and live Bio-Matter magnet/pickup behavior are implemented.
- Victory results use localized victory-specific copy instead of the former failure sentence.
- All 18 permanent-upgrade effect keys have explicit validation, runtime consumers, prerequisite-aware Forge gates, and focused engine tests.
- Competitive runs now retain only Rift Dividend as a winning-run Bio-Matter modifier while normalizing combat-affecting permanent stats; losses are not multiplied. Warm Chamber's first window pauses through the intro.
- The ten-step tutorial observes real gameplay/Forge events; replay presentation now persists from `RunScene` to the Nest and completes on the Forge step.
- INF-P1-006 is resolved in code: all 42 room records compile through a fail-closed registry; source and compiled lanes are bounded by `lane_count`; digest-bound previews precede side effects; actual-homing suppression removes rather than straightens threats; player homing agrees at 30/60/120 Hz; collision sweeps before retirement in first-contact order; nonlinear paths retain subsegments; and first exit is terminal under exact extreme hitch cases. The final room-runtime result is 24,438/0: mechanics 3,541, compiler 15,515, pure/live effects 354/212, projectile travel 685, integration 4,131. Human readability, reachability, variety, and balance remain release-validation gaps.
- The former CI false-green gap is resolved in the current workflow: all scenes are inventoried and isolated; process failure, engine/script/parse errors, sentinel/count drift, stale inventory, or invalid/missing soak pair fails closed. The final editor-plus-13-suite pass produced zero error lines and 28,410/0 assertions. Production/tracked-tests-CI fingerprints are `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382` / `e0af48b5b24e2333c928e685eccd12991c22f05d4cd8c37dc1c08f926bcb756b`. The soak validator recomputes current source and rejects stale, incomplete, or cleanup-pending `PASS` evidence; the production hash intentionally excludes local-only, non-exported capture provenance under `assets/store/gameplay/raw/`.
- Soak reports now stage and commit JSON/Markdown symmetrically under one transaction, cross-validate transaction/result parity, recover valid mixed primary/backup generations, and restore the previous complete pair byte-for-byte when JSON or Markdown open/write/verify/first-commit/second-commit failure injection fires. CI self-tests malformed pairs and requires 7/7 requested model counts to match executed counts.
- Run `33559947112` completed successfully, including source-bound long-soak job `100030992601`. Its retained artifact `9822001845` (9,042-byte ZIP; `f93bd2c76a640c8cc2ccbc80593112752bf625298f00af86037091c667b7d29c`) records 1,800.043 seconds, seed 203541, unchanged start/end production fingerprint, 26,676 iterations/cycles, 2,668 restarts/Dives, 1,335 save writes / 22 save reloads, 3,188 queue events / 24 queue reloads / final 500, peak 540, stable delta 3,667,676 bytes, slope 84,517.9971965645 B/min, exact 7/7 model coverage, complete transaction `5c047f1a630e8e1de5c5ffff`, and zero failures. This is Linux headless structural evidence, not target-device performance or human-play evidence.
- Runtime-evidence commit `380b6d4b632e9d507ea42075714d0f18d6cdb74f` passed run `33565500042`: validation, Web export/CI Chrome, Android debug, deploy job `100049011404`, and public-smoke job `100049076641` all passed; long-soak skipped by design after Validate accepted the retained current-source 30-minute report. Public artifact `9823113363` (90,667 bytes; `5038d055d8cf723b479424b4d099d0e3c036bb4e9eb325cb9c1ee6e00b750985`) records HTTP 200, a live 540×960 canvas, zero errors, 3/3/3 synthetic touch start/move/end events, and distinct before/after hashes `31212c7891fccbb64e3993062614178a854ac29b185878ee1a5db2963ccf2e23` / `94e6d2654a466e0ecb37670e6621d2b873eb5c9c56c39a5565ea2f38afa0b6d8`; the final screenshot visibly shows gameplay and Phase 89%. This closes only synthetic canvas-event delivery, continued live execution, and rendered-frame change—not semantic whole-path acceptance, mobile-browser/device behavior, or human feel.
- Four boss tonal identities and nine three-layer music states are wired through `RunScene`; device/browser listening QA remains open.
- Projectile speed, telegraph, dash-window, and aim-assist settings are exposed and consumed.
- `EVENT_TELEGRAPH_AVOIDED` is emitted from a real completed projectile volley only when the player took no hit and did not Dash after its telegraph began.
- Legacy `tutorial_complete=true` now migrates to `TutorialFlow.FULL_MASK`, with replay presentation kept separate.
- Reset Progress now replaces profile/backup defaults and idempotently clears the analytics queue plus leaderboard primary, backup, and temporary files.
- `armor_hit`, `organ_damage`, and `boss_phase` cues now have rate-limited live gameplay call sites.
- INF-P1-005 is resolved in code: all 12 organs declare validated post-loss contracts, seven intact attacks become safer authored replacements, five are fully disabled, all 12 publish unique procedural exterior states, and English/Hebrew result messages distinguish transformed from disabled systems. The 325-assertion focused suite verifies contracts, exact replacement patterns, readable ring telegraph alignment, live attack consumption, visual-token support, isolation, and idempotency. Human readability/balance still requires target-device play.
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

The event-driven tutorial tracks ten steps and sets `tutorial_complete` only after all ten are understood. Replay can be requested for the next run; its presentation state persists through the Run-to-Nest boundary and the Forge purchase completes the tenth replay step. The defense step now accepts either a live Dash or a real telegraphed volley that ends without a hit or Dash. The sequence remains observational rather than gated and has not been comprehension- or timing-tested with people.

**Required fix:** add targeted coachmarks/gates where observation alone is insufficient, then validate comprehension and time-to-first-Dive with real testers.

### INF-P1-008 — Safe-area implementation is not device/browser validated

**Status:** Open

`SafeAreaHelper` is wired to the Nest and run HUD. It converts native `DisplayServer` safe rectangles on iOS/Android and Web CSS `env(safe-area-inset-*)` values into logical coordinates; deterministic math assertions pass. However, the UI still fits a largely fixed `540 x 960` design surface inside that safe rectangle. There is no mobile Safari/Chrome, simulator, notch/Dynamic Island, small-phone, large-phone, or physical-device layout evidence.

**Required fix:** validate real insets and viewport changes on supported browsers/devices, then replace fixed-coordinate sections that letterbox, clip, or produce poor touch ergonomics with adaptive containers.

### INF-P1-009 — Accessibility behavior is partial; localized layouts lack device validation

**Status:** Open

- English/Hebrew key parity, non-empty values, all launch-catalog translations, fallback Hebrew glyph coverage, and representative Nest/run RTL widgets pass headless tests. Text fit, clipping, visual order, and live language switching have not been validated in browsers, simulators, or devices.
- `damage_flash` is stored but not applied to damage feedback intensity.
- Projectile-speed, telegraph, dash-window, and aim-assist controls are exposed and consumed, but have not been device/human validated.
- The analytics toggle says “Share anonymous gameplay analytics,” but the reviewed build only records a local queue and has no sharing transport. Turning the toggle off also leaves any existing local queue on device.
- Reduced Motion only affects world shake, not all transitions.

**Required fix:** run localized browser/simulator/device layout QA, apply damage-flash and broader reduced-motion behavior, make analytics wording/queue deletion match actual behavior, and add behavioral/UI tests for each accessibility effect.

### INF-P1-010 — Touch/mobile-browser/native-install validation is incomplete

**Status:** Open

Verified packages exist under `build/final-0.1.0-e942db6f`: 11,017,962-byte Web ZIP `8df771d4…`, debug APK `d089cebf…`, and unsigned iOS ZIP `5e3276c7…`; `BUILD_EVIDENCE.md` and `SHA256SUMS` pass. Packaged and live privacy hash to `81cf55f7f9e4c18a9c3a611593f358597020e93e61e594d89da482fd80bae17e`, and packaged/live support hash to `283e82c98eb26180c6426b2d9fcba919f0546eec8ea714f487b1eb5c50a802b2`. Runtime-evidence commit `380b6d4b632e9d507ea42075714d0f18d6cdb74f` passed run `33565500042`: the 28,410/0 matrix, Web export/CI Chrome, Android debug, deployment, and narrow synthetic public-host touch/frame smoke. Game/privacy/support/PCK/WASM return HTTP 200. No semantic whole control-path or reload result, mobile Safari/Chrome test, native install, production signing, physical-device test, or store result is claimed.

**Required fix:** extend the passing synthetic canvas event/frame smoke into semantic whole-control-path and reload-persistence checks, then repeat at `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` in declared mobile browsers. Install the debug APK on declared Android targets; use the separate AAB preset with complete SDK/build-tools 36 and secure signing; supply the Apple Team/signing configuration, re-export/compile/archive on macOS/Xcode, then run simulator/device QA without claiming unperformed coverage.

### INF-P1-011 — Online systems are absent

**Status:** Open

Daily and Friend Rifts work locally through deterministic seeds/codes. Accepted Daily/Friend results are separated by canonical challenge IDs and queue validated, checksummed, unverified local summaries; Story/Abyss results do not consume the outbox. Friend target outcome is displayed locally. There is no player-facing ranking call site and still no anonymous authentication, backend transport, server-side score validation, rate limiting, moderation, fetched remote configuration, competitive online leaderboard UI, or cloud save.

**Required fix:** add an honest local/online UI only when its scope is clear, then add an optional authenticated backend adapter with RLS, rate limiting, moderation, and server validation without making core play depend on network availability. Treat every locally queued score as unverified.

### INF-P1-012 — Installed-update, background, and repeated-Abyss coverage is incomplete

**Status:** Open

The main headless suite completes all four bosses through all six organ orders (24 deterministic victories), destroys each final core, verifies rewards, prevents duplicate completion banking, unlocks progression, and reaches the final stored Nest stage. It also exercises schema-1-to-6 migration. The combined player-facing smoke now fails, banks 55 Bio-Matter, returns to the Nest, purchases Reinforced Hull through the Forge UI, verifies the next run starts at 110 HP, fails again, presses instant retry, and verifies Bio-Matter, total runs, upgrade level, and run receipts after a separate Godot process loads `user://`. Remaining gaps are an update fixture captured from a previously shipped binary, force-close/background timing around damage/reward writes, and repeated Abyss-depth transitions with carried state.

**Required fix:** add a version-controlled prior-build update fixture, background/force-close interruption coverage around reward commits, and repeated Abyss-depth transitions. Keep every destructive main-suite run fail-closed behind `INFINIDIVE_TEST_ISOLATED=1` and a temporary `XDG_DATA_HOME`.

### INF-P1-013 — Store and release deliverables are incomplete

**Status:** Open

Implementation-aligned `PRIVACY_DATA_MAP.md`, bilingual `STORE_METADATA.md`, static bilingual privacy/support pages, bilingual Terms draft, Godot MIT notice, original brand sources, five real-runtime 1080×1920 stills, and two audio-complete 17.2-second development trailers now exist. The social file is 1080×1920 H.264/AAC; the Apple-format technical candidate is 886×1920 H.264/AAC with a matching poster. The 1024×1024 app icon and 1024×500 feature graphic are verified RGB/no-alpha rasters; the 512×512 Play icon is verified RGBA; and exact-size RGB/no-alpha iOS icon files are wired in the preset and were inspected in a prior Xcode asset catalog. The privacy and support drafts are publicly reachable through the pre-alpha Pages deployment, but none of the release artifacts is store-approved and final legal/product review has not occurred. The screenshots cover only five early-flow scenes and are not at Apple 6.9-inch submission sizes. The Apple candidate is Linux/Xvfb footage scaled and padded to the technical frame size, not a supported-iPhone capture, so it is not submission-ready. There is still no production-signed Android AAB, signed iOS archive, installed native test, complete eight-scene RC screenshot set, supported-iPhone App Preview, final-binary open-source notice audit, submitted age/privacy forms, or completed store listing.

**Required fix:** complete final-code and legal review of the published privacy/support drafts, then republish any required corrections; produce visual assets only from verified release-candidate gameplay; complete native signing, installed QA, store forms, listings, and submissions with truthful evidence.

## Open P2 issues

### INF-P2-002 — Difficulty tiers are primarily scalar

Diver, Deep, and Abyss alter HP, damage, projectile speed, and rewards. They do not yet introduce documented new patterns or organ behaviors as required for mature difficulty tiers.

### INF-P2-003 — Friend Rift checksum is integrity-only

The short checksum catches accidental/tampered text when the checksum is not recomputed, but it is not a signature. Anyone who knows the public encoding algorithm can generate a valid code. This is acceptable offline but cannot secure competitive score submission.

### INF-P2-004 — No graphical result card or replay highlight

Share currently copies an encoded challenge code and shows a toast. It does not create the requested result card, image, animated card, or deterministic highlight replay.

### INF-P2-005 — Analytics never leaves the device

The abstraction and event allowlist exist, but default opt-in is false and no transport/query dashboard exists. Retention or balance metrics cannot be claimed.

### INF-P2-006 — `RunScene` is becoming monolithic

The script coordinates combat, boss patterns, rooms, rewards, modes, analytics, draw effects, and mutation consumption. Split boss-pattern execution, reward calculation, mode progression, tutorial flow, and effect consumers before expanding content.

### INF-P2-007 — Adaptive audio lacks mobile profiling and final mix validation

Four boss profiles, nine three-layer music states, and rate-limited live `armor_hit`, `organ_damage`, and `boss_phase` cues are wired; focused/main suites inspect deterministic PCM/cache behavior and cue throttling. Boss-colored SFX still share pitch-shifted base recipes rather than bespoke motifs. First-time music-layer generation for a state/intensity bucket is synchronous and has not been profiled on mobile; transitions restart/fade layers rather than true crossfading between two complete state sets. No browser/device loudness, interruption, mastering, or listening QA exists.

**Required fix:** profile first-use synthesis, prewarm or move costly generation away from combat transitions as needed, evaluate true state-to-state crossfades, then mix/listen-test every boss/state on target browsers and devices.

### INF-P2-008 — Bio-Matter pickups are not pooled

Runtime pickups are lightweight dictionaries in a dynamic array rather than a bounded reusable pool. Profile their allocation and collection behavior during long/high-kill runs; pool or cap them if they create frame-time or memory pressure.

### INF-P2-009 — Declared keyboard/controller actions are not consumed

`project.godot` defines Space/controller dash and Escape/controller pause InputMap actions, but gameplay scripts do not call `Input.is_action*` for them. Mouse-emulated touch and on-screen buttons work, but the declared keyboard/controller shortcuts currently do not.
