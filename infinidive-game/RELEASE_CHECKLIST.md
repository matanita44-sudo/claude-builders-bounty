# INFINIDIVE Release Checklist

This checklist is evidence-based. Check an item only after the artifact or test exists. A configured preset, authored data row, or code path is not equivalent to a validated build or feature.

## 0. Source and version control

- [x] Godot project exists under `infinidive-game/`.
- [x] Project version is declared as `0.1.0`.
- [x] Source-of-truth README, architecture, status, issues, and release checklist exist.
- [x] Production source is committed on `infinidive-production`; Actions run 33498494206 tested commit `374bdb5cb8de7f4622917a343e379ff4cfd26232`.
- [ ] Default/production branch is remotely playable and protected appropriately.
- [ ] Risky migration work has a recoverable branch/tag/checkpoint.
- [ ] Release version, changelog, and tag agree.
- [ ] No credentials, certificates, keystores, provisioning profiles, service-role keys, or store API private keys are committed.

## 1. Gate 1 — Control feel

- [x] Drag movement, smoothing, dead zone, combat bounds, and finger offset exist in code.
- [x] Dedicated button, double-tap, and flick dash input paths exist in code.
- [x] Dash invulnerability has an automated logic test.
- [x] Dash readiness is displayed as a percentage/ready state.
- [x] Native/Web safe-area inset adapters are wired to the Nest and run HUD, and inset-to-logical-coordinate math is automated.
- [ ] Touch behavior is tested on a small iPhone-sized display.
- [ ] Touch behavior is tested on a large iPhone with Dynamic Island/safe areas.
- [ ] Touch behavior is tested on representative mid-range and high-refresh Android devices.
- [ ] Accidental activation rates are measured for all dash methods.
- [ ] Player death is consistently attributable to a visible telegraph/cause during real play.
- [ ] Every attack pattern has a tested safe path at all supported aspect ratios.

## 2. Gate 2 — Core hook

- [x] Automated test damages exterior armor and opens a breach.
- [x] Automated test enters organ selection and supports all organ orders.
- [x] Automated test reaches an organ chamber through a deterministic authored route; runtime safe-path proof remains separately unchecked below.
- [x] Automated test destroys an organ and disables its linked exterior ability.
- [x] Automated test selects a mutation and returns outside with destroyed-organ state intact.
- [ ] Visual transformation is verified for every organ on every boss.
- [ ] Post-organ attack behavior matches every player-facing effect description.
- [ ] Dive tunnel, organ destruction, and return transitions pass reduced-motion and interruption QA.

## 3. Gate 3 — Complete run and progression

- [x] Three armor phases and a final core state exist in runtime code.
- [x] Failure retention includes a 55 Bio-Matter floor after an 18-second failed run.
- [x] Save backup recovery is covered by an automated corruption test.
- [x] Automated smoke tests defeat all three organs and the final core for all four bosses in all six organ orders.
- [x] Automated complete-victory tests validate rewards and run-id deduplication.
- [ ] Automated smoke test validates a complete death and instant-retry path.
- [ ] Automated smoke test purchases a permanent upgrade and verifies its effect.
- [ ] Save survives process relaunch and background/force-close timing tests.
- [ ] First failure reliably affords one functional, meaningful upgrade.
- [ ] Immediate retry preserves only intended state and cannot duplicate rewards.

## 4. Gate 4 — Content complete

### Catalog inventory

- [x] Four boss definitions exist.
- [x] Five weapon definitions exist.
- [x] At least 24 mutation definitions exist.
- [x] At least 18 permanent-upgrade definitions exist.
- [x] At least 30 non-chamber room definitions exist.
- [x] At least 12 organ chamber definitions exist.
- [x] Five visual Nest stages and six facility access points exist.

### Runtime fidelity

- [x] Every authored mutation effect key is admitted through an explicit runtime contract; representative contextual behaviors have automated tests.
- [x] All 18 permanent-upgrade effect keys and the prerequisite gate have explicit consumers and focused engine tests; competitive mode retains only Rift Dividend as a winning-run Bio-Matter modifier, not on losses.
- [x] Arc Swarm chains to its authored count/range in automated runtime coverage.
- [x] Scatter Maw uses explicit distance falloff matching its communicated range weakness.
- [x] Void/Hungry Orbital absorption and growth behavior have automated runtime coverage.
- [ ] Rail Spine damages every collinear target crossed in one physics step until pierce is exhausted.
- [ ] Every boss has three mechanically distinct exterior phases beyond scalar changes.
- [ ] Every organ has a boss-specific external visual and mechanical consequence.
- [ ] Every authored room safe rule corresponds to visible, playable geometry/behavior.
- [x] Every room contract enforces a full telegraph, matching safe gap, active-window cleanup, and maximum-active bound under normal and hitch playback.
- [ ] Internal zones use more than a generic defender and three broad live pattern geometries; 42 contracts and playback invariants alone do not satisfy this fidelity gate.
- [ ] All organ orders are balanced; none is mandatory.
- [ ] No weapon or mutation dominates successful runs based on real test data.

### Modes

- [x] Local Story Descent route exists.
- [x] Local deterministic Daily Rift generation exists.
- [x] Offline Friend Rift code creation/opening exists.
- [x] Early Abyss depth continuation exists.
- [ ] Daily reset time and standard competitive settings are displayed and verified.
- [x] Friend target score/time is compared and shown in the local post-run result UI.
- [ ] Abyss score/depth is cumulative and validated across repeated bosses.
- [ ] Optional leaderboards work with privacy-preserving identifiers and offline fallback.

## 5. Tutorial, localization, settings, and accessibility

- [x] Tutorial advances drag through an observed movement event.
- [x] Tutorial advances auto-fire through the first live shot event.
- [x] Tutorial defense observation advances through either a live Dash or a real telegraphed volley that ends without hit or Dash.
- [ ] Human testing confirms that the defense prompt teaches the intended Dash method and safe-path concept.
- [x] Tutorial observes breach/Dive, organ destruction, mutation choice, and changed exterior behavior.
- [x] Tutorial completion requires all ten observed event bits, including Forge; Forge alone cannot complete it.
- [x] Settings exposes replay-on-next-run without erasing understood-step history.
- [x] A full replay persists through return to the Nest and completes on the final Forge step in automated UI-level coverage.
- [x] English/Hebrew interface-key parity, non-empty values, and all launch-catalog translations pass the headless localization contract.
- [x] Representative Nest/run overlays apply Hebrew RTL direction and alignment in headless UI tests.
- [ ] Full RTL visual order, live language switching, and text fit are verified on target browsers/simulators/devices.
- [ ] Text expansion and clipping pass on small portrait screens.
- [x] Master, music, and SFX volume are persisted and applied.
- [x] Haptics, screen shake, projectile contrast, sensitivity, dash method, and handedness have UI controls.
- [ ] Reduced Motion affects all necessary transitions/effects.
- [ ] Damage-flash intensity is applied.
- [x] Assist projectile speed, telegraph duration, and dash-window controls are exposed and applied in combat code and covered by focused/headless checks.
- [x] Aim-assist setting changes target-selection behavior in combat code.
- [x] Analytics preference is exposed in Settings, defaults off, and controls only the local offline queue in the reviewed build.
- [x] Reset Progress has a bilingual confirmation/cancel flow in Settings.
- [ ] No critical information is conveyed only through color.

## 6. Save, analytics, privacy, and online safety

- [x] Save schema number exists.
- [x] Primary checksum validation exists.
- [x] Temporary-file promotion and backup rotation exist.
- [x] Corrupt-primary recovery from backup has automated evidence.
- [x] Run IDs are retained for local duplicate-reward defense.
- [x] Schema-1-to-current migration, nested defaults, reward banking, durable run-ID deduplication, and in-process save reload have automated coverage.
- [x] Automated migration fixtures preserve supported schema data, and legacy `tutorial_complete=true` maps to `TutorialFlow.FULL_MASK` while replay presentation remains separate.
- [ ] Force-close/background reward-duplication tests pass.
- [ ] Update from a previously shipped build is tested.
- [x] Intentional reset confirmation and service orchestration have automated coverage; human interaction and forced storage-failure presentation remain untested.
- [x] Reset Progress replaces the primary profile and recovery backup with clean defaults; corruption cannot resurrect the pre-reset profile.
- [x] Reset Progress idempotently erases the analytics queue and Daily/Friend leaderboard primary, backup, and temporary files.
- [ ] Reset failure messaging is human-tested under forced profile/queue I/O failures.
- [x] Analytics calls use an allowlisted abstraction rather than a vendor SDK scattered through gameplay.
- [x] Analytics defaults to opt-out and remains offline in current code.
- [x] A privacy data map matches the reviewed `0.1.0` working tree; final signed-binary review is still required.
- [x] Static bilingual privacy and support page drafts exist in `web_pages/`.
- [x] `OPEN_SOURCE_NOTICES.md` records the Godot MIT runtime notice and the no-third-party-creative-asset boundary; final-binary notice audit remains required.
- [x] A bilingual pre-release Terms draft exists in `TERMS.md`; it is not legally approved or public.
- [x] A bounded, checksummed offline leaderboard outbox validates canonical Daily/Friend summaries, separates challenge IDs, rejects duplicates, fails closed with no transport, and is called after every completed run; Story/Abyss calls do not consume it.
- [ ] Privacy policy, support page, terms/open-source notices, and asset-license ledger are public.
- [ ] If backend is enabled: anonymous identity, RLS, rate limiting, validation, moderation, and offline queue pass security review.
- [ ] No service-role key or private credential exists in the client.
- [ ] Score submissions cannot be trivially forged for competitive boards.

## 7. Automated QA and CI

- [x] Latest local JUnit-style artifact reports 2,508 assertions and 0 failures; wall time is intentionally omitted because the artifact is regenerated on reruns.
- [x] Six focused local suites pass: backend 82, permanent upgrades 120, tutorial 198, room mechanics 2,583, meta goals 111, and audio 505; seven invocations total 6,107 assertions and 0 failures.
- [x] Data integrity, all boss/organ orders, challenge-code malformed/fuzz cases, mutation/weapon runtime, localized UI, analytics contract, local reset cleanup, room safety, project/safe-area configuration, projectile collision, movement, dash/shields, save recovery/migration/banking, live telegraph avoidance, rate-limited combat cues, core hook, and complete-victory tests exist.
- [x] A committed CI workflow imports, tests, exports Web/Android, browser-smoke-tests Web, and attempts Pages deployment.
- [ ] The complete CI workflow passes on GitHub. In run 33498494206, `validate`, `web-export`, and `android-debug` succeeded; `deploy` failed only at Configure Pages because `Create Pages site` returned `Resource not accessible by integration`.
- [x] Remote Actions run 33498494206 passed the mutation main suite plus focused permanent-upgrade, tutorial, room, backend, meta, and audio suites for commit `374bdb5cb8de7f4622917a343e379ff4cfd26232`.
- [x] The CI-served Playwright/Chromium boot smoke returned HTTP 200, started Godot 4.7.2 with WebGL2, created a 540×960 canvas, hid the loading status, and emitted no page errors.
- [x] Local complete-boss victory smoke tests pass for four bosses × six organ orders.
- [ ] Failure, reward, upgrade, retry, relaunch, and full-save migration smoke tests pass.
- [ ] The full gameplay path produces no repeated console errors in an actual Web run; the remote browser boot smoke itself emitted no page errors.
- [x] Malformed and deterministic-fuzz Friend Rift corpora fail closed in the main headless suite.
- [ ] Pause/backgrounding cannot avoid or duplicate damage/rewards incorrectly.
- [ ] Procedural routes pass a large seeded-layout sweep.

## 8. Performance and resilience

- [x] Projectile pools have explicit caps and segment collision.
- [ ] Cold start is measured against the target on representative devices.
- [x] A 30-minute Linux headless structural soak completed for its loaded snapshot with zero failures and a bounded static-memory trend; repeat after code freeze for RC evidence.
- [x] A current-tree 90.02-second source-locked soak completed 1,604 cycles, 161 restarts, and 161 Dive transitions with an unchanged fingerprint and zero failures.
- [x] Headless soak completed 3,239 repeated restarts without retained run/projectile nodes.
- [x] Headless soak completed 3,239 outside-inside-outside transitions without recorded duplicate/retained state.
- [ ] Maximum-projectile stress test passes at target frame rate.
- [x] Headless soak completed 1,620 atomic saves and 27 reload/backup checks.
- [ ] Offline/online transition test passes if networking is enabled.
- [ ] Background return is fast and stable.
- [ ] No blocking network or save operation occurs during combat.
- [ ] Final package size is recorded for Web, Android, and iOS.

## 9. Web release

- [x] A reconciled-tree Godot Web evidence export exists under `../../build/web/` with HTML, JavaScript, PCK, WASM, worklets, icons, and recorded SHA-256 hashes; the checked-in preset's default target remains `../build/web/`.
- [x] Static Web validation passes and confirms tooling/adaptive-icon sources are excluded from the package.
- [x] The remote Pages artifact for commit `374bdb5cb8de7f4622917a343e379ff4cfd26232` records HTML 2,618 bytes / `f86b5f1c0f8985d66056f47c4969f8ae8366b5fb256ebc1098900471188e4336`, PCK 423,872 bytes / `b0f971a5f56accfd8eec18683978e4da556c3a582ddfad30462db7ae5685a5a1`, and WASM 39,514,754 bytes / `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`.
- [x] The remote Web artifact boots through CI-served HTTP in headless Chromium with no page errors; this does not cover touch gameplay, Safari, or the public host.
- [ ] Export is smoke-tested in desktop Safari and Chrome.
- [ ] Export is touch-tested in mobile Safari and mobile Chrome.
- [ ] Hosting sends any headers required by the exported Godot configuration.
- [ ] GitHub Pages workflow completes successfully; run 33498494206 stopped at Configure Pages because the integration could not create the Pages site.
- [ ] `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` opens the current game directly, returns HTTP 200, and passes runtime smoke.
- [ ] Public build displays current version and a working feedback link.

## 10. Android internal test

- [x] A reconciled-tree arm64 portrait debug APK exists at `../../build/android/infinidive-debug.apk` (28,903,975 bytes; SHA-256 `d04ff8f814d9affec0a63b7df55fcca94d68936c4be3733edc747fafbfa32bd7`).
- [x] The remote CI debug APK for commit `374bdb5cb8de7f4622917a343e379ff4cfd26232` is 28,862,289 bytes (SHA-256 `45f1ebc82f1bae1d1cb767456c81fcf405d25b01d5e737c96b06f95084d0ef4c`).
- [x] Its manifest verifies `com.matan.infinidive`, version `0.1.0 (1)`, min SDK 24, target SDK 36, and exactly normal `android.permission.VIBRATE`.
- [x] The APK passes zip alignment and v2/v3 signature verification with `CN=Android Debug`; it is not production-distributable evidence.
- [x] Both reconciled Android presets request only normal `android.permission.VIBRATE` for optional haptics; it has no runtime prompt and does not collect data.
- [x] The verified CI installer extracts `android_source.zip`, and integrated debug export with `--install-android-build-template` creates `android/build`.
- [ ] Debug APK is installed and smoke-tested on an emulator or physical Android device.
- [ ] A full Android SDK platform/build-tools 36 environment is installed and documented for the production build; the current local shim falls back to build-tools 34.0.4.
- [ ] Release AAB is produced; Gradle dependency resolution, complete SDK/build-tools 36, and private signing are still required.
- [x] A separate Gradle/AAB preset targets `../build/android/infinidive-release.aab` without replacing the working debug-APK preset; no AAB artifact exists yet.
- [ ] Package ID and version code/name are final.
- [ ] Signing uses protected secrets; no key is committed.
- [ ] Internal-testing upload succeeds.
- [ ] Fresh install passes on representative Android hardware.
- [ ] Upgrade from prior test version preserves save.
- [ ] Background, call interruption, audio interruption, low-battery mode, and unstable-network tests pass.

## 11. iOS TestFlight

- [x] A reconciled-tree unsigned iPhone-targeted Xcode export is present at `../../build/ios-iphone-current/INFINIDIVE.xcodeproj` (47 files, approximately 368 MB); PCK, frameworks, plists, entitlements, and export options parse.
- [x] It verifies `TARGETED_DEVICE_FAMILY="1"`, bundle ID `com.matan.infinidive`, version `0.1.0 (1)`, minimum iOS 15.0, exact RGB/no-alpha icons, and no Team/placeholder value.
- [x] PCK, pbxproj, and export-options sizes/hashes are recorded in `PROJECT_STATUS.md`.
- [ ] Direct release export/archive from the checked-in blank-Team-ID preset succeeds; owner Team ID and signing configuration are still required.
- [x] The regenerated unsigned project contains 47 files and records an approximately 368 MB directory size; no unreferenced temporary archive is reported by the structural audit.
- [ ] Bundle ID, Apple team, capabilities, and minimum iOS version receive final owner/store approval.
- [ ] Xcode archive is produced on macOS.
- [ ] Signing/provisioning uses private protected credentials.
- [ ] Archive uploads to App Store Connect/TestFlight.
- [ ] Fresh TestFlight install passes.
- [ ] Save update, background/resume, audio interruption, Dynamic Island, and safe-area tests pass.
- [ ] Store privacy declarations match the exact final binary behavior.

## 12. Store assets and metadata

- [x] Original 1024×1024 app-icon source/raster exists; the raster is verified RGB without alpha.
- [x] Dedicated Google Play icon raster exists at 512×512, 141,587 bytes, 8-bit/color RGBA; final visual and console-upload validation remain pending.
- [x] Exact-size RGB/no-alpha iOS icon rasters are wired in the preset and verified in the reconciled-tree Xcode asset catalog.
- [ ] App icon is visually tested at small sizes and wired into the final Android asset catalog.
- [x] Five direct runtime screenshots exist at 1080×1920 with provenance and hashes.
- [ ] Final iPhone screenshots are recaptured from the RC at Apple-accepted device dimensions.
- [x] A technical 886×1920, 17.2-second H.264/AAC stereo Apple-format candidate exists with provenance and hash.
- [ ] Final 6.9-inch App Preview is recaptured from a supported iPhone at 886×1920 for 15–30 seconds with stereo audio and passes App Store Connect processing; the technical candidate is not submission-ready.
- [ ] Final Android screenshot narrative contains the planned eight real-gameplay scenes; current development set contains five.
- [x] Original Google Play feature-graphic source and verified 1024×500, 79,388-byte RGB raster with no alpha exist.
- [x] Original logo/wordmark and social-card source/raster assets exist with recorded dimensions, formats, and SHA-256 hashes.
- [x] A 17.2-second, 1080×1920, H.264/30 fps social-development trailer uses real runtime frames and a stereo AAC arrangement rendered only from shipped procedural-audio code.
- [ ] Final trailer/app preview passes target-device capture, listening/caption review, exact store format, and upload validation.
- [x] A portrait 1080×1920 social clip uses real gameplay capture; platform publication and device playback are untested.
- [x] English and Hebrew metadata drafts exist in `STORE_METADATA.md`, including current official source URLs and character/dimension constraints.
- [ ] English title, subtitle/short description, full description, keywords, captions, and release notes are final and entered in the store consoles.
- [ ] Hebrew metadata is reviewed by a fluent human and entered only after complete in-game RTL QA.
- [ ] Age-rating and privacy answers are completed truthfully.
- [x] Repository-local bilingual support/privacy pages and bilingual Terms draft exist; open-source notices are recorded.
- [ ] Support, privacy, and marketing URLs are public and correct.
- [ ] No screenshot, trailer, claim, testimonial, metric, or award is fabricated.

## 13. Final release gates

- [ ] No known P0 remains.
- [ ] No known P1 remains without an explicit owner-approved exception.
- [ ] Fresh-install test passes on Web, Android, and iOS targets.
- [ ] Update-from-previous-save test passes.
- [ ] Signed builds are available.
- [ ] TestFlight and Google Play internal testing are ready.
- [ ] Store listing and legal/support pages are complete.
- [ ] Final installed build is tested.
- [ ] Owner performs any required irreversible public-release confirmation.
- [ ] Submission to store review is completed and recorded.
