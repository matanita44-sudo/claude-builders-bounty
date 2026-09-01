# Changelog

All notable source changes to the Godot implementation of INFINIDIVE are recorded here.

The current project version is 0.1.0. This is a publicly deployed pre-alpha development snapshot, not a release candidate or store release.

## [Unreleased]

### Semantic Web QA candidate

- Added a read-only Web QA snapshot that exists only when the exact query `?infinidive_qa=1` is present. It exposes a fixed whitelist of Nest/run state, player position, movement observation, Dash counters/charge, monotonic revision, and ephemeral run generation. It does not expose raw run IDs, seeds, saves, profile/currency data, challenge codes, account identifiers, or analytics payloads.
- Added explicit `state_valid` and `numeric_state_valid` guards. Invalid enum, missing player state, non-finite position/timing, or impossible Dash ranges fail the semantic smoke instead of being normalized into plausible values.
- Upgraded both CI-served and public-host Chrome smoke paths to prove Nest-to-run transition, at least 12 logical pixels of drag movement with `movement_observed` changing false-to-true, unchanged Dash count before the button tap, exact `dash_count + 1`, consumed charge, stable `run_generation`, monotonic revision/elapsed trace, and durable acceptance. Page crashes, JavaScript errors, and failed critical JS/WASM/PCK requests now fail closed with stage-specific evidence.
- Current candidate fingerprints are production `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e` and tracked tests/CI `ff2530d3aad779a21a3b775e8d973ba1b3e3c37a86b5b97cea133801c954dc59`. Strict editor import and all 13 suites passed `28,410/0` with zero engine/script/parse errors. Fresh 8.049-second and 90.041-second source-bound reports passed 7/7 model coverage with zero failures; the required current-source 30-minute CI and deployed semantic smoke remain pending.

### Evidence updates

- Frozen production source is pushed as commit [`67e2c54a177e9117d11a9f791f07aae703cdea5b`](https://github.com/matanita44-sudo/claude-builders-bounty/commit/67e2c54a177e9117d11a9f791f07aae703cdea5b) with exact tree `4133ea44b900b3143e90f33513105fcb04547015`.
- GitHub Actions run [33557365042](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33557365042), attempt 2, passed overall. The strict Validate path reported 28,410/0 across all 13 suites, the current Web export booted successfully in CI Chrome, and current Android debug export/validation passed.
- Pages deploy job [100024023277](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33557365042/job/100024023277) passed. Direct public checks return HTTP 200 for the game root, privacy, support, PCK, and WASM at `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/`.
- Source-bound long-soak job [`100030992601`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33559947112/job/100030992601) in run [33559947112](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33559947112) passed and retained artifact `9822001845`. The later runtime run intentionally skips another 30-minute execution after its Validate job accepts this retained current-source report.
- Runtime-evidence commit [`380b6d4b632e9d507ea42075714d0f18d6cdb74f`](https://github.com/matanita44-sudo/claude-builders-bounty/commit/380b6d4b632e9d507ea42075714d0f18d6cdb74f) passed run [33565500042](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33565500042): validate, Web export/CI Chrome, Android debug, deploy job [`100049011404`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33565500042/job/100049011404), and public-smoke job [`100049076641`](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33565500042/job/100049076641) all passed. Artifact `9823113363` is 90,667 bytes / `5038d055d8cf723b479424b4d099d0e3c036bb4e9eb325cb9c1ee6e00b750985`; it records HTTP 200, a live 540×960 canvas, zero errors, 3/3/3 synthetic touch start/move/end events, and rendered hashes `31212c7891fccbb64e3993062614178a854ac29b185878ee1a5db2963ccf2e23` -> `94e6d2654a466e0ecb37670e6621d2b873eb5c9c56c39a5565ea2f38afa0b6d8`. The final screenshot visibly shows gameplay and Phase 89%. This proves synthetic canvas event delivery, continued live execution, and visual change—not semantic acceptance of the entire control path, mobile-browser/device behavior, or human feel.
- The final frozen local matrix passed 28,410 assertions across 13 suites with zero failures: main 2,631; backend 82; upgrades 120; tutorial 198; room mechanics 3,541; compiler 15,515; pure/live defender effects 354/212; projectile travel 685; live integration 4,131; organs 325; meta 111; audio 505. Editor and every suite passed the strict wrapper with zero error lines. `headless-tests.xml` records main 2,631/0; production/tracked-tests-CI fingerprints are `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382` / `e0af48b5b24e2333c928e685eccd12991c22f05d4cd8c37dc1c08f926bcb756b`.
- A combined real-UI progression smoke fails, banks the 55 Bio-Matter floor, returns to the Nest, buys Reinforced Hull, starts a 110-HP run, fails again, instant-retries, then verifies currency, run count, upgrade, and reward receipts from a separate Godot process.
- Verified packages under `build/final-0.1.0-e942db6f`: Web ZIP `INFINIDIVE-0.1.0-prealpha-web-e942db6f.zip` (11,017,962 bytes; `8df771d497ce98c5807e40bf2e2f0bff9aa5bbdb74f614551668b8fd559b0001`), `INFINIDIVE-0.1.0-prealpha-debug-e942db6f.apk` (`d089cebf…`), and `INFINIDIVE-0.1.0-prealpha-ios-unsigned-e942db6f.zip` (`5e3276c7…`); `BUILD_EVIDENCE.md` and `SHA256SUMS` pass. Packaged and live privacy hash to `81cf55f7f9e4c18a9c3a611593f358597020e93e61e594d89da482fd80bae17e`; packaged and live support hash to `283e82c98eb26180c6426b2d9fcba919f0546eec8ea714f487b1eb5c50a802b2`. Web static/local-HTTP, current CI Web/Chrome, narrow synthetic public-host touch/frame smoke, current CI Android structural validation, and iOS current-source PCK headless boot pass. Semantic control acceptance, native install, production signing, physical-device, and store evidence remain absent.
- The room-runtime matrix passed 24,438/0: mechanics 3,541; compiler 15,515; pure/live effects 354/212; travel 685; integration 4,131. New coverage includes lane topology, 30/60/120 Hz player homing, pre-retirement swept collision, first-contact order, and exact `16/3s` first-exit handling.
- Regenerated source-bound soaks share unchanged start/end production fingerprint `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`, 7/7 exact model coverage, peak 540, complete transactions, and zero failures. The 8.031-second smoke completed 86 cycles, nine restarts/Dives, six saves, transaction `9ac05a1b4bcc696001e5a6e7`, JSON `d8d5c6c5b0667f3b53844839f5955841430e85842ea168220c1a0d8ca4b5c1e9`, and Markdown/bound `9ba26093ba394c70b591130544a21094e719d0801d55755d82fd0e5c93814c27`. The 90.048-second soak completed 1,169 cycles, 117 restarts/Dives, 60 save writes, 637 queue events / three queue reloads / final 500, stable delta 90,040 bytes, slope 218,786.041893738 B/min, transaction `26dad83d28067418d76982a3`, JSON `2bc054556fe9e0c75813feb7e50dfcae5844c8140e4491bfd599e9129309c4c1`, and Markdown/bound `026962ed338b02db99cfee0ecb08bc16b197c9b2abd1544214e11ed61e69ab83`.
- The now-prior `e942db6f` 30-minute CI soak passed for 1,800.043 seconds with seed 203541, 26,676 iterations/cycles, 2,668 restarts/Dives, 1,335 save writes / 22 save reloads, 3,188 queue events / 24 queue reloads / final 500, stable delta 3,667,676 bytes, and slope 84,517.9971965645 B/min. Transaction `5c047f1a630e8e1de5c5ffff` is complete; JSON is 53,857 bytes / `2f8171e8317572f31fd479884edcaa441452082640a9be4f3fe9339da02710b4`, and Markdown is 1,091 bytes / bound `a508864e78c75981e8221df2c53f0ed97c82501295e999328fa86b78970f1856`. Artifact `9822001845` is a 9,042-byte ZIP with SHA-256 `f93bd2c76a640c8cc2ccbc80593112752bf625298f00af86037091c667b7d29c`.
- Production fingerprinting intentionally excludes `assets/store/gameplay/raw/`, which is local-only, non-exported capture provenance rather than executable product source.

### Changed

- Replaced binary-only organ shutdown with 12 required data-driven loss contracts. Seven organs retain safer authored `aimed_fan`, `ring`, or `lane` variants; five systems shut down completely.
- Added 12 unique BossVisual loss states, explicit post-loss telegraph/safe-path contracts, attributable transformed projectile waves, and distinct English/Hebrew transformed-versus-disabled feedback.
- Added a 325-assertion organ-transformation suite covering data guardrails, exact described patterns, readable ring telegraph alignment, live `RunScene` consumption, visuals, isolation, and idempotency.
- Main TestRunner now requires `INFINIDIVE_TEST_ISOLATED=1` plus an isolated temporary `XDG_DATA_HOME`, failing closed before it can touch an ordinary player profile.
- Rail Spine now resolves every crossed collinear target nearest-to-farthest until pierce is exhausted, with per-hit falloff and duplicate-target protection.
- Replaced the former generic internal-room executor with a pure, fail-closed runtime-plan compiler and live plan consumer. All 42 rooms now map through eight runtime categories, six movement models, 42 named spawn profiles, 25 projectile profiles including structural-only hazards, and ten defender archetypes with compiled geometry, collision, visual, travel, lifecycle, ownership, and deterministic signatures.
- Room schedules now hold the prior safe pocket through its clear boundary, leave a non-overlapping warning before the next activation, and clear the final damaging window before the exit opens. Structural motifs use swept collision under hitch deltas and share thickness parameters with their code-drawn presentation.
- Split transient source-wave ownership from longer-lived defender actor groups. Added bounded, deterministic defender kill effects for interruption, priority marks, cover, tracking/link/hatch/echo disruption, and false-target reveal, with same-lineage successor behavior and unrelated-lineage isolation.
- Room projectile plans freeze the telegraphed player snapshot and bounded recent input history, build and validate the complete finite projectile preview before side effects, sign that preview into the execution digest, preserve a safe exclusion disk, bound delayed emissions to the active window, digest-check and re-filter delayed specs at spawn time, and atomically clear compiler-signed owner/cycle projectiles, motifs, actors, pending emissions, and effect state at their declared boundaries.
- Pause hardening now rejects Dive requests while `BREACH_OPEN` is paused, preserves the pause overlay and locked controls, and restores the legal Dive action only after manual resume; the main suite covers both sides of that transition.
- Tracking suppression now removes already-live owned projectiles with actual positive homing and suppresses matching pending/future specs. It preserves non-homing and foreign-owned controls and never straightens a previewed curved threat into a new path.
- Nonlinear/homing projectile simulation now records curve-following swept collision subsegments with matching radii even when no safe-zone metadata is present, preventing both chord-created false hits and curve-missed real hits under large deltas.
- Projectile simulation now treats the first arena exit as terminal, so a recorded path cannot re-enter and hit later in the same hitch; true collision before the first exit remains valid.
- CI now inventories all Godot test scenes and runs editor plus each standalone suite with an isolated data root through an exact sentinel/count wrapper. Any engine error, script/parse error, missing/duplicated summary, count drift, stale inventory, or invalid soak report pair fails the workflow; the frozen pass emitted zero error lines.
- Soak evidence now commits JSON and Markdown symmetrically as one full-schema transaction, binds the exact Markdown SHA-256 into JSON, recovers truncated/mixed primary-backup states, and rolls back byte-for-byte on either-side open/write/verify/first-commit/second-commit failure injection. Positive fractional durations are supported; source drift persists as a validated diagnostic `FAIL`; the CI validator self-tests `PASS`, diagnostic, and strict negative fixtures and requires all seven requested travel models to match executed counts.

## [0.1.0-dev] — 2026-09-01

### Added

- Godot 4.7.2 portrait project with a 540 × 960 logical viewport and GL Compatibility rendering.
- Touch-drag movement with smoothing, finger offset, dead zone and bounded play areas.
- Native and Web safe-area fitting for the Last Nest and combat HUD.
- Automatic weapon targeting and firing.
- Phase Dash with a dedicated button plus optional double-tap and flick gestures.
- Player hull, one-hit shields, hit invulnerability, damage feedback, haptics and death attribution.
- Pooled player and enemy projectile simulation with swept segment collision.
- Explicit run states for exterior combat, breach, organ selection, dive, internal rooms, organ chamber, mutation choice, return, final core, death and victory.
- Three armor phases, three player-selected organ dives and a final core sequence.
- OrganAbilityMap with idempotent organ destruction and exterior ability disabling.
- Four boss data records and code-drawn silhouettes:
  - GRAVEMAW
  - SERAPH-9
  - ABYSS LEVIATHAN
  - NULL TWIN
- Five weapon records and runtime behaviors:
  - Pulse Needle
  - Scatter Maw
  - Rail Spine
  - Arc Swarm
  - Void Orbitals
- Catalog of 24 temporary mutations.
- Catalog of 18 permanent upgrades.
- Catalog of 30 non-chamber internal modules and 12 organ chambers.
- Seeded mutation offers, offer-ID validation, per-run rerolls and seeded internal route generation.
- Local Story Descent, UTC-date Daily Rift, Friend Rift code and Abyss Loop entry flows.
- Friend Rift ID1 encode/decode, validation, checksum and clipboard sharing.
- Bio-Matter banking, Story Core Shards, sequential boss unlocks and weapon unlocks.
- Five visual Last Nest stages with Hangar, Forge, Research Vat, Rift Terminal, Trophy Chamber and Core Chamber.
- Versioned schema-6 saves with checksum, temporary-file promotion, backup rotation, migration, recovery and durable run-id deduplication.
- English and Hebrew string tables for the Nest/settings surface.
- Audio, haptic, control, contrast, reduced-motion and handedness settings.
- Runtime-synthesized sound effects plus three-layer adaptive music across nine states and four boss tonal identities, including rate-limited live armor-hit, organ-damage, and boss-phase cues.
- Opt-in, allowlisted local analytics queue with no network transport.
- Event-driven ten-step tutorial state plus replay-on-next-run control.
- Explicit 42-key mutation and 18-key permanent-upgrade runtime contracts, Forge prerequisite enforcement, and focused behavioral tests.
- Forty-two deterministic room hazard contracts with runtime warning, safe-gap, active-cap, cleanup, and hitch-playback invariants; 14 local achievements; and 19 rotating local contracts.
- Canonical Daily/Friend challenge identities and challenge-separated validated outbox submissions; Story/Abyss results remain local-only and transport remains deliberately unavailable.
- Confirmed Reset Progress UI flow with a clean-default recovery backup and idempotent deletion of the analytics queue plus Daily/Friend leaderboard primary, backup, and temporary files.
- Bilingual pre-release Terms draft plus Godot MIT/open-source notice.
- Verified raster exports for the 1024×1024 RGB app icon, 512×512 RGBA Play icon, and 1024×500 RGB/no-alpha Google feature graphic, plus original hashed Android adaptive background/foreground/monochrome SVG layers.
- Web, Android and iOS export presets.
- Custom Web loading shell.
- GitHub Actions workflow for Godot import, headless tests, Web export, headless-Chrome boot smoke and Pages artifact deployment.
- Verified Android template-install path: CI extracts `android_source.zip`, integrated debug export creates `android/build`, and both Android presets request only normal `android.permission.VIBRATE` for optional haptics. No AAB compilation/signing is claimed.
- Headless tests for content counts, all three-organ orders, challenge codes, mutation determinism, room determinism, projectile collision/pooling, dash invulnerability, save recovery and the first complete outside–inside–outside hook.

### Verified locally

- Godot 4.7.2 main headless suite on 2026-09-01: 2,631 assertions passed, 0 failed (`artifacts/headless-tests.xml`).
- The final frozen local matrix across all 13 suites is 28,410 assertions with zero failures; editor import and every suite passed the strict wrapper with zero error lines. The JUnit artifact records only the 2,631-assertion main suite.
- The earlier pre-transactional soak reports were superseded by the current source-bound 8.031-second, 90.048-second, and 1,800.043-second transactional evidence recorded under `[Unreleased]`.
- These results are not evidence of mobile Safari, mobile Chrome, Android hardware, iPhone hardware, signed native exports, or store review.

### Current known limitations

- All 42 mutation effect keys and all 18 permanent-upgrade effect keys have explicit contracts, runtime consumers, and focused behavioral coverage; human balance/feel validation remains absent.
- Forge prerequisites are enforced. Competitive Daily/Friend runs retain only Rift Dividend for victory Bio-Matter while normalizing combat-affecting permanent stats; losses are not multiplied.
- Rail Spine now resolves every collinear target crossed in one physics step nearest-to-farthest until pierce is exhausted; human balance remains untested.
- Bio-Matter pickups use a bounded lightweight dictionary array rather than a formal reusable object pool.
- Breaches expire after their seven-second baseline window, extended by Breach Anchor.
- Forty-two room profiles now execute authored structural/projectile/movement identities, ten defender archetypes, and scoped kill effects with deterministic warnings, safe pockets, active windows, caps, and cleanup. Human readability, reachability, perceived variety, and balance remain unvalidated on browsers and physical devices.
- Bosses have distinct data, silhouettes and ability sets but still share attack-controller families.
- The ten-step tutorial observes and persists real events, replay spans the RunScene-to-Forge boundary, legacy completion migrates to the full mask, and defense can advance from a real no-hit/no-Dash telegraphed volley or Dash. Human comprehension/timing remains unvalidated.
- English/Hebrew key and launch-catalog coverage plus representative RTL widgets pass headless tests; device text-fit and live layout QA remain unperformed.
- Projectile-speed, telegraph, dash-window, and aim-assist controls are exposed and consumed. Damage-flash intensity and reduced-motion coverage remain incomplete.
- Analytics remains local, defaults off, and has a Settings control; there is no analytics upload transport.
- Completed Daily/Friend runs queue challenge-separated, validated, unverified local summaries; Story/Abyss results do not consume the outbox. There is no backend transport, account, online leaderboard UI, fetched config, or cloud save.
- Final local Web and debug-signed Android outputs pass structural validation with recorded hashes. Runtime-evidence commit `380b6d4b632e9d507ea42075714d0f18d6cdb74f` passed current remote validation, Web export/CI Chrome boot, Android debug validation, Pages deployment, and narrow public-host synthetic touch/frame-change smoke in run `33565500042`. The current-source iOS PCK is assembled only into a retained unsigned scaffold after full export failed on blank Team ID. No semantic whole-path/reload result, release-signed AAB, full current-source Xcode export/compile/archive/sign, native install, or store upload exists.
- Deploy job `100049011404` and public-smoke job `100049076641` passed; direct game/privacy/support/assets checks return HTTP 200. Artifact `9823113363` retains the touch-event/frame-change evidence. No mobile Safari/Chrome, human-control, simulator, or physical-device test is claimed.
- Development icon/brand exports, five real-runtime stills, a 1080×1920 audio-complete social trailer, an 886×1920 audio-complete Apple-format technical candidate/poster, and bilingual privacy/support drafts exist with provenance and hashes. The privacy/support drafts are reachable in the pre-alpha Pages deployment, but final legal approval has not occurred; the Apple candidate still requires supported-iPhone recapture, and none of the media is store-accepted or submitted.
