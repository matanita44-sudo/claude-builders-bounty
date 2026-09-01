# Changelog

All notable source changes to the Godot implementation of INFINIDIVE are recorded here.

The current project version is 0.1.0. This is a development snapshot, not a claim of a public or store release.

## [Unreleased]

### Evidence updates

- Historical GitHub Actions run [33514397476](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476) tested commit `8e4be78267a043072827963d6492c7964239ae94`. Validate job `99877648950`, Web job `99877839855`, and Android job `99877839931` passed; this run predates the frozen local tree.
- That historical Validate job passed its then-configured eight invocations: main 2,538; backend 82; upgrades 120; tutorial 198; rooms 2,583; organ 325; meta 111; audio 505; all zero failures.
- Historical remote Web export for commit `8e4be782` records HTML 2,618 bytes, PCK 440,384 bytes, and WASM 39,514,754 bytes in Pages artifact `9803007777`. Chromium smoke artifact `9803006599` records HTTP 200, Godot 4.7.2, WebGL2, canvas 540×960, hidden loading status, and no page errors. These files are not the frozen local export.
- Historical Android debug export for commit `8e4be782` used build-tools 36 and produced SHA-256 `9b981f4d0accc600ef8f869e600b16f5585533ea1fe4cf8c71a983cfbdd87172` in artifact `9802998519`. It is not the frozen local APK, not an AAB, and was not installed.
- Pages deployment did not complete. Deploy job [99878161111](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476/job/99878161111) failed exactly at Get Pages `Not Found` / Create Pages `Resource not accessible by integration`; direct game/support/privacy checks remain HTTP 404 with no canvas.
- The final frozen local matrix passed 28,410 assertions across 13 suites with zero failures: main 2,631; backend 82; upgrades 120; tutorial 198; room mechanics 3,541; compiler 15,515; pure/live defender effects 354/212; projectile travel 685; live integration 4,131; organs 325; meta 111; audio 505. Editor and every suite passed the strict wrapper with zero error lines. `headless-tests.xml` records main 2,631/0; production/tests-CI fingerprints are `8e9810de2615332713f86f47bf2f28f38728fb75e51ea5bfaf2d16760927d863` / `db398ae7804cf75e6741e13380993f9425d42b3e44de8da62631f159595f1597`.
- A combined real-UI progression smoke fails, banks the 55 Bio-Matter floor, returns to the Nest, buys Reinforced Hull, starts a 110-HP run, fails again, instant-retries, then verifies currency, run count, upgrade, and reward receipts from a separate Godot process.
- Verified packages under `build/final-0.1.0-8e9810de`: `INFINIDIVE-0.1.0-prealpha-web-8e9810de.zip`, `INFINIDIVE-0.1.0-prealpha-debug-8e9810de.apk`, and `INFINIDIVE-0.1.0-prealpha-ios-unsigned-8e9810de.zip`; `BUILD_EVIDENCE.md` and `SHA256SUMS` pass. Web static/local-HTTP and Android structural validation pass; iOS current-source PCK headless boot passes. No current browser canvas, native install, production signing, physical-device, or store claim.
- The room-runtime matrix passed 24,438/0: mechanics 3,541; compiler 15,515; pure/live effects 354/212; travel 685; integration 4,131. New coverage includes lane topology, 30/60/120 Hz player homing, pre-retirement swept collision, first-contact order, and exact `16/3s` first-exit handling.
- Final soaks: 8.014s, 87 cycles, 9 restarts/Dives, 6 saves, 529 events/2 reloads/final 500, tx `b5a5db690e1513095a2cf63f`, JSON `dbcbf0bdb4fc9e6fb763a5c344f274872cb13875696764fe118a4bf8c3901bdb`, Markdown `15cd17499c54496ad909536039a3706f46c2fc197c856aa4b9fd89feaf2f5167`; and 90.118s, 1,141 cycles, 115 restarts/Dives, 58 saves, 634 events/3 reloads/final 500, tx `22c5717c57c6018e8189b84f`, JSON `119157a6aaf32943c30062dd2b51fe0ee1182b525b50acd0017c8f8c2150c5cf`, Markdown `30c3b34a24347a5d6267929dc1a1f37bbd3b4a2f7374d64a6b446b6e66679bea`; both 7/7, peak 540, zero failures, unchanged `8e9810de...`.

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
- A 1,800.019-second Linux headless soak completed with zero recorded failures, but source changed after its process snapshot loaded. It is structural evidence, not release-candidate or target-device performance evidence.
- Historical note: an earlier 90.02-second source-locked soak passed its then-current snapshot, but its report pair has been superseded by later transactional-validator hardening; current frozen evidence is recorded only under `[Unreleased]` after regeneration.
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
- Final local Web and debug-signed Android outputs pass structural validation with recorded hashes; historical commit `8e4be782` separately passed remote validation/Web/Chromium/Android. The current-source iOS PCK is assembled only into a retained unsigned scaffold after full export failed on blank Team ID. No public deployment, final-Web browser/touch automation, release-signed AAB, full current-source Xcode export/compile/archive/sign, native install, or store upload exists.
- Current deploy job 99878161111 failed at Pages site creation, and direct game/support/privacy checks remain HTTP 404; no mobile-browser or physical-device test is claimed.
- Development icon/brand exports, five real-runtime stills, a 1080×1920 audio-complete social trailer, an 886×1920 audio-complete Apple-format technical candidate/poster, and bilingual privacy/support drafts exist with provenance and hashes. The Apple candidate still requires supported-iPhone recapture; none of these is final legal approval, public deployment, store acceptance, or submission.
