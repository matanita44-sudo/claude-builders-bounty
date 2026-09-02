# INFINIDIVE — Game Bible

> Truth status: pre-alpha development snapshot 0.1.0, recorded 2026-09-02. The live Pages deployment marker advanced to hardening commit `e7275f5fc78ad7237da2549ff0396123814ccebc` in Actions run `33668271115`, but that run's public-smoke job later failed during bright-trailer input. The latest complete public whole-path/reload proof therefore remains bright Greek-mythic/AION commit `a550ca867506f34856cf337fbe28083a9cdbaec5` from passing run `33594396541`. This document is not a claim that INFINIDIVE 1.0, a production-signed store build, device-validated release, TestFlight build, or submitted App Store product exists. The post-`e7275f5` fixes remain local until a new source-bound remote run proves them.

## Product identity

**Current in-game tagline:** Fight giants outside. Destroy them within.

INFINIDIVE is a portrait, touch-first 2D action roguelite set across a bright mythic sky-world. AION, god of eternity, was broken into four living shards and devoured at a forbidden feast by CRONUS, HYPERION, OCEANUS and MNEMOSYNE. AION's final curse condemned the Titans to eternal hunger: they now consume one sky-world after another without ever becoming full. At the Last Nest, an unarmed young Keeper hears AION's final heartbeat and becomes the first Diver.

The implemented gameplay hook is framed as **outside → Dive → purify → return**:

1. Face a colossal Titan in an exterior sky battle.
2. Break its exterior armor and open a breach in its divine seal.
3. Choose one of its remaining fractured organs.
4. Dive through a seeded internal route.
5. Purify the chosen organ by defeating its defenders and exhausting its HP.
6. Choose a temporary mutation.
7. Return outside and see the organ's linked attack transformed or disabled.
8. Repeat for all three organs.
9. Defeat the exposed core or die.
10. Bank rewards and return to the Last Nest sky sanctuary.

“Purify” is the current fiction and presentation direction. The runtime still names the completion event `organ_destroyed`, resolves it through damage and HP, and stores the organ ID in the destroyed-organ list. This document does not imply that those internal contracts have been renamed.

The current project is built in Godot 4.7.2 with GDScript and the GL Compatibility renderer. Its logical viewport is 540 × 960 and its project version is 0.1.0. The Nest and combat HUD are fitted into native safe-area rectangles or Web CSS safe-area insets; this math is headless-tested but not verified on physical phones.

## Design pillars represented in the current build

- **Immediate movement:** dragging moves the Diver and firing is automatic.
- **Titan anatomy:** every Titan has exactly three fractured organs, each mapped to one exterior ability.
- **Player-selected organ order:** every breach presents all surviving organs.
- **Skill plus build:** movement, dash timing, weapon behavior and up to three selected mutations affect a run.
- **Retained progress:** failed runs bank part of their Bio-Matter; victories grant full run rewards and boss rewards.
- **Visible Nest progress:** the Last Nest has five drawn stages, evolving from a broken floating shrine into a populated celestial haven; facilities unlock by stage.
- **Offline core:** story runs, Daily Rift seeds, Friend Rift codes, save data and Abyss Loop do not require a server.

These pillars describe implemented systems, not validated player-retention or fun metrics.

## Controls

| Input | Current behavior |
|---|---|
| Touch drag | Moves toward the touch position with an 82px upward finger offset, smoothing and an 8px dead zone |
| Mouse drag | Emulated as touch by the Godot project settings |
| Automatic fire | Aims at the nearest internal defender, then the current organ or exterior boss |
| Dedicated Phase button | Default dash method |
| Double tap | Optional dash method; second tap must occur within 310ms and 72px |
| Quick flick | Optional dash method; gesture must travel at least 78px within 280ms |
| Space / controller face button | Present in the InputMap, but RunScene does not currently consume this action |
| Escape / controller menu button | Present in the InputMap, but RunScene does not currently consume this action |

The left/right-hand setting moves the HUD's Dash and Dive buttons. Controller actions exist, but controller play has not been documented as device-tested.

## Run state machine

The implemented states are:

INTRO → EXTERIOR → BREACH_OPEN → ORGAN_SELECT → DIVING_IN → INTERNAL_ROOMS → ORGAN_CHAMBER → MUTATION_CHOICE → DIVING_OUT → EXTERIOR

After three organ destructions, DIVING_OUT enters CORE instead of another armor phase. A run then reaches DEAD or VICTORY.

Combat is paused during organ selection, mutation selection, death and victory. Application focus loss requests an in-game pause.

### Exterior phases

- Every boss has three armor phases.
- Phase armor is rebuilt from the boss's base armor using phase multipliers 3.0, 3.5 and 4.1.
- Destroying phase armor opens a breach and clears hostile projectiles.
- The breach remains open for a seven-second baseline window, multiplied by Breach Anchor, then closes if the player does not Dive.
- Exterior attacks are drawn from one baseline rupture pattern plus abilities whose organs are still alive.
- Destroying an organ always removes its intact ability. Seven organs replace it with a validated safer degraded pattern; five disable the system completely.

### Internal route

For a chosen organ, RoomGenerator creates a deterministic five-entry route:

1. Fixed entrance.
2. One eligible traversal module.
3. One eligible combat module.
4. One eligible hazard module.
5. The organ's authored chamber.

The catalog contains 30 non-chamber modules: eight traversal, ten combat and twelve hazard records, plus 12 organ chambers. `RoomMechanics` provides an explicit deterministic contract for each of the 42 hazard IDs, including schedule, telegraph, normalized safe positions, active windows, spawn caps and cleanup identity. The pure runtime compiler expands those contracts into eight runtime categories, six movement models, 42 spawn profiles, 25 projectile profiles, and ten defender archetypes. Runtime consumes the compiled geometry, travel, movement, actors, warning/safe-pocket data, frozen preview/digest, compiler-signed owner/cycle identity, caps, and cleanup. Focused playback verifies normal/hitch schedules, collision/drawing parity, 30/60 Hz travel, tracking suppression, first-arena-exit terminal behavior, and owned cleanup. This is meaningful code-drawn differentiation, not 42 bespoke art scenes, and automated playerless playback is not proof of human readability, reachability, or enjoyment.

### Purification chamber and return

- Organ health is its catalog HP multiplied by 1.65 and the selected difficulty's HP multiplier.
- Internal defenders accompany the chamber.
- Completing the purification by reducing the organ to zero HP awards run Bio-Matter and score, removes the intact linked ability, applies its transformed-or-disabled loss contract, and offers three deterministic non-duplicate mutations.
- Selecting a mutation returns the player to exterior combat.
- After the third organ, the core becomes the final target.

## Boss roster

All four Titan records, their authored textures and their organ maps are loaded by the current game. The stable mechanical IDs remain unchanged for save, challenge-code and service compatibility. The Titans have different health, palettes, silhouettes and organ ability sets. Several abilities share projectile-pattern controllers, so this is not yet four wholly unique production encounters.

| Titan | Stable boss ID | Base armor | Core HP | Fractured organ → exterior ability | Loss contract |
|---|---|---:|---:|---|---|
| CRONUS — The Gilded Harvester | `gravemaw` | 1,750 | 3,600 | Fate Eye → Homing Eye | Transformed into straight salvos |
|  |  |  |  | Gaia Breath → Gravity Ring | Transformed into a slower ring with a wider safe opening |
|  |  |  |  | Adamant Forge → Bone Missiles | Disabled |
| HYPERION — Lord of First Light | `seraph_9` | 2,150 | 4,400 | Dawn Mind → Prism Lances | Transformed into fewer rays with a longer warning |
|  |  |  |  | Solar Mantle → Laser Wings | Transformed into a single-wing sweep with a safe flank |
|  |  |  |  | Sun Crown → Halo Barrier | Transformed into a fractured ring that cannot fully close |
| OCEANUS — The Worldstream | `abyss_leviathan` | 2,450 | 5,000 | Worldstream Heart → Suction Waves | Transformed into a weaker pull with a broad calm channel |
|  |  |  |  | Storm Palm → Chain Lightning | Transformed into an unchained single arc |
|  |  |  |  | River Springs → Parasite Swarm | Disabled |
| MNEMOSYNE — Mother of Echoes | `null_twin` | 2,850 | 6,200 | Memory Crown → Weapon Copy | Disabled |
|  |  |  |  | Echo Heart → Echo Dash | Disabled |
|  |  |  |  | Muse Veil → False Weakpoints | Disabled |

These are the twelve selectable fractured organs in the current boss catalog. They are not twelve separately persisted collectibles. `data/story.json` instead defines one named AION shard returned by each Titan chapter—Beginning, Radiance, Flow and Memory—and `StoryService` can derive restored shards from a supplied set of cleared boss IDs. The live save still banks the existing numeric Core Shards currency rather than four unique narrative-shard objects.

`BossVisual` receives the destroyed-organ list and supports a distinct loss token for all twelve organs, alongside authored Titan textures and procedural phase/effect drawing. Automated visual-contract tests cover those tokens; their clarity and impact have not yet been validated with human players or physical devices.

## Weapons

| Weapon | Current runtime identity | Unlock path |
|---|---|---|
| Aion Spark (`pulse_needle`) | Fast single straight divine bolt; display-awakens from the Keeper's empty hands after first movement | Default |
| Scatter Maw | Five-projectile spread | 2 Core Shards |
| Rail Spine | Slow, high-damage projectile with four pierces | 4 Core Shards or first CRONUS clear |
| Arc Swarm | Homing projectile with up to three bounded chain hops and reduced damage after the primary hit | 6 Core Shards or first HYPERION clear |
| Void Orbitals | Regular projectile plus two close orbitals that consume bullets and deal contact damage | 9 Core Shards or first OCEANUS clear |

Weapon descriptions, exact values and caveats are maintained in BALANCE.md and data/weapons.json.

## Temporary mutations

The catalog contains exactly 24 mutation definitions. Mutation offers are seeded, contain no duplicate IDs, and do not re-offer a mutation already selected in the run.

The mutation interpreter separates numeric keys ending in `_mul` or `_add` from flag-style effects. All 42 effect keys used by the 24 launch mutations are now covered by an explicit catalog contract and runtime consumers, including contextual dash, breach, shield, healing, pickup, orbital, rate, and damage behaviors. The headless suite verifies representative behavior; human balance and control-feel validation is still absent.

There is currently no rarity field, tag eligibility filter or weighted offer logic. Research Reroll grants one or two per-run rerolls; the reroll excludes the three IDs from the immediately previous offer.

## Permanent progression

### Currencies

- **Bio-Matter:** earned inside runs and spent on Forge upgrade levels.
- **Core Shards:** earned only from Story Descent victories and spent to unlock weapons.

There are no purchases, ads, premium currencies or network-dependent rewards in the current project.

### Boss and weapon unlocks

- A new profile starts with CRONUS (`gravemaw`) and Aion Spark (`pulse_needle`).
- Story victories unlock Titans sequentially: CRONUS → HYPERION → OCEANUS → MNEMOSYNE.
- CRONUS, HYPERION and OCEANUS victories also unlock Rail Spine, Arc Swarm and Void Orbitals respectively.
- The Hangar also allows locked weapons to be purchased directly for their Core Shard cost.
- Defeating MNEMOSYNE unlocks Abyss Loop.

### Forge

The catalog contains 18 upgrade definitions across hull, drive, weapons, salvage, depth and research branches. The Forge can buy levels using:

rounded cost = base cost × cost scale ^ current level

`PermanentUpgradeEngine` recognizes all 18 launch effect keys, rejects unknown definitions, aggregates and clamps stats, and enforces the Starting Sheath prerequisite through the Forge purchase gate. `RunScene` has a consumer for every effect, and the focused upgrade suite passes 120 assertions. Competitive Daily/Friend runs normalize combat-affecting permanent stats but retain Rift Dividend solely for Bio-Matter on victory; losses still use normalized death retention. It cannot affect ranked play time, score, damage or survivability. Human balance and combined-build feel have not been validated.

### The Last Nest

The save and localization layer retain five existing stage labels. Their current visual interpretation is a mythic floating sanctuary:

| Stage | Existing UI label | Current visual state |
|---:|---|---|
| 0 | Broken Shell | Broken sky shrine, fallen masonry, damaged columns and a dormant Aether altar |
| 1 | Awakened Reactor | Restored temple frame, awakened altar and illuminated bronze paths |
| 2 | Living Workshop | Working bronze mechanisms and waterfalls beneath the island |
| 3 | Diver Colony | Keeper silhouettes, banners and a visibly inhabited sanctuary |
| 4 | Infinite Nest | Laurels, orbiting star lights and a thriving celestial haven |

Nest stage is the higher of total wins and total purchased upgrade levels divided by four, capped at stage four. The scene is drawn as a bright floating island with clouds, marble terraces, bronze inlay, aqua Aether light and six facilities with distinct mythic-tech silhouettes. Reduced Motion freezes decorative cloud, water, Aether and ornament animation while preserving every structure and interaction.

| Facility | Stage requirement | Current function |
|---|---:|---|
| Hangar | 0 | Select or unlock weapons |
| Forge | 0 | Buy permanent upgrade levels |
| Research Vat | 1 | Read all boss organ descriptions |
| Rift Terminal | 1 | Start Daily Rift; create/open Friend Rift codes; display three deterministic UTC-day contracts |
| Trophy Chamber | 2 | Display boss clears and 14 local achievement progress rows |
| Core Chamber | 3, or Abyss unlocked | Start Abyss Loop |

Fourteen local achievements and nineteen local contracts are data-driven, rotate deterministically by UTC day, progress through idempotent offline events, award Bio-Matter/Core Shards, and have basic player-facing lists. Exact-once reward handling uses a durable ledger and bounded SHA-256 event receipts; new goal-changing events fail closed if the 4,096-receipt cap is reached. Their UI shows title/progress but not full reward/completion history. Cosmetics remain only an unused default save value: there is no catalog, unlock, selector, or renderer consumer.

## Modes

| Mode | Implemented behavior | Current boundary |
|---|---|---|
| Story Descent | Select an unlocked Titan, weapon and one of three difficulties; victory advances progression. The first eligible CRONUS Story run presents a skippable four-beat English-first prologue. Main also presents the localized chapter intro before an eligible Story attempt, injects that chapter's authored first-breach beat into the actual breach event, and presents the shard-restoration beat when the run result explicitly marks its first Story clear | All four chapter intros, first-breach lines, and first-clear victory beats are connected. The breach line is a short nonmodal HUD message: movement, the seven-second breach timer, and the Dive control remain active. Its globally unique beat ID is saved before display in a versioned exact-once ledger; save failure suppresses the line and allows a later retry. Story gating does not rely on the cross-mode `boss_clears` counter |
| Daily Rift | Uses a seed derived from the current UTC date, chooses a fixed boss and weapon, and runs on Deep difficulty | A completed run can queue an unverified local summary under a canonical UTC-day challenge ID; there is no synchronization authority, upload transport, or online leaderboard |
| Friend Rift | Creates and parses ID1 codes containing boss, seed, weapon, difficulty, modifiers and optional targets | Accepted runs queue under a canonical payload-derived challenge ID, so unrelated codes do not share a local board. Score/time targets are evaluated and shown as met/missed after the run. Only completed Daily/Friend results expose result sharing: Story upgrades/Assist state and Abyss continuation state are not encoded by ID1. Clipboard checksum is not server authority; modifier IDs are transported but do not yet alter rules |
| Abyss Loop | Cycles bosses after wins, increases HP, damage and projectile speed by depth, carries selected mutations, restores part of health, and advances local meta goals | Continuation occurs through the Retry action; no online leaderboard or periodic choice screen. Abyss results remain local and do not expose Friend Rift sharing because ID1 codes cannot reconstruct depth scaling, carried mutations, restored health, mutation-choice position, or cumulative score |

Daily and Friend Rift configurations set competitive mode. Competitive mode deliberately ignores combat-affecting permanent upgrades; only Rift Dividend remains for the victory Bio-Matter calculation.

## Difficulty

All three difficulty choices are currently selectable without progression gating.

| Difficulty | HP | Damage | Projectile speed | Reward |
|---|---:|---:|---:|---:|
| Diver | 0.84× | 0.78× | 0.88× | 0.90× |
| Deep | 1.00× | 1.00× | 1.00× | 1.00× |
| Abyss | 1.18× | 1.22× | 1.13× | 1.35× |

Abyss Loop adds per-depth scaling beyond these values. Exact formulas are in BALANCE.md.

## Presentation

The current direction is bright mythic 2D: blue sky-worlds, marble, bronze, aqua Aether light, coral danger accents, gold divine seals, chunky silhouettes and strong dark outlines for mobile readability. The build imports authored raster art for the unarmed Keeper, all four Titans, the sky battle and the divine interior. `PlayerController`, `BossVisual`, `RunScene` and the Last Nest also add procedural drawing for readable status, phase damage, organ-loss transformations, effects, sanctuary structures and fallbacks. This is a working art pass, not a claim of final production art or device-validated readability.

Semantic palette:

| Meaning | Color |
|---|---|
| Friendly/player | #54F2E7 |
| Enemy projectile | #FF4D5E |
| Telegraph | #FFC857 |
| Vulnerable tissue | #F32D83 |
| Bio-Matter | #92E65D |
| Core Shard | #A78BFA |
| Armor | #D7D0BD |
| Dark UI / outline base | #03050C |

Projectiles use distinct shapes in addition to color. High-contrast mode changes hostile shots to orange while retaining the angular silhouette and white center.

Audio ships as 123 deterministic, original pre-rendered `AudioStreamWAV` resources produced offline from project-owned oscillator/noise recipes. The catalog contains 24 named one-shots plus 99 adaptive layers covering four Titan tonal identities and nine states: Nest, exterior, breach, Dive, interior, organ, low health, core, and victory. `RunScene` selects the Titan identity and state/intensity; `armor_hit`, `organ_damage`, and `boss_phase` are connected to live combat with per-cue rate limiting. Runtime loads resources lazily with bounded caches and performs no PCM synthesis during startup or gameplay. Transitions fade/restart layers rather than crossfading two complete state sets, and browser/device sound quality, interruption behavior, transition feel, and mastering remain untested. Haptic calls are optional and use Godot's handheld vibration API; Android declares only the normal `android.permission.VIBRATE` permission, which has no runtime prompt and does not collect data.

## Onboarding, localization and accessibility

### Current onboarding

- `TutorialFlow` observes ten persistent comprehension steps: movement, auto-fire, dash/telegraph defense, exposed armor, Dive, organ destruction, mutation choice, changed exterior behavior, phase/death, and Forge purchase.
- Accepted events persist immediately and may arrive out of order without double-counting. Tutorial completion means all ten bits are understood; it is not set by the Forge step alone.
- Settings exposes “Replay tutorial on next run.” Replay resets presentation without erasing persistent comprehension, persists the first nine observations across the Run-to-Nest handoff, and completes on the later Forge purchase.
- The defense step can advance through either a first Dash or a real telegraphed-volley avoidance: the latter is emitted only after that volley ends without a hit and without a Dash since its telegraph began. Replay remains observational rather than gated. Timing, comprehension and first-Dive targets have not been measured with people.

### AION prologue and first movement

- On a non-QA Story start against CRONUS, while the persistent tutorial understood mask is still zero, `Main` presents a skippable four-beat English-first prologue: AION is devoured, the Titans receive eternal hunger, the hero begins unarmed, and AION's Spark is promised. Hebrew remains an optional Settings localization and is never selected automatically for a fresh profile.
- That launch is marked `aether_prologue`. The Keeper enters the run with the Spark dormant and automatic fire blocked.
- Moving at least 12 pixels records the tutorial movement observation and starts a 0.36-second awakening delay. The AION Spark then appears, automatic fire becomes active, and the game emits its toast, sound, haptic request and analytics event.
- The authored hero and procedural fallback both present empty hands. Even after awakening, `PlayerController.presentation_snapshot()` reports no visible physical weapon and no muzzle flash. Weapon selection and automatic projectile behavior still exist as combat systems; “unarmed” describes the hero presentation, not removal of the weapon catalog.
- Prologue eligibility currently relies on the tutorial understood mask rather than a separate narrative-completion save field. The prologue handoff marks `story_intro_seen` so it does not immediately duplicate CRONUS's chapter intro. For each Titan, Main otherwise shows the chapter intro only while its Story difficulty progress is incomplete. Main prepares the authored `first_breach` beat only for a fresh Story chapter; `RunScene` persists its beat ID before showing a nonmodal HUD line at the actual first breach, removes the consumed notice from retry configuration, and leaves movement, the breach timer, and Dive active. Daily/Friend/Abyss and malformed state fail closed. Before banking, RunScene records an explicit `story_first_clear` result marker; Main uses that marker for the victory/shard beat, so non-Story wins cannot suppress or fabricate chapter delivery. `story_intro_seen` survives the handed-off config and its retry, but is not separately persisted; returning to the Nest before a clear can therefore show the intro again.

### Localization

- English and Hebrew tables contain matching, non-empty interface keys.
- Bosses, organs, abilities, weapons, mutations, upgrades, room rules and hazard names have Hebrew catalog translations.
- Nest overlays and run-choice/result surfaces apply locale-aware direction and alignment; representative Hebrew UI and fallback-font glyph coverage pass headless tests.
- Small-phone text expansion, clipping, visual order and live language switching still require browser/simulator/physical-device QA.

### Settings with runtime effect

- Master, music and SFX volume
- Haptics
- Screen-shake amount
- Reduced motion for camera shake
- High-contrast hostile projectiles
- Control sensitivity
- Dash method
- Left/right hand HUD button placement
- Language
- Assist projectile-speed multiplier
- Assist telegraph multiplier
- Assist dash-window multiplier
- Aim assistance

Damage-flash intensity controls the player highlight blend while retaining a short fixed feedback window. Reduced Motion suppresses shake and player trails, freezes decorative Nest/boss/background movement, uses a stable Dive tunnel frame, and removes toast opacity sweeps while preserving gameplay-significant motion. The four assist controls above are exposed and consumed by combat. The bilingual diagnostics setting accurately describes on-device storage and defaults off; enabling it only writes to the local queue because no transport exists, and disabling it clears the queue with a next-boot retry on failure. All accessibility effects still require browser/device and human-comfort validation.

## Save and local data

Save schema 7 stores currencies, weapon unlocks, upgrade levels, Nest stage, boss progress, achievements/meta goals, discovered mutations, tutorial state, exact-once Story beat receipts, settings, run totals and supporting future-facing fields.

Current reliability measures:

- JSON envelope with SHA-256 checksum
- Temporary-file write before promotion
- Previous primary rotated to a backup
- Backup recovery when the primary is invalid
- Migrations from schema 1 through schema 7
- Legacy `tutorial_complete=true` maps to the full ten-step `TutorialFlow.FULL_MASK`; replay presentation remains separate
- Default-field deep merge
- A durable processed-run ledger retained to reject duplicate banking, including after later runs

Settings exposes Reset Progress behind a bilingual destructive confirmation. The current reset replaces and saves the default profile, replaces the prior-profile backup with a clean-default recovery copy, idempotently clears the analytics queue and the Daily/Friend leaderboard primary, backup, and temporary files, reapplies default settings, and rebuilds meta-goal state. A failed persistence or cleanup step prevents a success refresh and plays an error cue; the UI still needs human failure-path validation.

## Analytics and online boundaries

Analytics is opt-in and defaults to off. When enabled, approved events are sanitized and stored in a local queue capped at 500 entries. Independently, every completed run calls a local validation service. Story/Abyss summaries return local-only and are not queued; accepted Daily/Friend summaries use canonical challenge IDs and enter a validated, checksummed outbox capped at 256 entries. Those entries are marked unverified and remain on the device. Neither service has upload transport; no dashboard, account system, online leaderboard, or backend is connected.

The game makes no core-play network request and does not embed backend credentials.

## Current completion boundary

Present and playable in source:

- Complete outside–Dive–purify–return state path, with purification currently resolved by the existing organ-destruction runtime contract
- A skippable English-first AION opening, optional Hebrew localization, and first-movement Spark awakening for the first eligible CRONUS Story run
- Four Titan records, authored textures and distinct visual silhouettes
- Three selectable fractured organs per Titan, with twelve supported exterior-loss visual tokens
- A four-chapter bilingual story catalog and read-only story service, with localized chapter-intro, live nonmodal first-breach, and first-clear victory presentation connected through Main and RunScene
- Five weapon records and runtime weapon behaviors
- 24 mutation records
- 18 permanent-upgrade records
- 30 internal modules and 12 chambers
- Story, local Daily Rift, local Friend Rift and Abyss Loop flows
- Ten-step tutorial state, replay request, 14 achievements and 19 rotating local contracts
- Five Nest stages
- Versioned save, deterministic original audio, settings and headless tests
- Native/Web safe-area fitting for the Nest and HUD

Not established by this snapshot:

- Full production-quality uniqueness for every boss attack and room
- Human pacing and comprehension validation for the four live `first_breach` chapter beats
- Separate persistence or player-facing collection UI for the four named AION story shards
- Human balance/feel validation for mutation and permanent-upgrade combinations
- Complete cosmetic system and richer achievement/contract presentation
- Browser/simulator/device validation of Hebrew/RTL text fit and visual ordering
- Backend leaderboards, cloud saves or score validation
- Monetization, purchases, ads or restore flow
- Android or iOS signed builds
- Release-candidate device/performance QA or physical-device control-feel testing. Commit `a550ca867506f34856cf337fbe28083a9cdbaec5` passed both CI-served and public-host full outside-inside-outside semantic paths plus same-context reload in Actions run `33594396541`, alongside its source-bound 1,800.026-second structural soak. That proves automated desktop-Chromium state transitions and persistence for `a550ca8`; it does not prove the rebuilt local follow-up, Mobile Safari/Chrome behavior, native Simulator/device ergonomics, or human comprehension.
- Final Apple 6.9-inch screenshots, a supported-Apple-path App Preview capture, store approval, or submission. Five 1080×1920 stills, an audio-complete 1080×1920 social edit, and an 886×1920 Apple-format experiment exist, but all are virtual-display evidence from the superseded pre-pivot identity and must not represent the current product.

## Source precedence

When this document disagrees with implementation, use this order:

1. scripts/gameplay and scripts/core
2. scripts/services and scripts/ui
3. data JSON catalogs
4. BALANCE.md
5. This Game Bible

Update this document whenever the playable loop or content contract changes.
