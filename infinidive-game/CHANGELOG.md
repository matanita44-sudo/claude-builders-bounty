# Changelog

All notable source changes to the Godot implementation of INFINIDIVE are recorded here.

The current project version is 0.1.0. This is a development snapshot, not a claim of a public or store release.

## [Unreleased]

### Evidence updates

- GitHub Actions run [33498494206](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33498494206) validated commit `374bdb5cb8de7f4622917a343e379ff4cfd26232`: `validate`, `web-export`, and `android-debug` succeeded.
- The CI-served Playwright/Chromium smoke returned HTTP 200, started Godot 4.7.2 with WebGL2, created a 540×960 canvas, hid the loading status, and emitted no page errors. This is browser boot automation, not public-host, touch-gameplay, or device evidence.
- The remote Pages artifact records `index.html` at 2,618 bytes / SHA-256 `f86b5f1c0f8985d66056f47c4969f8ae8366b5fb256ebc1098900471188e4336`, `index.pck` at 423,872 bytes / `b0f971a5f56accfd8eec18683978e4da556c3a582ddfad30462db7ae5685a5a1`, and `index.wasm` at 39,514,754 bytes / `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`.
- The remote Android debug artifact is 28,862,289 bytes / SHA-256 `45f1ebc82f1bae1d1cb767456c81fcf405d25b01d5e737c96b06f95084d0ef4c`; CI validated its package/version, min 24/target 36, arm64 ABI, exact normal `android.permission.VIBRATE`, Debug v2/v3 signature, and adaptive icon. It is not an AAB and was not installed.
- Pages deployment did not complete. Rerun job [99862926627](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33498494206/job/99862926627) again failed because `Create Pages site` returned `Resource not accessible by integration`; direct game/support/privacy checks return HTTP 404 and no canvas.
- The current working tree passes 2,538 main-suite assertions plus seven focused suites—backend 82, upgrades 120, tutorial 198, rooms 2,583, meta 111, audio 505, and organ transformations 325—for 6,462 assertions across eight invocations with zero failures.
- A combined real-UI progression smoke fails, banks the 55 Bio-Matter floor, returns to the Nest, buys Reinforced Hull, starts a 110-HP run, fails again, instant-retries, then verifies currency, run count, upgrade, and reward receipts from a separate Godot process.
- Current-working-tree Web static export passes with HTML 2,618 / `190b5852ff3c94b4d2e6ce2849bdbc92cb64e77c6cb972d35165b9cf544713b5`, PCK 440,384 / `f9acf67d893ab6513f2b7fde450fcd2129331ba8252b3464132d94892b85b9d4`, and WASM 39,514,754 / `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`. The Android debug validator passes for 28,878,673-byte APK `2d3d5fa6f283381fd31aa1702df2cc697c80f12d0d7a96e6c1e22b59c33cdcef`; export warned of build-tools 34.0.4 fallback while targeting 36. Remote run 33498494206 remains evidence only for older commit `374bdb5cb8de7f4622917a343e379ff4cfd26232`.
- Full current-tree iOS project export failed because the Development Team is blank. `--export-pack iOS` refreshed only the retained scaffold's PCK to 440,480 bytes / `ac426ba74dd8993ea129448d2258d4f1b36ea3ee2fd48c28fd342bda53401db6`; the unchanged pbxproj remains `dbbc0f658d31f09a8ad0b020a4ef1d1f6072e422088d13c996dd0d09ee7748bb`, and the 411-byte plist remains `50c3cbc7d11c6c3c37357dc14e59ef93f1c011897467a9b94bb11637a795ea7d`. This is not a full current Xcode export and no compile/sign is claimed.

### Changed

- Replaced binary-only organ shutdown with 12 required data-driven loss contracts. Seven organs retain safer authored `aimed_fan`, `ring`, or `lane` variants; five systems shut down completely.
- Added 12 unique BossVisual loss states, explicit post-loss telegraph/safe-path contracts, attributable transformed projectile waves, and distinct English/Hebrew transformed-versus-disabled feedback.
- Added a 325-assertion organ-transformation suite covering data guardrails, exact described patterns, readable ring telegraph alignment, live `RunScene` consumption, visuals, isolation, and idempotency.
- Main TestRunner now requires `INFINIDIVE_TEST_ISOLATED=1` plus an isolated temporary `XDG_DATA_HOME`, failing closed before it can touch an ordinary player profile.
- Rail Spine now resolves every crossed collinear target nearest-to-farthest until pierce is exhausted, with per-hit falloff and duplicate-target protection.

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

- Godot 4.7.2 main headless suite on 2026-09-01: 2,538 assertions passed, 0 failed (`artifacts/headless-tests.xml`).
- Focused local suites also passed: backend/offline 82, permanent upgrades 120, tutorial 198, room mechanics 2,583, meta goals 111, adaptive audio 505, and organ transformations 325; all eight invocations total 6,462 assertions with zero failures. The JUnit artifact records only the 2,538-assertion main suite.
- A 1,800.019-second Linux headless soak completed with zero recorded failures, but source changed after its process snapshot loaded. It is structural evidence, not release-candidate or target-device performance evidence.
- A separate current-tree 90.02-second soak completed 1,563 pressure/projectile cycles, 157 restarts, 157 Dive transitions, 78 save writes, and 676 offline events with peak 540 projectiles, an unchanged source fingerprint, and zero failures.
- These results are not evidence of mobile Safari, mobile Chrome, Android hardware, iPhone hardware, signed native exports, or store review.

### Current known limitations

- All 42 mutation effect keys and all 18 permanent-upgrade effect keys have explicit contracts, runtime consumers, and focused behavioral coverage; human balance/feel validation remains absent.
- Forge prerequisites are enforced. Competitive Daily/Friend runs retain only Rift Dividend for victory Bio-Matter while normalizing combat-affecting permanent stats; losses are not multiplied.
- Rail Spine now resolves every collinear target crossed in one physics step nearest-to-farthest until pierce is exhausted; human balance remains untested.
- Bio-Matter pickups use a bounded lightweight dictionary array rather than a formal reusable object pool.
- Breaches expire after their seven-second baseline window, extended by Breach Anchor.
- Forty-two room profiles execute deterministic warnings, safe gaps, active windows, maximum-active bounds and cleanup, but visual presentation still collapses them to three broad geometries with one generic defender; named pattern/movement identities and human reachability remain incomplete.
- Bosses have distinct data, silhouettes and ability sets but still share attack-controller families.
- The ten-step tutorial observes and persists real events, replay spans the RunScene-to-Forge boundary, legacy completion migrates to the full mask, and defense can advance from a real no-hit/no-Dash telegraphed volley or Dash. Human comprehension/timing remains unvalidated.
- English/Hebrew key and launch-catalog coverage plus representative RTL widgets pass headless tests; device text-fit and live layout QA remain unperformed.
- Projectile-speed, telegraph, dash-window, and aim-assist controls are exposed and consumed. Damage-flash intensity and reduced-motion coverage remain incomplete.
- Analytics remains local, defaults off, and has a Settings control; there is no analytics upload transport.
- Completed Daily/Friend runs queue challenge-separated, validated, unverified local summaries; Story/Abyss results do not consume the outbox. There is no backend transport, account, online leaderboard UI, fetched config, or cloud save.
- Current-working-tree Web and debug-signed Android outputs pass local structural validation with recorded hashes. Only the PCK payload was refreshed inside the retained iPhone-targeted Xcode scaffold; full current-tree project export remains blocked by the blank Team ID. A remote CI-served Chromium boot smoke passed only for commit `374bdb5`, but no public deployment, touch-gameplay browser automation, release-signed AAB, current-tree Xcode compile/archive, native install, or store upload exists.
- Remote validation/Web/Android jobs pass only for the recorded older commit. Pages rerun job 99862926627 failed at site creation, and direct game/support/privacy checks remain HTTP 404; no mobile-browser or physical-device test is claimed.
- Development icon/brand exports, five real-runtime stills, a 1080×1920 audio-complete social trailer, an 886×1920 audio-complete Apple-format technical candidate/poster, and bilingual privacy/support drafts exist with provenance and hashes. The Apple candidate still requires supported-iPhone recapture; none of these is final legal approval, public deployment, store acceptance, or submission.
