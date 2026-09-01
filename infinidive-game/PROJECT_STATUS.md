# INFINIDIVE Project Status

**Status captured:** 2026-09-01\
**Project version:** `0.1.0`\
**Milestone truth:** playable local Godot production foundation / pre-alpha\
**Branch:** `infinidive-production`\
**Configured isolated branch-fallback URL:** `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` — not yet deployed or verified at the public URL; a CI-served Chromium boot smoke has passed

## Evidence snapshot

| Evidence | Result / state | What it proves |
|---|---|---|
| `artifacts/headless-tests.xml` | 2,538 assertions, 0 failures | The latest isolated main local headless suite passed its defined logic checks, including 24 complete deterministic boss-victory simulations and the combined failure/progression/relaunch flow. |
| Seven focused headless suites | backend 82; upgrades 120; tutorial 198; rooms 2,583; meta goals 111; audio 505; organ transformations 325; all 0 failures | Together with the main suite, eight local invocations passed 6,462 assertions. These focused results are console evidence, not included in the JUnit artifact above. |
| Headless main boot (`--quit-after 3`) | exit 0 with no emitted errors | The current boot scene parses and enters headless execution; this is not a Web/browser or rendered gameplay smoke. |
| `../../build/web/` | local commit-candidate export: HTML 2,618 bytes / SHA-256 `190b5852ff3c94b4d2e6ce2849bdbc92cb64e77c6cb972d35165b9cf544713b5`; PCK 440,384 / `f9acf67d893ab6513f2b7fde450fcd2129331ba8252b3464132d94892b85b9d4`; WASM 39,514,754 / `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` | Real local Godot Web export of commit `8e4be78267a043072827963d6492c7964239ae94` passed static validation; build tooling and adaptive sources are excluded. These hashes identify the local artifact only. |
| Remote Web/Pages artifacts, Actions run [33514397476](https://github.com/matanita44-sudo/claude-builders-bounty/actions/runs/33514397476), commit `8e4be78267a043072827963d6492c7964239ae94` | job `99877839855` PASS; HTML 2,618 bytes; PCK 440,384; WASM 39,514,754; Pages artifact `9803007777`; browser-smoke artifact `9803006599` | CI-served Chromium returned HTTP 200, started Godot 4.7.2 with WebGL2, created a 540×960 canvas, hid the loading status, and emitted no page errors. Matching sizes do not imply the local hashes above are remote hashes. This is current-commit browser boot automation, not touch-gameplay or public-host evidence. |
| `../../build/android/infinidive-debug.apk` | current-working-tree debug export: 28,878,673 bytes; SHA-256 `2d3d5fa6f283381fd31aa1702df2cc697c80f12d0d7a96e6c1e22b59c33cdcef`; validator PASS | Portrait arm64 debug APK verifies `com.matan.infinidive` `0.1.0 (1)`, min 24/target 36, exactly `android.permission.VIBRATE`, zip alignment, and Android Debug v2/v3 signing. The local exporter warned that it fell back to installed build-tools 34.0.4 while targeting 36. It is not an AAB and has not been installed. |
| Remote Android debug artifact, Actions run 33514397476 | job `99877839931` PASS using build-tools 36; SHA-256 `9b981f4d0accc600ef8f869e600b16f5585533ea1fe4cf8c71a983cfbdd87172`; artifact `9802998519` | Current-commit CI export passed its Android validation. It is a debug APK, not an AAB, and has not been installed. Its hash is intentionally distinct from the local build's hash. |
| `../../build/ios-iphone-current/INFINIDIVE.xcodeproj` | retained earlier 47-file scaffold with current-tree `--export-pack` payload: PCK 440,480 bytes / SHA-256 `ac426ba74dd8993ea129448d2258d4f1b36ea3ee2fd48c28fd342bda53401db6`; unchanged pbxproj `dbbc0f658d31f09a8ad0b020a4ef1d1f6072e422088d13c996dd0d09ee7748bb`; 411-byte plist `50c3cbc7d11c6c3c37357dc14e59ef93f1c011897467a9b94bb11637a795ea7d` | Full current-tree iOS re-export failed because no Development Team is configured. Only the PCK payload was refreshed; the scaffold/configuration was not regenerated. It remains uncompiled, unsigned, unarchived, simulator-unrun, uninstalled, and absent from TestFlight. |
| `assets/store/gameplay/trailer-runtime-social-17s.mp4` | 1080×1920, H.264/AAC stereo, 17.2 s; SHA-256 `3950107d8ef89abffd42fec303f96ef5931a1c4139dcc771d91c17c7fa9c7103` | A portrait social-development edit exists with project-generated audio; it is virtual-display capture, not device QA or store acceptance. |
| `assets/store/gameplay/trailer-runtime-apple-candidate-886x1920-17s.mp4` | 886×1920, H.264/AAC stereo, 17.2 s; SHA-256 `7559e8cd1a89820843cd66aa310e1d006cd390668f249ea08fd8b1587df5a1b8` | A technical-format Apple candidate exists, but it was not captured on a supported iPhone and is not submission-ready. |
| `export_presets.cfg` and Android CI path | Web, Android debug APK, separate Gradle Android AAB, and iOS presets | Both Android presets request only normal `android.permission.VIBRATE`. The CI installer extracts `android_source.zip`; an integrated debug export using `--install-android-build-template` created `android/build`. No AAB has been produced or signed. The iOS preset still lacks the owner Team ID. |
| `artifacts/soak-30m.json` | 1,800.019 s, 0 recorded failures | Linux headless structural soak passed for the process-loaded snapshot; production files changed during the run, so repeat after code freeze. |
| `artifacts/soak-current-90s.json` | 90.02 s; 1,563 iterations/projectile cycles; 157 restarts; 157 Dive transitions; 78 save writes; 676 offline events; peak 540 projectiles; unchanged fingerprint; 0 failures | Short structural soak validates the current tree without concurrent source drift; it is not a replacement for the full RC/device soak. |
| `../.github/workflows/infinidive-ci.yml` | run 33514397476 on commit `8e4be782`: validate `99877648950`, Web `99877839855`, and Android `99877839931` PASS; deploy `99878161111` FAIL | All eight suites plus current-commit Web/Chromium and Android debug exports passed remotely. Deploy failed exactly at Get Pages `Not Found` / Create Pages `Resource not accessible by integration`; direct game/support/privacy checks remain HTTP 404 with no canvas. |

No emulator/simulator, physical-device, production-signed-native-build, store upload, or public-host evidence is claimed.

## Completed in code

### Foundation

- Godot 4.7 project, portrait logical viewport, GL Compatibility renderer, collision-layer naming, and boot scene.
- Source separated into data, core logic, gameplay, services, UI, tests, and Web shell.
- Web, Android, and iOS export presets; Android requests only normal `android.permission.VIBRATE` for optional haptics.
- The current commit passes both local Web static validation and remote Web export/CI-served Chromium boot smoke; exported-canvas touch/gameplay, mobile browsers, and the public URL remain untested.
- Native/Web safe-area adapters are wired to the Nest and run HUD, including DisplayServer insets on iOS/Android and a CSS `env(safe-area-inset-*)` bridge on Web.
- A current-working-tree Android debug APK passed manifest, permission, alignment, and Debug v2/v3 signature checks with recorded size/hash. The local exporter warned of build-tools 34.0.4 fallback while targeting 36; no AAB/install exists.
- Full current-tree iOS re-export failed at the blank Development Team gate. `--export-pack iOS` refreshed the current-tree PCK inside the retained earlier 47-file scaffold, but did not regenerate the Xcode project; no compile, sign, archive, simulator run, install, or distribution evidence exists.

### Core hook

- Exterior armor combat and automatic weapon fire.
- Readable attack telegraph state followed by projectile patterns with intended gaps/lanes.
- Breach creation and explicit Dive action.
- Choice among all remaining organs.
- Seeded interior route, generic defenders, 42 deterministic hazard contracts, and organ chamber. Runtime enforces warning windows, safe gaps, active caps, wave cleanup, and hitch-safe scheduling; presentation still collapses declared profiles to three broad geometries.
- Organ destruction removes its intact exterior ability. Seven authored systems remain in the pool as safer, explicitly described replacement patterns; five shut down completely. All 12 losses publish unique exterior visual states and localized changed/disabled feedback.
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
- A combined player-facing progression smoke dies through the result UI, banks the 55 Bio-Matter failure floor, returns to the Nest, purchases Reinforced Hull in the Forge, starts a 110-HP run, dies a second time, presses instant retry, and verifies Bio-Matter, run count, upgrade, and run receipts from a separate Godot process.
- Twelve validated organ-loss contracts: seven degraded attack replacements, five complete shutdowns, 12 unique mechanical variants, 12 unique `BossVisual` states, exact safe-path/telegraph contracts, and English/Hebrew change messages. The dedicated focused suite passes 325 assertions.
- Focused coverage for all 18 permanent effects/prerequisites, ten-step tutorial state and cross-scene replay, real telegraph-avoidance qualification, all 42 room contracts and their runtime playback invariants, canonical challenge-separated offline outbox behavior, 14 achievements, 19 contracts, migration, exact-once meta rewards, and adaptive-audio contracts/live cue throttling.
- A 30-minute headless soak for its loaded snapshot plus a current-tree 90.02-second fingerprint-stable soak with 1,563 cycles, 157 restarts/Dives, 78 save writes, 676 offline events, a 540-projectile peak, and zero failures.

## In progress / incomplete

- Permanent-upgrade and mutation balance/product validation. Rift Dividend is retained only for winning Daily/Friend Bio-Matter (losses are not multiplied), and phase-opening timing no longer advances during the intro; neither change has human balance evidence.
- Meaningfully distinct authored room presentation rather than three broad runtime geometries and one generic defender. Timing, safe-gap, active-cap, and cleanup invariants are executed, but named pattern/movement identities and human reachability remain incomplete.
- Human visual/readability/balance review of the implemented boss-specific organ-loss replacements and transitions. Four audio identities are wired, but their mix and distinction have not been heard on browsers/devices.
- Gated/situational coaching, human comprehension, and measured onboarding timing. Live Dash and no-hit/no-Dash telegraph-avoidance paths plus cross-scene replay continuity are automated.
- Device/browser validation of the safe-area implementation and conversion of remaining fixed-coordinate layouts into genuinely adaptive UI.
- Browser/simulator/device validation of Hebrew/RTL text fit, visual ordering, and live language switching.
- Complete reduced-motion/damage-flash enforcement and accessibility/device validation; projectile, telegraph, dash-window, and aim-assist controls are exposed and consumed.
- Previously shipped-build update fixtures, background/force-close timing, and repeated Abyss-depth smoke tests. The combined UI failure/bank/Forge/retry/separate-process relaunch flow now passes.
- Balance simulation, a full 30-minute code-frozen soak rerun, allocation profiling, and real-device performance validation.
- Graphical result card and highlight capture/export.
- Public deployment and final legal/product review of privacy/support/store metadata.
- Final store-media package: original brand art and truthful gameplay captures need additional RC scenes, Apple 6.9-inch stills, supported-iPhone App Preview recapture, final mix/listening review, and console upload validation. The social trailer and Apple technical candidate already contain project-generated stereo audio.

## Blocked or unavailable in current evidence

| Item | Blocker/current truth |
|---|---|
| Dedicated `matanita44-sudo/infinidive` repository | It did not exist at the latest authenticated audit. The current work is on `infinidive-production` in the existing repository. |
| Public playable URL | `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` is the configured isolated branch fallback. Current-commit run 33514397476 passed Web build and CI-served Chromium boot smoke, but deploy job 99878161111 failed at Get Pages `Not Found` / Create Pages `Resource not accessible by integration`. Direct verification returns HTTP 404 for the game, support, and privacy URLs and finds no canvas. |
| Android Play testing build | The current-working-tree debug APK is structurally verified with recorded size/hash but not installed; local export used the available build-tools 34.0.4 fallback while targeting 36. A separate Gradle/AAB preset exists, and a clean combined export proves `android_source.zip` plus `--install-android-build-template` creates `android/build`; no AAB was produced because release evidence still needs complete build-tools 36 plus the owner's private upload/release keystore. |
| iOS testing build | Full current-tree project re-export failed because the Development Team is blank. A current-tree PCK was refreshed with `--export-pack iOS` inside the retained earlier scaffold; this is not a full current Xcode export. Archive/sign/TestFlight require macOS/Xcode, the owner's Team ID, certificate, and provisioning profile. No compile, simulator run, archive, install, or upload occurred. |
| Online Daily/Friend/Abyss leaderboards | Only completed Daily/Friend challenges populate the validated local outbox, separated by canonical challenge ID; Story/Abyss calls remain local-only. A local target-result panel exists, but no account, backend, credential, transport, server validation, online ranking call site, or competitive UI is connected. Current modes remain local/offline. |
| Cloud save / remote configuration | Cloud save and remote fetching are absent. A bundled local configuration snapshot exists and fails closed with every online/monetization feature disabled. |
| Ads / purchases | Intentionally absent and disabled; no SDK or identifiers are configured. |
| App Store / Google Play submission | Development media/drafts exist, but signed native artifacts, accounts/signing, final store-size media, privacy forms, and final QA are not complete. |
| Physical-device QA | Not performed or evidenced. |

## Quality-gate status

| Gate | Status | Evidence gap |
|---|---|---|
| Gate 1 — Control feel | Not passed | Controls and safe-area math exist, but accidental-dash rate, notch/Dynamic Island ergonomics, readability, and attributable deaths need real touch testing. |
| Gate 2 — Core hook | Logic-proven, visual QA pending | Headless suites verify outside-inside-outside plus all 12 data-driven organ consequences: seven safer replacement patterns, five shutdowns, and unique procedural exterior states. Browser/device presentation and human readability remain unverified. |
| Gate 3 — Complete run | Stronger automated proof; not passed | Twenty-four victories verify all bosses/orders, final cores, rewards, and deduplication. A combined UI failure/bank/Forge/110-HP/retry flow and separate-process save reload also pass. Human play, background/force-close behavior, shipped-build update migration, and repeated Abyss depths remain unverified. |
| Gate 4 — Content complete | Not passed | Required catalog counts, tutorial/meta contracts, and effect-key consumers exist, but room/boss fidelity, cosmetic system, mode polish, and human balance remain incomplete. |
| Gate 5 — Release candidate | Not passed | Fresh structural exports and a CI-served Chromium boot smoke exist, but public/mobile browser testing, signed native builds, native installs, full QA, P0/P1 closure, final store assets, published privacy/support material, and fresh-install/update evidence are absent. |
| Gate 6 — Launch ready | Not passed | No signed builds, testing-channel uploads, store submission, or final installs. |

## Known severity snapshot

- **Known P0:** none identified by the current narrow headless suite. This is not proof that no P0 exists.
- **Known P1:** generic internal-room presentation/human reachability, untested human readability/balance of the implemented organ transformations, untested tutorial comprehension, partial accessibility, unvalidated localized/fixed layouts, no browser/device validation, no backend leaderboards, remaining update/background/Abyss coverage, incomplete store media, and no production native release artifacts.
- Detailed, actionable entries are maintained in `KNOWN_ISSUES.md`.

## Next executable work

1. Resolve GitHub's Pages-site creation/Actions permission for this repository, rerun deploy, then verify HTTP 200 plus a live canvas at `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/`; current deploy job 99878161111 returned Get Pages `Not Found` / Create Pages `Resource not accessible by integration`, and the game/support/privacy URLs remain HTTP 404.
2. Turn named room patterns/movement models into matching authored visuals and add player-driven reachability tests; runtime timing/gap/cap/cleanup invariants already pass.
3. Exercise a previously shipped save fixture, background/force-close reward timing, and repeated Abyss depths; the combined UI failure/progression/retry/process-relaunch path now passes.
4. Validate the seven degraded/five disabled organ outcomes, mutations, permanent combinations, and the victory-payout-only Rift Dividend rule with balance simulations and human runs.
5. Measure tutorial comprehension and time to first Dive; both live defense observation paths and cross-scene replay already pass automated coverage.
6. Produce and securely sign the Android AAB, re-export/compile/archive the current iOS tree on macOS, and install both through internal channels.
7. Validate safe areas, Hebrew/RTL layouts, accessibility, audio mix/transitions, and touch controls on declared browsers/simulators/devices.
