# INFINIDIVE Known Issues

This list records observed gaps in version `0.1.0`. “Open” means the issue is not fixed or not proven fixed. A passing headless suite only covers the assertions defined in `tests/test_runner.gd`.

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
- All 42 room contracts now execute full warning windows, matching safe gaps, bounded active waves, and cleanup, including deterministic hitch playback. Visual variety and human reachability remain open below.
- Four boss tonal identities and nine three-layer music states are wired through `RunScene`; device/browser listening QA remains open.
- Projectile speed, telegraph, dash-window, and aim-assist settings are exposed and consumed.
- `EVENT_TELEGRAPH_AVOIDED` is emitted from a real completed projectile volley only when the player took no hit and did not Dash after its telegraph began.
- Legacy `tutorial_complete=true` now migrates to `TutorialFlow.FULL_MASK`, with replay presentation kept separate.
- Reset Progress now replaces profile/backup defaults and idempotently clears the analytics queue plus leaderboard primary, backup, and temporary files.
- `armor_hit`, `organ_damage`, and `boss_phase` cues now have rate-limited live gameplay call sites.

## Open P1 issues

### INF-P1-005 — Organ-loss descriptions are mostly binary disablement

**Status:** Open

`OrganAbilityMap` disables the linked attack completely. Several descriptions instead promise altered mechanics—straight rather than homing shots, wider gaps, longer telegraphs, one disabled wing, broken shield timing, or visible true weak points. Procedural visuals react to only a subset of specific organ IDs.

**Required fix:** add boss-specific post-organ variants and verify each organ changes both readable visuals and the exact external mechanic described.

### INF-P1-006 — Authored room count overstates runtime variety

**Status:** Open

The catalog truthfully contains 30 non-chamber definitions and 12 chambers. `RoomMechanics` supplies 42 deterministic contracts, and live gameplay now consumes schedules, warning windows, authored safe positions/gaps, active duration, projectile lifetime, spawn count, maximum-active bounds, and wave cleanup. Focused playback verifies those invariants under normal and hitch timing. The game still uses one generic defender and collapses the declared lane/ring/sweep/spawn families into three broad execution geometries. Named spawn/projectile-pattern and movement-model identities are not rendered as the cover, gates, nodes, eggs, echoes, marks, or currents described by many safe rules.

**Risk:** safe-rule text can mislead the player, and rooms with different IDs can play nearly identically.

**Required fix:** implement the named spatial/pattern identities and matching readable art, then run player-driven reachability at target aspect ratios. Automated playerless contract playback is not human playability evidence.

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

### INF-P1-010 — No public/mobile-browser/native-install validation

**Status:** Open

Fresh reconciled-tree Web, Android debug, and unsigned iPhone-targeted Xcode evidence outputs under `../../build/` now have recorded sizes/hashes and pass their available structural checks. Actions run 33498494206 passed validation, Web export, a CI-served Playwright/Chromium boot smoke, and Android debug export for commit `374bdb5cb8de7f4622917a343e379ff4cfd26232`. The browser smoke returned HTTP 200, started Godot 4.7.2 with WebGL2, created a 540×960 canvas, hid the loading status, and emitted no page errors. It did not drive touch gameplay, mobile Safari/Chrome, reload persistence, or the public URL. Pages deployment failed at Configure Pages because `Create Pages site` returned `Resource not accessible by integration`, so there is still no deployed/verified public URL. The remote debug APK uses the Android Debug signer, is 28,862,289 bytes with SHA-256 `45f1ebc82f1bae1d1cb767456c81fcf405d25b01d5e737c96b06f95084d0ef4c`, and has not been installed or built as an AAB. The Xcode export at `../../build/ios-iphone-current` verifies exact RGB icons and `TARGETED_DEVICE_FAMILY="1"`, with no Team/placeholder value, but has not been compiled, archived, signed, run in a simulator, or installed. The checked-in preset still needs the owner's Team/signing configuration for release export. Background/resume, interruption, and target-device performance profiles remain absent.

**Required fix:** enable Pages via **Settings → Pages → Build and deployment → Source: GitHub Actions**, rerun deployment, and verify `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/`; then drive touch gameplay and reload persistence in declared browsers. Install the debug APK on declared Android targets; use the separate AAB preset with complete SDK/build-tools 36 and secure signing; supply the Apple Team/signing configuration, compile and archive on macOS/Xcode, then run simulator/device QA without claiming unperformed coverage.

### INF-P1-011 — Online systems are absent

**Status:** Open

Daily and Friend Rifts work locally through deterministic seeds/codes. Accepted Daily/Friend results are separated by canonical challenge IDs and queue validated, checksummed, unverified local summaries; Story/Abyss results do not consume the outbox. Friend target outcome is displayed locally. There is no player-facing ranking call site and still no anonymous authentication, backend transport, server-side score validation, rate limiting, moderation, fetched remote configuration, competitive online leaderboard UI, or cloud save.

**Required fix:** add an honest local/online UI only when its scope is clear, then add an optional authenticated backend adapter with RLS, rate limiting, moderation, and server validation without making core play depend on network availability. Treat every locally queued score as unverified.

### INF-P1-012 — Complete-victory coverage exists; failure/retry coverage is incomplete

**Status:** Open

The main headless suite completes all four bosses through all six organ orders (24 deterministic victories), destroys each final core, verifies rewards, prevents duplicate completion banking, unlocks progression, and reaches the final stored Nest stage. It also exercises a schema-1-to-6 migration and save reload; a focused suite tests all permanent-effect aggregations and purchase gates. It does not yet cover one combined UI-driven death/instant-retry/Forge path, actual process relaunch, force-close/background timing, an update fixture from a previously shipped build, or repeated Abyss depth transitions.

**Required fix:** extend deterministic smoke tests through combined failure/retry/Forge UI behavior, process relaunch/update, background interruption, and repeated Abyss depths.

### INF-P1-013 — Store and release deliverables are incomplete

**Status:** Open

Implementation-aligned `PRIVACY_DATA_MAP.md`, bilingual `STORE_METADATA.md`, static bilingual privacy/support pages, bilingual Terms draft, Godot MIT notice, original brand sources, five real-runtime 1080×1920 stills, and two audio-complete 17.2-second development trailers now exist. The social file is 1080×1920 H.264/AAC; the Apple-format technical candidate is 886×1920 H.264/AAC with a matching poster. The 1024×1024 app icon and 1024×500 feature graphic are verified RGB/no-alpha rasters; the 512×512 Play icon is verified RGBA; and exact-size RGB/no-alpha iOS icon files are wired in the preset and were inspected in a prior Xcode asset catalog. These artifacts are not public or store-approved and have not received final legal/product review. The screenshots cover only five early-flow scenes and are not at Apple 6.9-inch submission sizes. The Apple candidate is Linux/Xvfb footage scaled and padded to the technical frame size, not a supported-iPhone capture, so it is not submission-ready. There is still no production-signed Android AAB, signed iOS archive, installed native test, complete eight-scene RC screenshot set, supported-iPhone App Preview, final-binary open-source notice audit, submitted age/privacy forms, or completed store listing.

**Required fix:** publish and verify the legal/support pages only after final-code review; produce visual assets only from verified release-candidate gameplay; complete native signing, installed QA, store forms, listings, and submissions with truthful evidence.

### INF-P1-014 — Piercing projectiles resolve at most one target per physics step

**Status:** Open\
**Evidence:** `ProjectilePool.step()` in `scripts/gameplay/projectile_pool.gd`

The collision loop stops after the first target intersection found for a player projectile during a physics step. A fast Rail Spine projectile with remaining pierce can therefore cross multiple collinear hurtboxes in one frame but damage only the first target returned by array order.

**Required fix:** gather and sort all segment intersections by travel distance, apply hits in order until pierce is exhausted, reject duplicate target hits for the same projectile as intended, and add a multi-target high-speed regression test.

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
