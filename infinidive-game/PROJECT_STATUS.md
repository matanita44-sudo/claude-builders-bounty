# INFINIDIVE Project Status

**Status captured:** 2026-09-01\
**Project version:** `0.1.0`\
**Milestone truth:** playable local Godot production foundation / pre-alpha\
**Branch:** `infinidive-production`\
**Configured isolated branch-fallback URL:** `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` — not yet deployed or verified at the public URL; a CI-served Chromium boot smoke has passed

## Evidence snapshot

| Evidence | Result / state | What it proves |
|---|---|---|
| `artifacts/headless-tests.xml` | 2,508 assertions, 0 failures | The latest main local headless suite passed its defined logic checks, including 24 complete deterministic boss-victory simulations. |
| Six focused headless suites | backend 82; upgrades 120; tutorial 198; rooms 2,583; meta goals 111; audio 505; all 0 failures | Together with the main suite, seven local invocations passed 6,107 assertions. These focused results are console evidence, not included in the JUnit artifact above. |
| Headless main boot (`--quit-after 3`) | exit 0 with no emitted errors | The current boot scene parses and enters headless execution; this is not a Web/browser or rendered gameplay smoke. |
| `../../build/web/` | reconciled-tree export; `index.html` 2,618 bytes / SHA-256 `f86b5f1c0f8985d66056f47c4969f8ae8366b5fb256ebc1098900471188e4336`; PCK 423,872 / `dc782fa3546fd464a9e2cf703e00e5675ec9b28f669118159d0e112f27b26a62`; WASM 39,514,754 / `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` | Real local Godot Web evidence export passed static validation; build tooling and adaptive sources are excluded. It is separate from the checked-in preset's default `../build/web/` target and the remote artifact below, and does not itself prove browser runtime or public deployment. |
| Remote Web/Pages artifact, Actions run [33498494206](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33498494206), commit `374bdb5cb8de7f4622917a343e379ff4cfd26232` | `index.html` 2,618 bytes / SHA-256 `f86b5f1c0f8985d66056f47c4969f8ae8366b5fb256ebc1098900471188e4336`; PCK 423,872 / `b0f971a5f56accfd8eec18683978e4da556c3a582ddfad30462db7ae5685a5a1`; WASM 39,514,754 / `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` | `validate` and `web-export` passed. The CI-served Playwright/Chromium smoke returned HTTP 200, started Godot 4.7.2 with WebGL2, created a 540×960 canvas, hid the loading status, and emitted no page errors. This is browser boot automation, not touch-gameplay or public-host evidence. |
| `../../build/android/infinidive-debug.apk` | 28,903,975 bytes; SHA-256 `d04ff8f814d9affec0a63b7df55fcca94d68936c4be3733edc747fafbfa32bd7` | Reconciled-tree portrait arm64 debug APK verifies `com.matan.infinidive` `0.1.0 (1)`, min 24/target 36, exactly `android.permission.VIBRATE`, zip alignment, and Android Debug v2/v3 signing. It is not an AAB and has not been installed. |
| Remote Android debug artifact, Actions run 33498494206 | 28,862,289 bytes; SHA-256 `45f1ebc82f1bae1d1cb767456c81fcf405d25b01d5e737c96b06f95084d0ef4c` | `android-debug` passed for the recorded commit and validated package/version, min 24/target 36, arm64, exactly `android.permission.VIBRATE`, Debug v2/v3 signing, and the adaptive icon. It is not an AAB and has not been installed. |
| `../../build/ios-iphone-current/INFINIDIVE.xcodeproj` | reconciled-tree unsigned export: 47 files/~368 MB; PCK 423,968 bytes / SHA-256 `5cab15e7e9bf5a1493abddf4679644380bc4ef9e0613855fdfd8b107820213e6`; pbxproj `dbbc0f658d31f09a8ad0b020a4ef1d1f6072e422088d13c996dd0d09ee7748bb`; 411-byte `INFINIDIVE/export_options.plist` `50c3cbc7d11c6c3c37357dc14e59ef93f1c011897467a9b94bb11637a795ea7d` | Target family 1, bundle/version/iOS 15, exact RGB icons, and absence of Team/placeholder values are verified. It is uncompiled, unsigned, unarchived, uninstalled, and not a TestFlight build. |
| `assets/store/gameplay/trailer-runtime-social-17s.mp4` | 1080×1920, H.264/AAC stereo, 17.2 s; SHA-256 `3950107d8ef89abffd42fec303f96ef5931a1c4139dcc771d91c17c7fa9c7103` | A portrait social-development edit exists with project-generated audio; it is virtual-display capture, not device QA or store acceptance. |
| `assets/store/gameplay/trailer-runtime-apple-candidate-886x1920-17s.mp4` | 886×1920, H.264/AAC stereo, 17.2 s; SHA-256 `7559e8cd1a89820843cd66aa310e1d006cd390668f249ea08fd8b1587df5a1b8` | A technical-format Apple candidate exists, but it was not captured on a supported iPhone and is not submission-ready. |
| `export_presets.cfg` and Android CI path | Web, Android debug APK, separate Gradle Android AAB, and iOS presets | Both Android presets request only normal `android.permission.VIBRATE`. The CI installer extracts `android_source.zip`; an integrated debug export using `--install-android-build-template` created `android/build`. No AAB has been produced or signed. The iOS preset still lacks the owner Team ID. |
| `artifacts/soak-30m.json` | 1,800.019 s, 0 recorded failures | Linux headless structural soak passed for the process-loaded snapshot; production files changed during the run, so repeat after code freeze. |
| `artifacts/soak-current-90s.json` | 90.02 s; 1,604 cycles; 161 restarts; 161 Dive transitions; unchanged fingerprint; 0 failures | Short structural soak validates the reconciled tree without concurrent source drift; it is not a replacement for the full RC/device soak. |
| `../.github/workflows/infinidive-ci.yml` | remote run 33498494206: `validate`, `web-export`, and `android-debug` succeeded; `deploy` failed at Configure Pages | Remote build/test/export evidence exists. Deployment did not start because `Create Pages site` returned `Resource not accessible by integration`; the public URL remains undeployed and unverified. |

No emulator/simulator, physical-device, production-signed-native-build, store upload, or public-host evidence is claimed.

## Completed in code

### Foundation

- Godot 4.7 project, portrait logical viewport, GL Compatibility renderer, collision-layer naming, and boot scene.
- Source separated into data, core logic, gameplay, services, UI, tests, and Web shell.
- Web, Android, and iOS export presets; Android requests only normal `android.permission.VIBRATE` for optional haptics.
- A remote reconciled-tree Godot Web export passed static validation and CI-served Playwright/Chromium boot smoke; exported-canvas touch/gameplay, mobile browsers, and the public URL remain untested.
- Native/Web safe-area adapters are wired to the Nest and run HUD, including DisplayServer insets on iOS/Android and a CSS `env(safe-area-inset-*)` bridge on Web.
- A fresh reconciled-tree Android debug APK passed manifest, permission, alignment, and Debug v2/v3 signature checks; no AAB/install exists.
- A fresh reconciled-tree unsigned iPhone-targeted Xcode project was structurally verified with exact-size RGB icons and no Team/placeholder value; no compile, sign, archive, install, or distribution evidence exists.

### Core hook

- Exterior armor combat and automatic weapon fire.
- Readable attack telegraph state followed by projectile patterns with intended gaps/lanes.
- Breach creation and explicit Dive action.
- Choice among all remaining organs.
- Seeded interior route, generic defenders, 42 deterministic hazard contracts, and organ chamber. Runtime enforces warning windows, safe gaps, active caps, wave cleanup, and hitch-safe scheduling; presentation still collapses declared profiles to three broad geometries.
- Organ destruction disables its mapped exterior ability.
- Seeded mutation offer and return to the changed exterior.
- Three organ phases and final core state exist in runtime code.

### Current content inventory

- 4 boss definitions, each with 3 organs.
- 5 weapon definitions.
- 24 mutation definitions.
- 18 permanent upgrade definitions.
- 30 non-chamber room definitions.
- 12 organ chamber definitions.
- 5 Nest visual stages and 6 facilities.

These inventory counts pass validation. Mutation and permanent-effect keys have explicit runtime contracts, but room/boss presentation does not yet match every description; see `KNOWN_ISSUES.md`.

### Meta systems

- Bio-Matter and Core Shards.
- Forge purchase UI and Hangar selection/unlock UI.
- Boss and weapon progression on Story wins.
- Local Story, Daily, Friend, and early Abyss flows.
- Settings persistence plus matching, non-empty English/Hebrew interface keys, translated launch catalogs, and headless-tested representative RTL UI.
- Procedural SFX, three-layer adaptive music across nine states, four wired boss tonal identities, rate-limited live armor/organ/phase cues, and optional haptics.
- Save schema 6 with checksum, temporary save, backup rotation, migrations, recovery, and processed-run deduplication.
- Ten-step event-driven tutorial with persisted comprehension state, real no-hit/no-Dash telegraph-avoidance observation, replay-on-next-run presentation that survives the Run-to-Nest Forge handoff, and full-mask legacy-completion migration.
- Eighteen-key permanent-upgrade runtime contract, Forge prerequisites, and focused behavior tests.
- Fourteen local achievements and nineteen rotating local contracts with basic Nest presentation, deterministic UTC rollover, exact-once rewards, a bounded SHA-256 receipt ledger, migration, and fail-closed receipt saturation.
- Reset Progress confirmation in Settings. It replaces the profile and recovery backup with clean defaults and idempotently clears the analytics queue plus Daily/Friend leaderboard primary, backup, and temporary files.
- Opt-in offline analytics abstraction with the required event-name catalog.
- Fail-closed local feature configuration and a validated, checksummed offline leaderboard outbox. Completed Daily/Friend runs queue unverified summaries under canonical challenge IDs; Story/Abyss calls are accepted as local-only and do not consume the outbox. No network transport, account, server validation, or online leaderboard UI is connected.
- Implementation-aligned privacy data map, bilingual store-metadata draft, and static bilingual privacy/support page drafts.
- Bilingual pre-release Terms draft and Godot MIT/open-source notice; neither is public or legally/final-binary approved.
- Original vector brand sources and raster exports for the icon, wordmark, feature graphic, and social card, plus original Android adaptive background/foreground/monochrome SVG layers with recorded hashes.
- Verified store rasters: 1024×1024 RGB app icon, 512×512 RGBA Google Play icon, and 1024×500 RGB/no-alpha Google feature graphic.
- Five 1080×1920 direct runtime stills, a retained 44.4-second continuous capture, a 17.2-second 1080×1920 H.264/AAC social trailer, and an 886×1920 H.264/AAC Apple-format technical candidate with capture provenance and hashes. These are virtual-display development evidence; the Apple candidate requires supported-iPhone recapture and none proves store acceptance.

### Automated coverage

- Data integrity and release-count checks.
- All six organ orders for each boss, including idempotent organ destruction.
- Friend Rift round-trip, malformed-input rejection, and deterministic fuzz coverage.
- Deterministic Daily seed.
- Deterministic, duplicate-free mutation offers plus mutation/weapon runtime-effect checks.
- Deterministic safe room route.
- High-speed projectile segment collision and pool return.
- 30/60 Hz movement consistency, dash invulnerability/recharge, shields, and exact post-dash damage.
- Primary-save corruption recovery, schema migration including legacy full tutorial completion, reward banking, durable run-ID deduplication, complete local reset cleanup, and reload.
- Localization table/content coverage, RTL widget behavior, settings keys, analytics opt-out, project configuration, and safe-area math.
- First exterior -> breach -> organ selection -> interior -> organ destruction -> mutation -> changed exterior hook.
- Twenty-four deterministic complete victories: four bosses × six organ orders, final core collapse, rewards, exact-once banking, unlock progression, and final Nest stage.
- Focused coverage for all 18 permanent effects/prerequisites, ten-step tutorial state and cross-scene replay, real telegraph-avoidance qualification, all 42 room contracts and their runtime playback invariants, canonical challenge-separated offline outbox behavior, 14 achievements, 19 contracts, migration, exact-once meta rewards, and adaptive-audio contracts/live cue throttling.
- A 30-minute headless soak for its loaded snapshot plus a current-tree 90.02-second fingerprint-stable soak with 1,604 cycles, 161 restarts/Dives, and zero failures.

## In progress / incomplete

- Permanent-upgrade and mutation balance/product validation. Rift Dividend is retained only for winning Daily/Friend Bio-Matter (losses are not multiplied), and phase-opening timing no longer advances during the intro; neither change has human balance evidence.
- Meaningfully distinct authored room presentation rather than three broad runtime geometries and one generic defender. Timing, safe-gap, active-cap, and cleanup invariants are executed, but named pattern/movement identities and human reachability remain incomplete.
- Boss-specific organ-loss replacement behaviors and transitions. Four audio identities are wired, but their mix and distinction have not been heard on browsers/devices.
- Gated/situational coaching, human comprehension, and measured onboarding timing. Live Dash and no-hit/no-Dash telegraph-avoidance paths plus cross-scene replay continuity are automated.
- Device/browser validation of the safe-area implementation and conversion of remaining fixed-coordinate layouts into genuinely adaptive UI.
- Browser/simulator/device validation of Hebrew/RTL text fit, visual ordering, and live language switching.
- Complete reduced-motion/damage-flash enforcement and accessibility/device validation; projectile, telegraph, dash-window, and aim-assist controls are exposed and consumed.
- Automated combined UI failure/retry/Forge/relaunch and repeated Abyss-depth smoke tests.
- Balance simulation, code-frozen soak rerun, allocation profiling, and real-device performance validation.
- Graphical result card and highlight capture/export.
- Public deployment and final legal/product review of privacy/support/store metadata.
- Final store-media package: original brand art and truthful gameplay captures need additional RC scenes, Apple 6.9-inch stills, supported-iPhone App Preview recapture, final mix/listening review, and console upload validation. The social trailer and Apple technical candidate already contain project-generated stereo audio.

## Blocked or unavailable in current evidence

| Item | Blocker/current truth |
|---|---|
| Dedicated `matanita44-sudo/infinidive` repository | It did not exist at the latest authenticated audit. The current work is on `infinidive-production` in the existing repository. |
| Public playable URL | `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` is the configured isolated branch fallback. Actions run 33498494206 passed the Web build and CI-served browser boot smoke, but deployment failed at Configure Pages because `Create Pages site` returned `Resource not accessible by integration`. The URL is not deployed or publicly verified. |
| Android Play testing build | The current reconciled-tree debug APK is structurally verified but not installed. A separate Gradle/AAB preset exists, and a clean combined export proves `android_source.zip` plus `--install-android-build-template` creates `android/build`; no AAB was produced because Gradle dependencies still need to resolve in a complete SDK/build-tools 36 environment and release signing requires the owner's private upload/release keystore. |
| iOS testing build | The current reconciled-tree unsigned Xcode export has verified structure/icons/target family but no Team value. Archive/sign/TestFlight require macOS/Xcode, the owner's Team ID, certificate, and provisioning profile. No compile, simulator run, archive, install, or upload occurred. |
| Online Daily/Friend/Abyss leaderboards | Only completed Daily/Friend challenges populate the validated local outbox, separated by canonical challenge ID; Story/Abyss calls remain local-only. A local target-result panel exists, but no account, backend, credential, transport, server validation, online ranking call site, or competitive UI is connected. Current modes remain local/offline. |
| Cloud save / remote configuration | Cloud save and remote fetching are absent. A bundled local configuration snapshot exists and fails closed with every online/monetization feature disabled. |
| Ads / purchases | Intentionally absent and disabled; no SDK or identifiers are configured. |
| App Store / Google Play submission | Development media/drafts exist, but signed native artifacts, accounts/signing, final store-size media, privacy forms, and final QA are not complete. |
| Physical-device QA | Not performed or evidenced. |

## Quality-gate status

| Gate | Status | Evidence gap |
|---|---|---|
| Gate 1 — Control feel | Not passed | Controls and safe-area math exist, but accidental-dash rate, notch/Dynamic Island ergonomics, readability, and attributable deaths need real touch testing. |
| Gate 2 — Core hook | Logic-proven, visual QA pending | The headless suite verifies outside-inside-outside and ability disablement; browser/device presentation is unverified. |
| Gate 3 — Complete run | Partially logic-proven; not passed | Twenty-four automated victories verify all bosses/orders, final cores, rewards, and deduplication; focused upgrade effects pass. A combined UI failure/retry/purchase/relaunch flow and human play remain unverified. |
| Gate 4 — Content complete | Not passed | Required catalog counts, tutorial/meta contracts, and effect-key consumers exist, but room/boss fidelity, cosmetic system, mode polish, and human balance remain incomplete. |
| Gate 5 — Release candidate | Not passed | Fresh structural exports and a CI-served Chromium boot smoke exist, but public/mobile browser testing, signed native builds, native installs, full QA, P0/P1 closure, final store assets, published privacy/support material, and fresh-install/update evidence are absent. |
| Gate 6 — Launch ready | Not passed | No signed builds, testing-channel uploads, store submission, or final installs. |

## Known severity snapshot

- **Known P0:** none identified by the current narrow headless suite. This is not proof that no P0 exists.
- **Known P1:** generic internal-room presentation/human reachability, incomplete boss-specific organ transformations, untested tutorial comprehension, partial accessibility, unvalidated localized/fixed layouts, no browser/device validation, no backend leaderboards, incomplete store media, and no production native release artifacts.
- Detailed, actionable entries are maintained in `KNOWN_ISSUES.md`.

## Next executable work

1. Enable GitHub Pages with **Settings → Pages → Build and deployment → Source: GitHub Actions**, rerun deployment, and verify `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/`; the private CI-served Chromium boot smoke already passes.
2. Drive a combined UI failure/bank/Forge/retry/process-relaunch flow plus repeated Abyss depths, including Reset Progress confirmation/failure presentation.
3. Turn named room patterns/movement models into matching authored visuals and add player-driven reachability tests; runtime timing/gap/cap/cleanup invariants already pass.
4. Validate mutation/permanent combinations—including the victory-payout-only Rift Dividend rule—with balance simulations and human runs.
5. Measure tutorial comprehension and time to first Dive; both live defense observation paths and cross-scene replay already pass automated coverage.
6. Produce and securely sign the Android AAB, compile/archive the iOS project on macOS, and install both through internal channels.
7. Validate safe areas, Hebrew/RTL layouts, accessibility, audio mix/transitions, and touch controls on declared browsers/simulators/devices.
