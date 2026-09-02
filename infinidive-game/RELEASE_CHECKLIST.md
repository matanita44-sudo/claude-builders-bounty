# INFINIDIVE Release Checklist

This checklist is evidence-based. Check an item only after the artifact or test exists. A configured preset, authored data row, or code path is not equivalent to a validated build or feature.

> Bright Greek-mythic/AION commit `a550ca867506f34856cf337fbe28083a9cdbaec5` is the current deployed evidence candidate. Run `33594396541` passed all seven configured jobs. The reconstructed tree now passes local editor/import and a fresh 21-suite `40,160/0` matrix with exact sentinels and zero unexpected engine/script/parse errors; it is not yet pushed, remotely run, or deployed.

## 0. Source and version control

- [x] Godot project exists under `infinidive-game/`.
- [x] Project version is declared as `0.1.0`.
- [x] Source-of-truth README, architecture, status, issues, and release checklist exist.
- [x] Prior frozen production tree `67e2c54` is committed and pushed on `infinidive-production`; it is historical evidence, not the active candidate.
- [x] Bright presentation/story candidate tree `2c77fa2266145323b99f7a349e5283416aec2c1c` is committed and pushed as `a550ca867506f34856cf337fbe28083a9cdbaec5` on `infinidive-production`.
- [x] The deployed candidate production inventory is fingerprinted as `a0e456bc31c947cb1db2330e40b5069a323168b2b0ac1df553143bf9e9eb9a2c`; the 1,800.026-second soak preserved that value from start to finish. The production calculation deliberately excludes only local-only, untracked, non-exported capture evidence.
- [ ] The rebuilt post-`a550ca8` hardening working tree is frozen, committed, pushed, and bound to a complete remote evidence chain, including the new Xcode Simulator lane.
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
- [x] Headless suspend/close notifications synchronously preserve a completed reward plus receipt, and a fresh Godot process rejects replay of that result without changing totals.
- [ ] Save survives real installed-app background/force-close timing and update from a prior TestFlight/App Store build.
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
- [x] A checked-in schema-1 pre-alpha fixture plus malformed/legacy cases preserve supported data, add current nested defaults, and map `tutorial_complete=true` to `TutorialFlow.FULL_MASK` while replay presentation remains separate.
- [x] Headless application suspend/close callbacks persist a banked result synchronously; a fresh process rejects replay and retains exactly one reward/receipt.
- [ ] Native force-close/background reward-duplication tests pass on an installed build.
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
- [x] A bilingual pre-release Draft Terms source exists in `TERMS.md` and `web_pages/terms.html` and is included in deployed candidate `a550ca8`; it is not legally approved.
- [ ] The rebuilt bilingual public notices page is committed, deployed, link-checked, and reconciled against the exact final archive and asset-license ledger. Local source alone is not public evidence.
- [x] A bounded, checksummed offline leaderboard outbox validates canonical Daily/Friend summaries, separates challenge IDs, rejects duplicates, fails closed with no transport, and is called after every completed run; Story/Abyss calls do not consume it.
- [x] Bilingual pre-release privacy and support pages are public over HTTPS.
- [ ] Final legally reviewed Terms/open-source notices and asset-license ledger are public where required.
- [ ] If backend is enabled: anonymous identity, RLS, rate limiting, validation, moderation, and offline queue pass security review.
- [ ] No service-role key or private credential exists in the client.
- [ ] Score submissions cannot be trivially forged for competitive boards.

## 7. Automated QA and CI

- [x] Latest reconstructed local JUnit-style artifact reports main `2,860/0` with recorded time `12.994` seconds.
- [x] Deployed `a550ca8` passed remote `28,949/0`. The rebuilt local tree passes `40,160/0` across 21 suites, including focused Titan attack, organ mapping, audio, visual, localized-layout acceptance, and QA-only native-capture gate assertions. Editor/import, exact sentinels, and strict zero-error scanning pass. Remote proof remains pending.
- [x] Current local bounded soak passes at 8.003 seconds with 98 iterations, 10 restarts/Dives, 98 projectile cycles, six saves, 530 queue events, peak 540, all seven movement models, zero failures, fingerprint `3f5aed099357c66985222681d6b825819e595dbd5ef960e3566003283c37c59a`, and transaction-recovery self-test PASS.
- [x] Editor import and every suite pass the isolated strict wrapper with exact sentinel/count validation and zero engine `ERROR`, script-error, or parse-error lines.
- [x] Main TestRunner requires `INFINIDIVE_TEST_ISOLATED=1` and a temporary `XDG_DATA_HOME`, failing closed before it can touch an ordinary player profile.
- [x] Data integrity, all boss/organ orders, challenge-code malformed/fuzz cases, mutation/weapon runtime, localized UI, analytics contract, local reset cleanup, room safety, project/safe-area configuration, projectile collision, movement, dash/shields, save recovery/migration/banking, live telegraph avoidance, rate-limited combat cues, core hook, and complete-victory tests exist.
- [x] Paused `BREACH_OPEN` rejects Dive without replacing the pause overlay; manual resume restores the legal Dive path in regression coverage.
- [x] The current CI workflow imports, tests, exports Web/Android, browser-smoke-tests the Web export, deploys Pages, and includes a post-deploy public-host smoke job.
- [x] Actions run `33557365042`, attempt 2, passes overall for exact-tree commit `67e2c54`; deploy job `100024023277` also passes.
- [x] Actions run `33559947112` completes fully `PASS`; its source-bound 30-minute job is `100030992601`, and artifact `9822001845` retains the validated JSON/Markdown pair.
- [x] Prior runtime commit `380b6d4b632e9d507ea42075714d0f18d6cdb74f` passes Actions run `33565500042`, including deploy job `100049011404` and public-smoke job `100049076641`. Its optional long-soak job skipped because validation accepted the then-current `e942db6f` 30-minute pair.
- [x] Current deployed candidate remote validate job `100134794261` passes the frozen 15-suite matrix at `28,949/0` in Actions run `33594396541` for pushed commit `a550ca867506f34856cf337fbe28083a9cdbaec5`.
- [x] Current deployed Web export/CI-served whole-path and reload smoke passes in job `100135597973`; artifact `9833003906` is 4,746,140 bytes with downloaded ZIP SHA-256 `1a6a23bbb8de3896e515cdd7e6f6174115407175b8567a60a1985fa2718981ba`.
- [x] Current deployed Android debug export/structural validation passes in job `100135598026`; artifact `9832975516` is 32,672,331 bytes / `4791955d62324e399a9ab549712946a9a42a4a23b2e913f21bb9ce6b9e59d77d`. No install, AAB, private signing, or Play upload is claimed.
- [x] Current deployed unsigned iOS scaffold job `100135598028` passes; artifact `9832974829` is 105,809,413 bytes / `ab43770f803d7000859405c50fb99939019dcd942bdfd4291af802b6a62b0943`. No Xcode compilation, archive, signing, Simulator/device install, or TestFlight upload is claimed.
- [x] Current deployed 30-minute structural soak passes in job `100135598119`; artifact `9833647628` records 1,800.026 seconds, 25,109 cycles, 2,511 restarts/Dives, stable production fingerprint `a0e456bc31c947cb1db2330e40b5069a323168b2b0ac1df553143bf9e9eb9a2c`, zero failures, and zero orphan nodes. Downloaded ZIP SHA-256 is `4607d9dfb3e5c0fdb53dd2666a10922fd6b90a7ace18ef6db0236a15ef8ac245`.
- [x] Deploy job `100141614551` and public-smoke job `100141657457` pass. Public artifact `9833689840` is 4,752,918 bytes / SHA-256 `b5c2034b1398f852846c476f18c49d758c9fc17836607e06983eeb745a1d7f58`, and its deployment marker matches `a550ca867506f34856cf337fbe28083a9cdbaec5`.
- [x] Historical candidate Web, Android, endurance, deployment, and movement/Dash-only public evidence from run `33572931398` remains retained under artifacts `9825704303`, `9826413723`, and `9826433759`; it is superseded by the `a550ca8` evidence above and is not the active candidate.
- [x] Historical Android debug export and structural validation also pass in Actions run `33557365042`, attempt 2; this is retained as prior-source evidence only.
- [x] The commit-bound public-host synthetic canvas automation passes in Actions run `33565500042`: HTTP 200, 540×960 canvas, zero page errors, and `3/3/3` canvas `touchstart` / `touchmove` / `touchend` events. Before SHA-256 `31212c7891fccbb64e3993062614178a854ac29b185878ee1a5db2963ccf2e23` differs from after SHA-256 `94e6d2654a466e0ecb37670e6621d2b873eb5c9c56c39a5565ea2f38afa0b6d8`, proving rendered change. Artifact `9823113363` is 90,667 bytes / `5038d055d8cf723b479424b4d099d0e3c036bb4e9eb325cb9c1ee6e00b750985`. This proves synthetic delivery and rendering only, not semantic gameplay state, mobile Safari/Chrome, or physical touch feel.
- [x] Local complete-boss victory smoke tests pass for four bosses × six organ orders.
- [x] Combined failure, 55-Bio banking, Forge upgrade, 110-HP new run, second failure, instant retry, and separate-process relaunch smoke passes.
- [x] Five consecutive headless Abyss win/continue cycles preserve carried build state, bounded repair, deterministic boss/seed progression, scaling, and exact-once reward receipts.
- [ ] A prior installed-build update and native background/force-close reward timing pass on iPhone/Android.
- [x] CI-served and deployed-public Web for commit `a550ca8` traverses exterior → breach → organ choice → Dive → chamber → organ destruction → mutation → Dive out → changed exterior, then reloads the same context and restores the exact persisted state with zero page/crash/request failures. Public artifact `9833689840` binds the result to that commit.
- [x] Malformed and deterministic-fuzz Friend Rift corpora fail closed in the main headless suite.
- [x] Headless simulated pause/close reward writes remain exact-once across a fresh process, including a retryable injected storage failure.
- [ ] Native pause/backgrounding cannot avoid damage or duplicate rewards on installed iOS/Android builds.
- [ ] Procedural routes pass a large seeded-layout sweep.
- [x] Recorded-path travel retires at the first arena exit even if a later point re-enters during the same hitch; a true hit before that exit remains valid.
- [x] CI inventory validates 21 scenes: 19 standalone suites, one nested relaunch probe, zero imported probes, and one soak scene; new or stale scenes fail validation.
- [x] Soak reports use a complete two-phase transaction with bound Markdown hash and cleanup completion marker. The validator recomputes current source, rejects stale/incomplete/cleanup-pending `PASS`, permits partial/early diagnostic `FAIL`, and covers open/write/verify/commit/cleanup plus truncated/mixed pairs.

## 8. Performance and resilience

- [x] Projectile pools have explicit caps and segment collision.
- [ ] Cold start is measured against the target on representative devices.
- [x] Current deployed-candidate 30-minute Linux headless structural soak passes for production fingerprint `a0e456bc31c947cb1db2330e40b5069a323168b2b0ac1df553143bf9e9eb9a2c`: run `33594396541`, job `100135598119`, artifact `9833647628`, 1,800.026 seconds, 25,109 cycles, 2,511 restarts/Dives, zero failures, and zero orphan nodes.
- [x] Historical 8.049-second pair passes: 88 cycles, 9 restarts / 9 Dives, 6 saves, 529 queued events / 2 reloads / final 500, peak 540, 7/7, transaction `994142d36b9310b4523a7b2f`. It remains comparison evidence only.
- [x] Historical 90.041-second pair passes: 1,166 cycles, 117 restarts / 117 Dives, 60 saves / 1 reload, 637 queued events / 3 queue reloads / final 500, peak 540, 7/7, transaction `98e69a9b42dd1314f6a16cb9`. It remains comparison evidence only.
- [x] Historical short `1db2d97a…` pairs complete their two-phase transactions, execute 7/7 travel models, and report zero failures; they remain retained comparison evidence, not the active candidate.
- [x] The current deployed-candidate 30-minute soak completed 2,511 repeated restarts/Dives with zero recorded failures or orphan nodes; this is Linux headless structural evidence, not physical-device performance or human-play evidence.
- [ ] Maximum-projectile stress test passes at target frame rate.
- [x] Historical soak evidence completed 1,353 atomic saves and 22 reload/backup checks, plus 3,224 offline events / 24 queue reloads / final queue 500. These exact counts are not relabelled as current `a550ca8` proof.
- [ ] Offline/online transition test passes if networking is enabled.
- [ ] Background return is fast and stable.
- [ ] No blocking network or save operation occurs during combat.
- [x] Historical pre-pivot package names, sizes, hashes, `BUILD_EVIDENCE.md`, and `SHA256SUMS` remain recorded under `../../build/semantic-qa-1db2d97a/`. They are not active-candidate install, signing, device, or store evidence.
- [x] Historical `e942db6f` canonical-package evidence remains recorded under `../build/final-0.1.0-e942db6f/`; it is prior-source evidence and is not substituted for the current candidate.

## 9. Web release

- [x] Historical pre-pivot Web package `../../build/semantic-qa-1db2d97a/INFINIDIVE-0.1.0-prealpha-web-1db2d97a.zip` is retained with its passing archive/static/local-HTTP validation; current `a550ca8` Web evidence is in run `33594396541` and artifacts `9833003906` / `9833689840`.
- [x] The extracted file hashes under `semantic-qa-1db2d97a` are retained historical provenance; they are not labelled as current-candidate files.
- [x] Current deployed-candidate CI-served and public semantic Chromium smokes pass in Actions run `33594396541`, covering the complete outside-inside-outside path and same-context reload. This does not prove Mobile Safari/Chrome or physical touch feel.
- [x] Historical commit `73a3f4a` passed the earlier public movement/Dash contract; it is superseded by `a550ca8` full-path/reload public evidence.
- [x] Historical Web evidence under `../build/final-0.1.0-e942db6f/web/` is complete, hashed, and passes static/local-HTTP validation; no local real-browser canvas was available for that package.
- [x] Web ZIP `INFINIDIVE-0.1.0-prealpha-web-e942db6f.zip` contains the deployment-corrected bilingual privacy/support pages and is recorded in the passing `SHA256SUMS` with SHA-256 `8df771d497ce98c5807e40bf2e2f0bff9aa5bbdb74f614551668b8fd559b0001`.
- [x] Static Web validation passes and confirms tooling/adaptive-icon sources are excluded from the package.
- [x] Local HTTP smoke returns 200 for the frozen game root, privacy page, and support page; this is not a real-browser canvas/WebGL/touch run.
- [x] Actions run `33557365042`, attempt 2, exports exact-tree commit `67e2c54` and boots that output through CI-served HTTP in headless Chrome; that historical step is retained as boot evidence, while current public-host synthetic input evidence is recorded below.
- [ ] Export is smoke-tested in desktop Safari and Chrome.
- [ ] Export is touch-tested in mobile Safari and mobile Chrome.
- [ ] Hosting sends any headers required by the exported Godot configuration.
- [x] GitHub Pages deployment completes successfully for runtime commit `380b6d4b632e9d507ea42075714d0f18d6cdb74f` in job `100049011404` (Actions run `33565500042`).
- [x] GitHub Pages deployment completes successfully for current candidate `a550ca867506f34856cf337fbe28083a9cdbaec5` in job `100141614551` (Actions run `33594396541`).
- [x] `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` opened prior runtime commit `380b6d4b632e9d507ea42075714d0f18d6cdb74f` directly, returned HTTP 200, and passed the historical public-host boot plus synthetic canvas-delivery smoke in job `100049076641`; this is not current-candidate public confirmation.
- [x] The public URL carries deployment marker `a550ca867506f34856cf337fbe28083a9cdbaec5`, returns HTTP 200, and passes current-candidate public whole-path/reload smoke in job `100141657457`.
- [x] Public-smoke artifact `9823113363` retains the before/after screenshots and JSON evidence; it is 90,667 bytes with SHA-256 `5038d055d8cf723b479424b4d099d0e3c036bb4e9eb325cb9c1ee6e00b750985`.
- [x] Historical public-smoke artifact `9826433759` retains earlier movement/Dash evidence. Current public artifact `9833689840` retains whole-path/reload evidence and hashes to `b5c2034b1398f852846c476f18c49d758c9fc17836607e06983eeb745a1d7f58`.
- [x] The live game, support, and privacy URLs each return HTTP 200.
- [ ] Public build displays current version and a working feedback link.

## 10. Android internal test

- [x] Historical pre-pivot arm64 portrait debug APK remains structurally verified under `../../build/semantic-qa-1db2d97a/`; current `a550ca8` Android debug job `100135598026` passed remotely. Neither result is an installed release AAB or Play internal test.
- [x] Its `.idsig` is 234,930 bytes with SHA-256 `d4a223d9647ea9321ea5ddc609eb073f5fd02ed08cd406d22b2e6872518b8381`.
- [x] Candidate Android export/validation job `100071482096` passes in Actions run `33572931398`; no emulator/device install, lifecycle, private signing, AAB, or Play upload is claimed.
- [x] Historical arm64 portrait debug APK `INFINIDIVE-0.1.0-prealpha-debug-e942db6f.apk` is hashed (`d089cebf2207391634fa6b2719d9b8c0a56e654619c33b05292e47aacc78bfa6`) and passes package/min24/target36/arm64/exact-VIBRATE/alignment/debug-v2-v3 validation.
- [x] Actions run `33557365042`, attempt 2, exports and structurally validates the Android debug build for exact-tree commit `67e2c54`; no emulator/device install or production-signing claim is made.
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

- [x] A direct iOS export from the checked-in preset remains intentionally gated because the owner Development Team is blank. A fresh local Linux export using an obvious non-secret Team placeholder in an ephemeral project copy successfully regenerated the Xcode scaffold; the placeholder was scrubbed before validation and was never added to the source preset.
- [x] Historical pre-pivot iOS PCK/scaffold evidence remains retained under `../../build/semantic-qa-1db2d97a/`; current `a550ca8` unsigned-scaffold job `100135598028` passed remotely. Neither is a macOS/Xcode compile, archive, signed app, Simulator/device install, or TestFlight result.
- [x] Historical unsigned iOS ZIP `INFINIDIVE-0.1.0-prealpha-ios-unsigned-e942db6f.zip` remains recorded in the prior passing `SHA256SUMS` with SHA-256 `5e3276c7d3c92a21ef154e776c290e4308424975c0af4f9eb604194537e51ede`; it is retained as prior-source evidence only.
- [x] The assembled unsigned scaffold records pbxproj SHA-256 `dbbc0f658d31f09a8ad0b020a4ef1d1f6072e422088d13c996dd0d09ee7748bb` and a 411-byte app-store-method export-options plist with SHA-256 `50c3cbc7d11c6c3c37357dc14e59ef93f1c011897467a9b94bb11637a795ea7d`.
- [x] Godot 4.7 still generates empty Camera, Microphone, and Photo Library usage-description entries even when the preset omits them. The deterministic post-export sanitizer removes only empty reviewed defaults plus `CFBundleSignature`; it rejects non-empty/non-string reviewed descriptions and every new unreviewed `NS*UsageDescription` key, writes atomically, reparses, and passes positive/negative/idempotency self-tests.
- [x] A fresh local Linux-generated scaffold passed exact custom 780×1688/1170×2532 RGB launch-pixel comparison, rejected the stock Godot splash path, and emitted tracking false with only `FileTimestamp:C617.1`, `SystemBootTime:35F9.1`, and `DiskSpace:E174.1`; collected-data and tracking-domain arrays are absent/empty. This is structural export evidence, not an Apple-platform build result.
- [x] The deployed-candidate CI unsigned-scaffold job passes remotely; artifact `9832974829` is a sanitized current-source Xcode handoff for `a550ca8`. It uses a fake Team ID only in a temporary project copy, scrubs it from generated project/export-options files, scans the whole artifact, and labels the result as unsigned Linux export evidence.
- [x] A rebuilt local iOS scaffold repairs scheme-to-target binding and passes metadata, icon, launch, and privacy validators.
- [x] The protected signed archive-only workflow and fail-closed source/profile/certificate/archive/IPA validator pass local self-tests, source checks, YAML/Bash parsing, full-SHA action-pin checks, trust-chain contract tests, and archive/IPA substitution negatives. No signed artifact is claimed.
- [ ] Register the byte-identical signed workflow on the default branch, protect `infinidive-production` and immutable `ios-v*` tags, configure the `app-store-production` environment/reviewers, and provide protected Apple signing credentials.
- [ ] Calibrate exact Xcode 26 `altool` success/error JSON schemas in a protected run before automated upload can be enabled; the current workflow rejects `upload_to_app_store_connect=true` before secrets.
- [x] A separate QA-only native store-capture lane is implemented and locally validates its source binding, Debug-only activation, six canonical state markers, exact 1320×2868 RGB/no-alpha contract, bright-identity thresholds, uniqueness, and changed Hunter Eye state. It cannot be called submission evidence before a real macOS run and human review.
- [ ] The Xcode 26 Simulator lanes pass remotely. They must compile, install, launch, capture the boot frame plus all six current-bright iPhone 16 Pro Max stages, terminate cleanly, and upload source-bound evidence.
- [ ] The full rebuilt current source is compiled for iOS. The Xcode scaffold can be regenerated structurally on Linux, but no current macOS/Xcode compile has occurred.
- [ ] Direct release export/archive from the checked-in blank-Team-ID preset succeeds; owner Team ID and signing configuration are still required.
- [x] The retained unsigned scaffold contains 47 files and records an approximately 368 MB directory size; this does not claim that the scaffold itself was regenerated for the current tree.
- [ ] Bundle ID, Apple team, capabilities, and minimum iOS version receive final owner/store approval.
- [ ] Xcode archive is produced on macOS.
- [ ] Release candidate is compiled and archived with Xcode 26 or later and the iOS 26 SDK.
- [ ] Final `.xcarchive` Privacy Report, Info.plist, entitlements, embedded frameworks, required-reason manifest, export-compliance answer, bundle version/build, and icon/launch assets are inspected.
- [ ] Signing/provisioning uses private protected credentials.
- [ ] Archive uploads to App Store Connect/TestFlight.
- [ ] Fresh TestFlight install passes.
- [ ] Save update, background/resume, audio interruption, Dynamic Island, and safe-area tests pass.
- [ ] Store privacy declarations match the exact final binary behavior.

## 12. Store assets and metadata

- [x] Original 1024×1024 app-icon source/raster exists; the raster is verified RGB without alpha.
- [x] Dedicated Google Play icon raster exists at 512×512, 141,587 bytes, 8-bit/color RGBA; final visual and console-upload validation remain pending.
- [x] Exact-size RGB/no-alpha iOS icon rasters and custom portrait launch assets are wired in the preset. A fresh local scaffold validates launch pixel parity and metadata; committed remote proof and final signed-archive inspection remain open.
- [ ] App icon is visually tested at small sizes and wired into the final Android asset catalog.
- [x] Five direct runtime screenshots exist at 1080×1920 with provenance and hashes.
- [ ] At least one complete 6.9-inch screenshot set is recaptured from the RC at Apple-accepted dimensions; the planned eight-scene narrative is a product choice, not Apple's minimum count.
- [x] A technical 886×1920, 17.2-second H.264/AAC stereo Apple-format candidate exists with provenance and hash.
- [ ] If an App Preview is used, recapture it from the RC in Xcode Device Hub on a supported simulated or physical iPhone and pass App Store Connect processing; otherwise omit it for 1.0. App Preview is optional.
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
- [x] Repository-local bilingual Support, Privacy, and Draft Terms pages exist; `a550ca8` deployed the then-current legal pages. Rebuilt public notices are local, unapproved, and not yet deployed or audited against the final binary/archive.
- [ ] Support, privacy, and marketing URLs are public and correct. The deployed support and privacy URLs return HTTP 200; final content/legal/marketing validation remains open.
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
