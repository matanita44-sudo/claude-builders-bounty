# Changelog

All notable source changes to the Godot implementation of INFINIDIVE are recorded here.

The current project version is 0.1.0. This is a development snapshot, not a claim of a public or store release.

## [Unreleased]

No changes are recorded after the 0.1.0 development snapshot below.

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

- Godot 4.7.2 main headless suite on 2026-09-01: 2,508 assertions passed, 0 failed (`artifacts/headless-tests.xml`).
- Focused local suites also passed: backend/offline 82, permanent upgrades 120, tutorial 198, room mechanics 2,583, meta goals 111, and adaptive audio 505; all seven invocations total 6,107 assertions with zero failures. The JUnit artifact records only the 2,508-assertion main suite.
- A 1,800.019-second Linux headless soak completed with zero recorded failures, but source changed after its process snapshot loaded. It is structural evidence, not release-candidate or target-device performance evidence.
- A separate reconciled-tree 90.02-second soak completed 1,604 pressure cycles, 161 restarts, and 161 Dive transitions with an unchanged source fingerprint and zero failures.
- These results are not evidence of mobile Safari, mobile Chrome, Android hardware, iPhone hardware, signed native exports, or store review.

### Current known limitations

- All 42 mutation effect keys and all 18 permanent-upgrade effect keys have explicit contracts, runtime consumers, and focused behavioral coverage; human balance/feel validation remains absent.
- Forge prerequisites are enforced. Competitive Daily/Friend runs retain only Rift Dividend for victory Bio-Matter while normalizing combat-affecting permanent stats; losses are not multiplied.
- Rail Spine resolves only one projectile collision per physics step and can skip additional collinear targets crossed in the same step.
- Bio-Matter pickups use a bounded lightweight dictionary array rather than a formal reusable object pool.
- Breaches expire after their seven-second baseline window, extended by Breach Anchor.
- Forty-two room profiles execute deterministic warnings, safe gaps, active windows, maximum-active bounds and cleanup, but visual presentation still collapses them to three broad geometries with one generic defender; named pattern/movement identities and human reachability remain incomplete.
- Bosses have distinct data, silhouettes and ability sets but still share attack-controller families.
- The ten-step tutorial observes and persists real events, replay spans the RunScene-to-Forge boundary, legacy completion migrates to the full mask, and defense can advance from a real no-hit/no-Dash telegraphed volley or Dash. Human comprehension/timing remains unvalidated.
- English/Hebrew key and launch-catalog coverage plus representative RTL widgets pass headless tests; device text-fit and live layout QA remain unperformed.
- Projectile-speed, telegraph, dash-window, and aim-assist controls are exposed and consumed. Damage-flash intensity and reduced-motion coverage remain incomplete.
- Analytics remains local, defaults off, and has a Settings control; there is no analytics upload transport.
- Completed Daily/Friend runs queue challenge-separated, validated, unverified local summaries; Story/Abyss results do not consume the outbox. There is no backend transport, account, online leaderboard UI, fetched config, or cloud save.
- Fresh reconciled-tree Web, debug-signed Android, and unsigned iPhone-targeted Xcode outputs were structurally validated with recorded hashes. No browser runtime/public deployment, release-signed AAB, Xcode compile/archive, native install, or store upload exists.
- A headless-Chrome boot smoke is configured in CI, but no successful remote run, touch-gameplay browser automation or physical-device test is claimed.
- Development icon/brand exports, five real-runtime stills, a 1080×1920 audio-complete social trailer, an 886×1920 audio-complete Apple-format technical candidate/poster, and bilingual privacy/support drafts exist with provenance and hashes. The Apple candidate still requires supported-iPhone recapture; none of these is final legal approval, public deployment, store acceptance, or submission.
