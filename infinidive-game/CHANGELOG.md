# Changelog

All notable source changes to the Godot implementation of INFINIDIVE are recorded here.

The current project version is 0.1.0. This is a development snapshot, not a claim of a public or store release.

## [Unreleased]

### Evidence updates

- GitHub Actions run [33514397476](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476) tested commit `8e4be78267a043072827963d6492c7964239ae94`. Validate job `99877648950`, Web job `99877839855`, and Android job `99877839931` passed.
- Validate passed all eight invocations: main 2,538; backend 82; upgrades 120; tutorial 198; rooms 2,583; organ 325; meta 111; audio 505; all zero failures.
- Current-commit Web export records HTML 2,618 bytes, PCK 440,384 bytes, and WASM 39,514,754 bytes in Pages artifact `9803007777`. Chromium smoke artifact `9803006599` records HTTP 200, Godot 4.7.2, WebGL2, canvas 540×960, hidden loading status, and no page errors. No remote hash is inferred from the separate local hashes below.
- Current-commit Android debug export used build-tools 36 and produced SHA-256 `9b981f4d0accc600ef8f869e600b16f5585533ea1fe4cf8c71a983cfbdd87172` in artifact `9802998519`. It is not an AAB and was not installed.
- Pages deployment did not complete. Deploy job [99878161111](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476/job/99878161111) failed exactly at Get Pages `Not Found` / Create Pages `Resource not accessible by integration`; direct game/support/privacy checks remain HTTP 404 with no canvas.
- The current working tree passes 2,538 main-suite assertions plus seven focused suites—backend 82, upgrades 120, tutorial 198, rooms 2,583, meta 111, audio 505, and organ transformations 325—for 6,462 assertions across eight invocations with zero failures.
- A combined real-UI progression smoke fails, banks the 55 Bio-Matter floor, returns to the Nest, buys Reinforced Hull, starts a 110-HP run, fails again, instant-retries, then verifies currency, run count, upgrade, and reward receipts from a separate Godot process.
- Local commit-candidate Web static export passes with HTML 2,618 / `190b5852ff3c94b4d2e6ce2849bdbc92cb64e77c6cb972d35165b9cf544713b5`, PCK 440,384 / `f9acf67d893ab6513f2b7fde450fcd2129331ba8252b3464132d94892b85b9d4`, and WASM 39,514,754 / `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`. The local Android debug validator passes for 28,878,673-byte APK `2d3d5fa6f283381fd31aa1702df2cc697c80f12d0d7a96e6c1e22b59c33cdcef`; local export warned of build-tools 34.0.4 fallback while targeting 36. These local hashes remain separate from the remote artifact evidence above.
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
- Current-commit Web and debug-signed Android outputs pass local structural validation with recorded local hashes, and current-commit CI independently passes validation/Web/Chromium/Android with retained remote artifacts. Only the PCK payload was refreshed inside the retained iPhone-targeted Xcode scaffold; full current-tree project export remains blocked by the blank Team ID. No public deployment, touch-gameplay browser automation, release-signed AAB, current-tree Xcode compile/archive, native install, or store upload exists.
- Current deploy job 99878161111 failed at Pages site creation, and direct game/support/privacy checks remain HTTP 404; no mobile-browser or physical-device test is claimed.
- Development icon/brand exports, five real-runtime stills, a 1080×1920 audio-complete social trailer, an 886×1920 audio-complete Apple-format technical candidate/poster, and bilingual privacy/support drafts exist with provenance and hashes. The Apple candidate still requires supported-iPhone recapture; none of these is final legal approval, public deployment, store acceptance, or submission.
