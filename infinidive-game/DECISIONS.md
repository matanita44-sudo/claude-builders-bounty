# INFINIDIVE — Implementation Decisions

> This file records decisions visible in the current 0.1.0 source as of 2026-09-02. It does not retroactively claim stakeholder approval or production validation.

## D-001 — Godot 4.7.2 and GDScript

**Status:** Implemented

The production project uses Godot 4.7.2, GDScript and the GL Compatibility renderer.

**Why this implementation fits the project**

- One source project can target Web, Android and iOS.
- GDScript keeps gameplay iteration local to the engine.
- GL Compatibility supports the current code-drawn 2D presentation and web export.

**Consequences**

- The repository pins 4.7.2 in .godot-version and CI.
- Export presets exist for Web, Android and iOS.
- Android presets request only normal `android.permission.VIBRATE`; CI installs the verified `android_source.zip` template before debug Gradle export. This proves project generation, not AAB compilation or signing.
- A configured preset is not evidence of a signed native build.

## D-002 — Portrait-first fixed logical canvas

**Status:** Implemented

The logical viewport is 540 × 960 with canvas-item stretching and portrait handheld orientation.

**Consequences**

- Gameplay coordinates and balance distances are authored against this space.
- Touch bounds reserve upper space for the boss and lower space for the player.
- Canvas scaling uses expand and fractional scale modes.
- SafeAreaHelper converts native display safe areas or Web CSS insets and fits the 540 × 960 Nest/HUD surface inside them.
- Safe-area conversion has headless coverage, but device-specific safe-area QA is still required.

## D-003 — Explicit run state machine

**Status:** Implemented

RunScene owns a finite sequence from Intro through exterior phases, breach, organ selection, internal route, mutation selection, core, death and victory.

**Why**

- The core hook depends on a reliable outside–inside–outside order.
- State guards prevent duplicate breach, dive, organ-destruction and completion calls.

**Consequences**

- UI and input are disabled in selection/result states.
- Phase and organ transitions are testable without embedding progression logic in UI scripts.

## D-004 — Organ abilities are authoritative runtime links

**Status:** Implemented

Every boss organ maps to one exterior ability through OrganAbilityMap. Destroying the organ is idempotent and disables that ability.

**Consequences**

- Organ order changes the remaining attack pool.
- The current runtime performs a complete disable even when catalog prose describes a weaker transformation.
- Future partial transformations require an explicit ability-state model, not only copy changes.

## D-005 — JSON catalogs for content

**Status:** Implemented

Bosses, weapons, mutations, permanent upgrades and internal rooms live in separate JSON arrays loaded by GameData.

**Why**

- Counts, IDs and tuning can change without editing the main run controller.
- Headless validation can reject missing IDs, invalid organ maps and unsafe room records.

**Consequences**

- The service loader validates inventory/references; dedicated mutation and permanent-upgrade engines separately enforce complete effect-key contracts.
- Room profiles retain their JSON/mechanics metadata boundary, while a pure runtime compiler maps every declared spawn, projectile, movement, and defender ID to a supported bounded implementation. `RunScene` consumes compiled operations and visual tokens instead of switching on room IDs or reducing them to a generic geometry/defender path.
- Catalog presence remains distinct from human balance, presentation fidelity, and device validation; BALANCE.md tracks those boundaries.

## D-006 — Seeded local challenge systems

**Status:** Implemented

Run RNG, mutation offers and room routes are seeded. Daily Rift derives a seed from the UTC date. Friend Rift serializes boss, seed, weapon, difficulty, modifiers and targets into an ID1 code with a checksum.

**Why**

- Core play remains offline.
- Two players can exchange a compact deterministic configuration without an account.

**Consequences**

- Friend codes are validated locally, not authenticated by a server.
- There is no online leaderboard, remote daily authority or anti-cheat validation. Accepted Daily/Friend runs enter an unverified local outbox under canonical challenge IDs; Story/Abyss calls remain local-only.
- Run IDs intentionally include time and are not deterministic because they serve reward idempotency.

## D-007 — Competitive modes normalize combat upgrades

**Status:** Implemented

Daily and Friend Rift configurations set competitive to true. `PermanentUpgradeEngine` returns baseline combat stats for competitive runs while retaining Rift Dividend solely for Bio-Matter on victory; losses use normalized death retention.

**Why**

- Challenge comparisons are not affected by the owner's Forge progression.

**Consequences**

- Rift Dividend cannot affect score, time, damage, or survivability; it multiplies only winning-run Bio-Matter.
- Temporary mutations selected during a challenge still affect that run.

## D-008 — Touch drag, automatic fire and selectable dash gesture

**Status:** Implemented

Movement follows drag input with smoothing, dead zone, bounds and finger offset. Weapons fire automatically. Dedicated button is the default dash method; double tap and quick flick are alternatives.

**Consequences**

- The primary loop is playable without an on-screen fire button.
- Aim assistance is selectable in Settings and changes combat target selection.
- Keyboard and controller actions exist in the InputMap but RunScene does not consume them yet.
- Gesture preference requires device testing before a production default can be validated.

## D-009 — Code-drawn original visuals

**Status:** Implemented

The Diver, bosses, enemies, projectiles, telegraphs, Nest and transitions are rendered through Godot draw calls.

**Why**

- The current build has a coherent original visual baseline without external or unlicensed art dependencies.
- Semantic projectile shapes remain readable without relying solely on color.

**Consequences**

- There is no imported production sprite/animation pipeline yet.
- Some boss organ changes are represented by status marks rather than detailed anatomical deformation.

## D-010 — Procedural runtime audio

**Status:** Implemented

Short effects and music loops are synthesized into AudioStreamWAV objects from deterministic oscillator/noise recipes.

**Why**

- No copyrighted music or third-party sample library is required.
- State changes can select distinct generated loops.

**Consequences**

- SFX use 22,050Hz mono PCM; three music layers use 11,025Hz generated PCM.
- Four boss profiles and nine music states are selected at runtime, with an eight-entry generated-layer cache and 12 pooled SFX players.
- Armor-hit, organ-damage, and boss-phase cues are emitted from live gameplay through per-cue rate limits.
- There are no mastered external stems or browser/device loudness results. Focused headless tests inspect generated PCM, live-call contracts, cache bounds, and throttling while actual headless playback remains disabled. First-use generation and fade/restart transitions still need mobile profiling and listening QA.

## D-011 — Offline-first save envelope

**Status:** Implemented

Save schema 7 uses a checksummed JSON envelope, temporary write, backup rotation, recovery, migrations and deep defaults. Its versioned Story receipt ledger persists a first-breach beat before display, prevents replay after retry/relaunch, recovers malformed current ledgers to a safe default, and preserves unknown future nested versions for a newer build.

**Why**

- A force-close or malformed primary save should not erase all progress.
- A durable processed-run ledger makes reward banking idempotent across later runs and reloads.

**Consequences**

- Processed run IDs are not evicted, so the ledger grows with completed runs and may eventually need a compact server-backed transaction strategy.
- Save data is local; cloud synchronization and cross-device conflict handling do not exist.
- Settings exposes Reset Progress behind confirmation. It resets the profile, replaces the rotating recovery backup with clean defaults, and idempotently clears the analytics queue plus the Daily/Friend outbox primary, backup, and temporary files. No server-side deletion path exists because no backend record exists.

## D-012 — Local, opt-in analytics abstraction

**Status:** Implemented

AnalyticsService accepts only a named event allowlist, sanitizes primitive properties and stores up to 500 events in a local JSON queue. Opt-in defaults to false.

**Why**

- Gameplay code depends on an internal event API rather than a vendor SDK.
- No analytics data leaves the device in the current build.

**Consequences**

- There is no upload transport or dashboard.
- Retention and conversion targets cannot be claimed from the local queue alone.

## D-013 — Five-stage Last Nest as the progression surface

**Status:** Implemented

The Nest stage is derived from wins and purchased upgrade levels. Facilities exist as locations on a drawn Nest rather than a flat main-menu list.

**Consequences**

- Visual additions appear at stages one through four.
- Facility access is stage-gated.
- Story clears can advance the Nest independently of Forge spending.

## D-014 — Runtime-generated internal routes from authored records

**Status:** Implemented

Every dive selects one traversal, one combat room, one hazard room and the chosen organ chamber after a fixed entrance.

**Why**

- Authored safe rules and boss filters coexist with deterministic variation.

**Consequences**

- The catalog meets the 30-module and 12-chamber inventory counts.
- Forty-two hazard IDs have explicit deterministic contracts. A pure versioned compiler expands them into eight runtime categories, six movement models, 42 named spawn profiles, 25 projectile profiles including the structural-only profile, and ten defender archetypes. Gameplay consumes their geometry, collisions, visual tokens, travel behavior, compiler-signed owner/cycle identity, full warnings, safe pockets, active durations, caps, and atomic cleanup. Projectile events also bind a complete frozen travel-preview set into the execution digest before any side effect.
- The catalog count is no longer represented by a generic shared executor. The remaining validation boundary is human/device readability, reachability, and perceived variety; code-drawn differentiation is not a claim of 42 bespoke art scenes.
- Room completion is time-based except for the organ chamber.

## D-015 — No monetization or backend dependency in 0.1.0

**Status:** Implemented by omission

The project contains no ad SDK, billing SDK, login, cloud save, networked leaderboard client, or service credential. A local-only leaderboard staging service contains no transport.

**Consequences**

- Core gameplay cannot be blocked by network or payment failure.
- Store privacy declarations must continue to match the actual code if services are added later.

## D-016 — Automated headless evidence before release claims

**Status:** Implemented for the current headless suite

The rebuilt local result totals 29,815 assertions with zero failures across 19 suites. The earlier 15-suite set totals 28,973/0, while visual regression 315, story canon 476, Story Overlay 34, and Player Presentation 17 now run independently. Editor/import plus 19 suite drivers produce 20 logs, 19 exact sentinels, and zero engine/script/parse errors. The 8.01-second bounded soak and transaction-recovery self-test pass. Deployed commit `a550ca8` separately retains remote 28,949/0 and public evidence; the rebuilt delta requires a new frozen remote chain.

**Consequences**

- Local headless results are reported separately from browser, simulator and physical-device testing.
- The current suite is not evidence of performance, touch comfort, browser compatibility or native store readiness.

## D-017 — Truthful 0.1.0 version boundary

**Status:** Active

The project version remains 0.1.0 because the current source is a playable development build, not INFINIDIVE 1.0.

**Consequences**

- Catalog counts may meet planned inventory numbers without implying every item is production-complete.
- Public deployment, production-signed native artifacts, final store-media approval, and submission require separate evidence; final Web/Android outputs are structural development evidence only, while iOS has a current-source PCK inside a retained unsigned scaffold rather than a regenerated native project.

## D-018 — Pure room-plan compilation with split runtime ownership

**Status:** Implemented in the current pre-alpha working tree

`RoomMechanics` remains the source of schedule and safe-path contracts. The side-effect-free `RoomPatternRuntime` compiler validates and converts those contracts into deterministic normalized plans; `RunScene` executes only validated plan data. Transient motifs, projectiles, and pending emissions use a short source-wave owner, while defenders use a separate bounded actor owner and intentional cross-pulse effects use a deterministic room/cycle/archetype lineage.

**Why**

- Authored room IDs need real mechanical identities without adding another large room-ID conditional block to `RunScene`.
- A published safe pocket must remain authoritative for the complete damaging interval, including delayed emission and hitch stepping.
- Defenders need enough time to be meaningfully targetable without keeping an old projectile corridor alive into the next telegraph.
- Kill effects such as cover, link break, hatch suppression, and echo disruption sometimes need to affect a successor pulse, but must never leak into another room, cycle, or archetype.

**Consequences**

- The schedule holds the previous pocket through `clear_at`, allows movement during the next telegraph, and validates that the final damage window clears before the forward exit opens.
- Compiler caps bound events, geometry, per-event projectiles, active projectiles, per-event defenders, and active defenders; unsupported or malformed inputs fail closed.
- Runtime telegraph data freezes the player snapshot and bounded recent input history used by tracking/replay profiles. The complete bounded projectile preview is validated and signed into the execution payload before any visual or damaging side effect; delayed specs are digest-checked and filtered again at actual spawn.
- Structural drawing and swept collision derive from the same compiled collision record. Room projectiles preserve source-wave and effect-lineage metadata through the shared pool.
- Nonlinear and homing projectile collision follows ordered simulated subsegments with per-segment radii even when no safe-zone metadata is present, avoiding both missed curve hits and fabricated straight-chord hits under hitch deltas.
- The first arena exit is terminal for a projectile step. Later authored curve points cannot re-enter and collide during the same hitch; collision before that first boundary crossing remains valid.
- Immediate cleanup remains compiler-signed source-wave/cycle scoped; same-lineage successor state is idempotent and time-bounded; room/cycle transitions clear all remaining owned state. Tracking suppression removes actual-homing owned threats and matching pending/future specs instead of changing a previewed curve into an untelegraphed straight path.
- Automated compiler/runtime/travel/effect evidence does not replace physical-device or human playability testing.

## D-019 — Exact, inventory-driven CI test execution

**Status:** Implemented in the current workflow

Every Godot test scene is discovered and reconciled with a version-controlled manifest. The repaired inventory contains 21 scenes: 19 standalone suites, the process-relaunch scene as one nested probe, zero imported probes, and one structural soak. Each standalone suite uses an isolated data root and an exact expected sentinel/assertion count.

**Why**

- Godot can emit a script or parse error while a surrounding test process still exits zero or prints a stale-looking pass summary.
- A newly added test scene must not remain silently outside CI.
- A soak command is not evidence unless its report exists and proves the requested projectile models actually executed.

**Consequences**

- Process failure, any engine `ERROR`, `SCRIPT ERROR`, parse error, missing/duplicated sentinel, assertion-count drift, stale/missing inventory, or invalid/missing soak report pair fails the workflow. The frozen editor-plus-suite pass contained zero error lines; no suite has an error allowlist.
- Soak evidence is a JSON/Markdown transaction. Both outputs stage before commit, validate the complete schema, bind the exact Markdown SHA-256 into JSON, and restore the prior complete pair symmetrically if either side fails. Positive fractional durations are valid; source drift persists as a validated diagnostic `FAIL`. Failure injection covers JSON and Markdown open/write, staged verification, first/second commit, truncated/mixed pairs, fractional duration, and persisted source-change diagnostics.
- The CI validator self-tests `PASS`, diagnostic, malformed, and missing report pairs; requires exact result/transaction/bound-hash parity; requires all seven travel-model requested counts to equal executed counts; and rejects incomplete evidence.
- This hardening improves automated evidence integrity; it does not turn headless results into browser, device, or human-play evidence.

## D-020 — Query-gated read-only Web QA boundary

**Status:** Whole-path/reload v2 deployed and evidence-bound in `a550ca8`; rebuilt hardening delta requires a fresh candidate

The Web build publishes a fixed semantic snapshot only when the exact query parameter `infinidive_qa=1` is present. Normal Web sessions and every non-Web platform leave the publisher disabled. JavaScript can read the snapshot but receives no callback or mutator into Godot.

**Why**

- Canvas touch delivery and changed pixels do not prove that gameplay accepted movement or Dash.
- A stable, narrow contract is less brittle than reading rendered text or exposing arbitrary save/profile fields to browser automation.
- CI must distinguish real gameplay acceptance from accidental movement, stale state, a restarted run, or sanitized numeric corruption.

**Consequences**

- The v2 whitelist retains the movement/Dash fields and adds only bounded health ratios, phase, catalog-valid organ/ability status, a catalog-valid post-loss `BossVisual` token, mutation offer/selection aggregates, and strict tutorial/mutation-discovery aggregate counts plus the fail-closed save load source. Raw nested dictionaries are deep-projected; future top-level or nested fields cannot become observable without an explicit code change and contract update.
- Raw run ID, deterministic seed, currencies, challenge codes, account/player identifiers, analytics payloads, arbitrary profile fields, and arbitrary save contents remain excluded. Diagnostic URLs strip credentials, fragments, and non-QA query strings; diagnostic lists and text are bounded.
- CI requires the same generation throughout, monotonic revision/elapsed, valid finite numeric state, movement of at least 12 logical pixels while Dash count remains unchanged, then an exact Dash-count increment and charge decrease from the dedicated button. The v2 candidate additionally drives the rendered controls through breach, Hunter Eye selection, internal rooms, organ destruction, mutation selection, exterior return, `homing_eye` degradation, `blinded_hunter_eye` rendering, stable post-return state, and a same-context reload with exact persisted aggregate counts.
- Actions run `33594396541` passed the v2 contract against both the CI-served export and the deployed public host; deployment job `100141614551` and public-smoke job `100141657457` bind that evidence to source commit `a550ca867506f34856cf337fbe28083a9cdbaec5`.
- Run `33594396541` closes the CI-served and deployed-public whole-path/reload boundary for the bright Greek-mythic/AION candidate, including the schema-7 first-breach story path. It does not prove the rebuilt accessibility/privacy/notices/icon/Simulator-lane delta. Automated semantic proof is not human control-feel, Mobile Safari/Chrome compatibility, native installation, or physical-device evidence.

## D-021 — Bright Greek-mythic presentation pivot

**Status:** Implemented and publicly deployed in candidate `a550ca8`; human/device art validation remains open

The code-drawn production pipeline remains original, while the presentation direction changes from dark biopunk to a bright mythic sky world: colossal Greek-inspired Titans, open light, marble and bronze structure, aqua/coral accents, chunky touch targets, and high-contrast attack language. The direction is original and does not reproduce another game's interface or assets.

**Why**

- The earlier black-on-black presentation obscured hierarchy, threat readability, and giant-boss scale on a phone.
- A brighter sky-and-temple setting gives the game a clearer identity while preserving the outside–inside–outside combat hook.
- Marble/bronze structure and aqua/coral state colors provide a reusable visual grammar across the HUD, Last Nest, bosses, telegraphs, and selection panels.

**Consequences**

- The deployed source applies the direction to the boss, Last Nest, and run-HUD presentation while retaining touch safe areas, optional Hebrew/RTL support, projectile contrast, and Reduced Motion behavior.
- Deployed `a550ca8` evidence includes historical remote main `2,726/0`, its complete 15-suite remote matrix, Web export, public whole-path/reload smoke, and retained rendered frames from run `33594396541`; rebuilt local main is `2,733/0`. These validate contracts and automated rendering, not taste, human-play readability, mobile rendering, or commercial art quality.
- The public Pages build serves commit `a550ca8` and includes the visual and story pivot. Rebuilt hardening after that commit remains pending revalidation and deployment.

## D-022 — Canonical Aion prologue through a decoupled story layer

**Status:** Story data/service, English-first overlay, prologue, chapter-intro, nonmodal first-breach, and first-clear victory integration deployed in `a550ca8`; human/device validation pending

The opening canon is concise and English-first: Aion is devoured; his final curse is “You craved eternity. Now hunger forever.”; the hero begins without a weapon; and Aion's spark awakens. Hebrew remains an optional explicit localization. Narrative beats are supplied from data rather than embedded in gameplay controllers.

**Why**

- The first-session story must establish motive without delaying first input or requiring a dialogue-heavy campaign.
- A reusable overlay keeps narrative presentation out of `RunScene`, player control code, and content-specific UI conditionals.
- External beat data allows short English/Hebrew sequences and future chapters to share the same presentation contract.

**Consequences**

- The reusable `StoryOverlay` supports touch-safe skip, English-first copy, optional Hebrew/RTL, external beat data, and a Reduced Motion path.
- Main now presents the four-beat Aion prologue before the first Cronus tutorial run, one focused intro before a fresh Story chapter, and one restored-shard beat after the first Story clear. The initial run remains unarmed until movement awakens Aion Spark.
- At the actual first breach, RunScene saves the chapter's unique beat receipt before displaying its short AION line in the HUD. The message is nonmodal: movement, the breach timer, and Dive remain active. Consumed notices cannot repeat on retry/reload, while an injected save failure suppresses display, rolls back, and allows one later successful claim.
- Story eligibility is based on Story difficulty progress and an explicit run-result first-clear marker, so a Daily/Friend/Abyss win cannot suppress a chapter beat. Intro-seen state remains config-scoped across immediate retry rather than separately persisted; breach presentation uses the durable schema-7 Story ledger.
- Remote evidence in run `33594396541` is the strict 15-suite matrix `28,949/0`, including Story Service `164/0` and Story Presentation/first-clear decisions `280/0`, plus public whole-path/reload automation. It does not establish player comprehension, pacing, Mobile Safari/device rendering, or localization fit.
