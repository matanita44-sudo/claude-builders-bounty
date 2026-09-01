# INFINIDIVE Release Checklist

This checklist is evidence-based. Check an item only after the artifact or test exists. A configured preset, authored data row, or code path is not equivalent to a validated build or feature.

## 0. Source and version control

- [x] Godot project exists under `infinidive-game/`.
- [x] Project version is declared as `0.1.0`.
- [x] Source-of-truth README, architecture, status, issues, and release checklist exist.
- [x] Historical remote source is committed on `infinidive-production`; Actions run 33514397476 tested commit `8e4be78267a043072827963d6492c7964239ae94` under the prior workflow.
- [ ] The final frozen local tree, fingerprinted as production `8e9810de2615332713f86f47bf2f28f38728fb75e51ea5bfaf2d16760927d863` and tests/CI `db398ae7804cf75e6741e13380993f9425d42b3e44de8da62631f159595f1597`, is committed and pushed.
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
- [x] Automated test destroys an organ and removes its intact exterior ability; seven authored systems degrade to safer replacements and five shut down completely.
- [x] Automated test selects a mutation and returns outside with destroyed-organ state intact.
- [x] A focused suite verifies a concrete, unique `BossVisual` state for every organ on every boss; human/device readability remains separately unchecked.
- [x] Automated contracts verify all 12 post-organ mechanics against player-facing effect descriptions, including exact seven-degraded/five-disabled behavior and EN/HE feedback; human balance remains unchecked.
- [ ] Dive tunnel, organ destruction, and return transitions pass reduced-motion and interruption QA.

## 3. Gate 3 — Complete run and progression

- [x] Three armor phases and a final core state exist in runtime code.
- [x] Failure retention includes a 55 Bio-Matter floor after an 18-second failed run.
- [x] Save backup recovery is covered by an automated corruption test.
- [x] Automated smoke tests defeat all three organs and the final core for all four bosses in all six organ orders.
- [x] Automated complete-victory tests validate rewards and run-id deduplication.
- [x] Automated smoke test validates a complete death, second death, and instant-retry path through the real result controls.
- [x] Automated smoke test purchases Reinforced Hull through the Forge UI and verifies the next run starts at 110 HP.
- [x] Save survives teardown and a separate Godot process relaunch with Bio-Matter, run count, upgrade level, and both run receipts intact.
- [ ] Save survives background/force-close timing tests and a real installed-app update from a prior shipped fixture.
- [x] First failure banks the 55 Bio-Matter floor and affords the functional Reinforced Hull upgrade in the combined smoke.
- [x] Immediate retry preserves the purchased upgrade and durable reward receipts without rebanking either completed run in the combined smoke.

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
- [x] Rail Spine damages every collinear target crossed in one physics step until pierce is exhausted; the main suite verifies nearest-to-farthest order and per-hit falloff across three targets.
- [ ] Every boss has three mechanically distinct exterior phases beyond scalar changes.
- [x] Every organ has a boss-specific procedural external state and a validated mechanical loss consequence; target-device readability/balance remains unchecked.
- [ ] Every authored room safe rule corresponds to visible, playable geometry/behavior.
- [x] Every room contract enforces a full telegraph, matching safe gap, active-window cleanup, and maximum-active bound under normal and hitch playback.
- [x] Internal zones execute eight runtime categories, six movement models, 25 projectile profiles, and ten defender archetypes through the new compiled executor; human/device readability and visual fidelity remain separate open gates.
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

- [x] Latest local JUnit-style artifact reports main `2,631/0`; wall time is intentionally omitted because the artifact is regenerated on reruns.
- [x] Final frozen local matrix passes `28,410/0` across 13 suites: main 2,631; backend 82; upgrades 120; tutorial 198; mechanics 3,541; compiler 15,515; pure/live defender effects 354/212; projectile travel 685; live integration 4,131; organs 325; meta 111; audio 505. The six room suites total `24,438/0`.
- [x] Editor import and every suite pass the isolated strict wrapper with exact sentinel/count validation and zero engine `ERROR`, script-error, or parse-error lines.
- [x] Main TestRunner requires `INFINIDIVE_TEST_ISOLATED=1` and a temporary `XDG_DATA_HOME`, failing closed before it can touch an ordinary player profile.
- [x] Data integrity, all boss/organ orders, challenge-code malformed/fuzz cases, mutation/weapon runtime, localized UI, analytics contract, local reset cleanup, room safety, project/safe-area configuration, projectile collision, movement, dash/shields, save recovery/migration/banking, live telegraph avoidance, rate-limited combat cues, core hook, and complete-victory tests exist.
- [x] Paused `BREACH_OPEN` rejects Dive without replacing the pause overlay; manual resume restores the legal Dive path in regression coverage.
- [x] The current working-tree CI workflow imports, tests, exports Web/Android, browser-smoke-tests Web, and attempts Pages deployment.
- [ ] The complete current workflow passes on GitHub. Historical run 33514397476 passed its prior validate/Web/Android jobs, but deploy job 99878161111 failed at Get Pages `Not Found` / Create Pages `Resource not accessible by integration`.
- [x] Historical validate job 99877648950 passed the then-configured eight invocations for commit `8e4be782`; it is not the frozen 13-suite matrix.
- [x] Historical Web job 99877839855 passed and its CI-served Chromium smoke returned HTTP 200, Godot 4.7.2, WebGL2, canvas 540×960, hidden loading status, and no page errors; the frozen local Web export has not received a real-browser smoke.
- [x] Local complete-boss victory smoke tests pass for four bosses × six organ orders.
- [x] Combined failure, 55-Bio banking, Forge upgrade, 110-HP new run, second failure, instant retry, and separate-process relaunch smoke passes.
- [ ] A previously shipped-build update fixture, background/force-close reward timing, and repeated Abyss-depth smoke pass.
- [ ] The full gameplay path produces no repeated console errors in an actual Web run; the remote browser boot smoke itself emitted no page errors.
- [x] Malformed and deterministic-fuzz Friend Rift corpora fail closed in the main headless suite.
- [ ] Pause/backgrounding cannot avoid or duplicate damage/rewards incorrectly.
- [ ] Procedural routes pass a large seeded-layout sweep.
- [x] Recorded-path travel retires at the first arena exit even if a later point re-enters during the same hitch; a true hit before that exit remains valid.
- [x] CI inventories all 13 standalone suites plus the nested relaunch probe and soak scene; new or stale scenes fail validation.
- [x] Soak reports use a complete two-phase transaction with bound Markdown hash and cleanup completion marker. The validator recomputes current source, rejects stale/incomplete/cleanup-pending `PASS`, permits partial/early diagnostic `FAIL`, and covers open/write/verify/commit/cleanup plus truncated/mixed pairs.

## 8. Performance and resilience

- [x] Projectile pools have explicit caps and segment collision.
- [ ] Cold start is measured against the target on representative devices.
- [x] A 30-minute Linux headless structural soak completed for its loaded snapshot with zero failures and a bounded static-memory trend; repeat after code freeze for RC evidence.
- [x] Final 8.014-second pair passes: 87 cycles, 9 restarts/Dives, 6 saves, 529 queued events / 2 reloads / final 500, peak 540, 7/7, transaction `b5a5db690e1513095a2cf63f`, JSON `dbcbf0bdb4fc9e6fb763a5c344f274872cb13875696764fe118a4bf8c3901bdb`, Markdown `15cd17499c54496ad909536039a3706f46c2fc197c856aa4b9fd89feaf2f5167`.
- [x] Final 90.118-second pair passes: 1,141 cycles, 115 restarts/Dives, 58 saves, 634 queued events / 3 reloads / final 500, peak 540, 7/7, stable delta 87,560 bytes, slope 216,364.835675299 B/min, transaction `22c5717c57c6018e8189b84f`, JSON `119157a6aaf32943c30062dd2b51fe0ee1182b525b50acd0017c8f8c2150c5cf`, Markdown `30c3b34a24347a5d6267929dc1a1f37bbd3b4a2f7374d64a6b446b6e66679bea`.
- [x] Headless soak completed 3,239 repeated restarts without retained run/projectile nodes.
- [x] Headless soak completed 3,239 outside-inside-outside transitions without recorded duplicate/retained state.
- [ ] Maximum-projectile stress test passes at target frame rate.
- [x] Headless soak completed 1,620 atomic saves and 27 reload/backup checks.
- [ ] Offline/online transition test passes if networking is enabled.
- [ ] Background return is fast and stable.
- [ ] No blocking network or save operation occurs during combat.
- [x] Final current-source package names, sizes, hashes, `BUILD_EVIDENCE.md`, and `SHA256SUMS` are recorded under `../build/final-0.1.0-8e9810de/`; none is browser, native-install, production-signing, physical-device, or store evidence.

## 9. Web release

- [x] Fresh current-source Web evidence under `../build/final-0.1.0-8e9810de/web/` is complete, hashed, and passes static/local-HTTP validation; no local real-browser canvas was available.
- [x] Web ZIP `INFINIDIVE-0.1.0-prealpha-web-8e9810de.zip` is recorded in passing `SHA256SUMS` with SHA-256 `4b0ab0515d12c23e5426dd952e47eff21006dc0e066dfd52697ef46e2836bba0`.
- [x] Static Web validation passes and confirms tooling/adaptive-icon sources are excluded from the package.
- [x] Local HTTP smoke returns 200 for the frozen game root, privacy page, and support page; this is not a real-browser canvas/WebGL/touch run.
- [x] Historical remote Web output for commit `8e4be782` records HTML 2,618, PCK 440,384, and WASM 39,514,754 in Pages artifact `9803007777`; smoke artifact `9803006599` retains its Chromium evidence. These are not the frozen local files.
- [x] The historical remote Web artifact boots through CI-served HTTP in headless Chromium with no page errors; this does not cover the frozen export, touch gameplay, Safari, or the public host.
- [ ] Export is smoke-tested in desktop Safari and Chrome.
- [ ] Export is touch-tested in mobile Safari and mobile Chrome.
- [ ] Hosting sends any headers required by the exported Godot configuration.
- [ ] GitHub Pages workflow completes successfully; current deploy job 99878161111 stopped at Get Pages `Not Found` / Create Pages `Resource not accessible by integration`.
- [ ] `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` opens the current game directly, returns HTTP 200, and passes runtime smoke.
- [x] Fail-closed verification records HTTP 404 for the game, support, and privacy URLs and no canvas; no public deployment is claimed.
- [ ] Public build displays current version and a working feedback link.

## 10. Android internal test

- [x] Fresh arm64 portrait debug APK `INFINIDIVE-0.1.0-prealpha-debug-8e9810de.apk` is hashed (`d089cebf2207391634fa6b2719d9b8c0a56e654619c33b05292e47aacc78bfa6`) and passes package/min24/target36/arm64/exact-VIBRATE/alignment/Debug-v2-v3 validation.
- [x] Historical Android job 99877839931 for commit `8e4be782` passed using build-tools 36 and produced remote debug APK SHA-256 `9b981f4d0accc600ef8f869e600b16f5585533ea1fe4cf8c71a983cfbdd87172` in artifact `9802998519`; it is not the frozen local APK.
- [x] Its manifest verifies `com.matan.infinidive`, version `0.1.0 (1)`, min SDK 24, target SDK 36, and exactly normal `android.permission.VIBRATE`.
- [x] The APK passes zip alignment and v2/v3 signature verification with `CN=Android Debug`; it is not production-distributable evidence.
- [x] Both reconciled Android presets request only normal `android.permission.VIBRATE` for optional haptics; it has no runtime prompt and does not collect data.
- [x] The verified CI installer extracts `android_source.zip`, and integrated debug export with `--install-android-build-template` creates `android/build`.
- [ ] Debug APK is installed and smoke-tested on an emulator or physical Android device.
- [ ] A full Android SDK platform/build-tools 36 environment is installed and documented for the production build; the current local exporter explicitly warned that it fell back to installed build-tools 34.0.4 while targeting 36.
- [ ] Release AAB is produced; Gradle dependency resolution, complete SDK/build-tools 36, and private signing are still required.
- [x] A separate Gradle/AAB preset targets `../build/android/infinidive-release.aab` without replacing the working debug-APK preset; no AAB artifact exists yet.
- [ ] Package ID and version code/name are final.
- [ ] Signing uses protected secrets; no key is committed.
- [ ] Internal-testing upload succeeds.
- [ ] Fresh install passes on representative Android hardware.
- [ ] Upgrade from prior test version preserves save.
- [ ] Background, call interruption, audio interruption, low-battery mode, and unstable-network tests pass.

## 11. iOS TestFlight

- [x] Full iOS export was attempted and failed exactly because the Development Team is blank.
- [x] Fresh current-source iOS PCK is 625,908 bytes / `8cf2bd0732b1df958f65958cd45fee65d2387527f6a7cf08b6287dff1f3ccf83` and passes the headless main-pack probe; the owner Team ID remains required for full native export.
- [x] Unsigned iOS ZIP `INFINIDIVE-0.1.0-prealpha-ios-unsigned-8e9810de.zip` is recorded in passing `SHA256SUMS` with SHA-256 `5e3276c7d3c92a21ef154e776c290e4308424975c0af4f9eb604194537e51ede`; no compiled, signed, installable iOS build is claimed.
- [x] The assembled unsigned scaffold records unchanged pbxproj SHA-256 `dbbc0f658d31f09a8ad0b020a4ef1d1f6072e422088d13c996dd0d09ee7748bb` and 413-byte export-options plist SHA-256 `7c41fe82380ed9bede2ad63898916de5b45e85839ef5800fafb9fa595fb7d661`.
- [ ] The full current source is successfully exported as a regenerated Xcode project and compiled for iOS; the attempt failed because the preset has no Apple Development Team ID, although the current-source PCK was exported separately.
- [ ] Direct release export/archive from the checked-in blank-Team-ID preset succeeds; owner Team ID and signing configuration are still required.
- [x] The retained unsigned scaffold contains 47 files and records an approximately 368 MB directory size; this does not claim that the scaffold itself was regenerated for the current tree.
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
- [x] Exact-size RGB/no-alpha iOS icon rasters are wired in the preset and verified in the retained historical scaffold's Xcode asset catalog; frozen-source full re-export remains blocked by the Team ID.
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
