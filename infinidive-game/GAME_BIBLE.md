# INFINIDIVE — Game Bible

> Truth status: pre-alpha development snapshot 0.1.0, recorded 2026-09-01. This document describes the game present in the repository now. It is not a claim that INFINIDIVE 1.0, a signed store build, public deployment, or device-validated release exists.

## Product identity

**Tagline:** Fight giants outside. Destroy them within.

INFINIDIVE is a portrait, touch-first 2D action roguelite. The implemented hook is a repeatable outside–inside–outside fight:

1. Break a colossal boss's exterior armor.
2. Open a breach.
3. Choose one of its remaining organs.
4. Traverse a seeded internal route.
5. Destroy the organ.
6. Choose a temporary mutation.
7. Return outside with the organ's linked attack disabled.
8. Repeat for all three organs.
9. Destroy the exposed core or die.
10. Bank rewards and return to the Last Nest.

The current project is built in Godot 4.7.2 with GDScript and the GL Compatibility renderer. Its logical viewport is 540 × 960 and its project version is 0.1.0. The Nest and combat HUD are fitted into native safe-area rectangles or Web CSS safe-area insets; this math is headless-tested but not verified on physical phones.

## Design pillars represented in the current build

- **Immediate movement:** dragging moves the Diver and firing is automatic.
- **Boss anatomy:** every boss has exactly three organs, each mapped to one exterior ability.
- **Player-selected organ order:** every breach presents all surviving organs.
- **Skill plus build:** movement, dash timing, weapon behavior and up to three selected mutations affect a run.
- **Retained progress:** failed runs bank part of their Bio-Matter; victories grant full run rewards and boss rewards.
- **Visible Nest progress:** the Last Nest has five drawn stages and facilities unlock by stage.
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
- Destroying an organ currently removes its linked ability from the attack pool completely.

### Internal route

For a chosen organ, RoomGenerator creates a deterministic five-entry route:

1. Fixed entrance.
2. One eligible traversal module.
3. One eligible combat module.
4. One eligible hazard module.
5. The organ's authored chamber.

The catalog contains 30 non-chamber modules: eight traversal, ten combat and twelve hazard records, plus 12 organ chambers. `RoomMechanics` provides an explicit deterministic contract for each of the 42 hazard IDs, including schedule, telegraph, normalized safe positions, active windows, spawn caps and cleanup identity. Runtime consumes those safety/timing bounds, and focused playback verifies full warnings, matching warning/projectile gaps, bounded active waves, cleanup, and deterministic behavior under normal and hitch timing. It still renders only three broad execution geometries: rings, defender/projectile spawns, and a vertical gap wall shared by the declared lane and sweep families. Named pattern and movement-model IDs are not 42 bespoke visual modules, and automated playerless playback is not proof of human reachability.

### Organ chamber and return

- Organ health is its catalog HP multiplied by 1.65 and the selected difficulty's HP multiplier.
- Internal defenders accompany the chamber.
- Destroying the organ awards run Bio-Matter and score, disables the linked ability, and offers three deterministic non-duplicate mutations.
- Selecting a mutation returns the player to exterior combat.
- After the third organ, the core becomes the final target.

## Boss roster

All four boss records, their portraits and their organ maps are loaded by the current game. Bosses have different health, palettes, silhouettes and organ ability sets. Several abilities share projectile-pattern controllers, so this is not yet four wholly unique production encounters.

| Boss | Base armor | Core HP | Organ → exterior ability |
|---|---:|---:|---|
| GRAVEMAW | 1,750 | 3,600 | Hunter Eye → Homing Eye |
|  |  |  | Gravity Lung → Gravity Ring |
|  |  |  | Bone Forge → Bone Missiles |
| SERAPH-9 | 2,150 | 4,400 | Prism Cortex → Prism Lances |
|  |  |  | Wing Reactor → Laser Wings |
|  |  |  | Halo Choir → Halo Barrier |
| ABYSS LEVIATHAN | 2,450 | 5,000 | Vortex Stomach → Suction Waves |
|  |  |  | Shock Gland → Chain Lightning |
|  |  |  | Brood Sac → Parasite Swarm |
| NULL TWIN | 2,850 | 6,200 | Memory Cortex → Weapon Copy |
|  |  |  | Echo Heart → Echo Dash |
|  |  |  | Reflection Lattice → False Weakpoints |

The organ catalog text sometimes describes an attack as weakened or altered. The current OrganAbilityMap behavior is stricter: it sets the mapped ability to disabled with zero strength.

BossVisual receives the destroyed-organ list. It renders organ status and phase changes; SERAPH-9 also has explicit broken-wing and broken-halo states. Other physical transformations are currently more abstract.

## Weapons

| Weapon | Current runtime identity | Unlock path |
|---|---|---|
| Pulse Needle | Fast single straight projectile | Default |
| Scatter Maw | Five-projectile spread | 2 Core Shards |
| Rail Spine | Slow, high-damage projectile with four pierces | 4 Core Shards or first GRAVEMAW clear |
| Arc Swarm | Homing projectile with up to three bounded chain hops and reduced damage after the primary hit | 6 Core Shards or first SERAPH-9 clear |
| Void Orbitals | Regular projectile plus two close orbitals that consume bullets and deal contact damage | 9 Core Shards or first ABYSS LEVIATHAN clear |

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

- A new profile starts with GRAVEMAW and Pulse Needle.
- Story victories unlock bosses sequentially: GRAVEMAW → SERAPH-9 → ABYSS LEVIATHAN → NULL TWIN.
- GRAVEMAW, SERAPH-9 and ABYSS LEVIATHAN victories also unlock Rail Spine, Arc Swarm and Void Orbitals respectively.
- The Hangar also allows locked weapons to be purchased directly for their Core Shard cost.
- Defeating NULL TWIN unlocks Abyss Loop.

### Forge

The catalog contains 18 upgrade definitions across hull, drive, weapons, salvage, depth and research branches. The Forge can buy levels using:

rounded cost = base cost × cost scale ^ current level

`PermanentUpgradeEngine` recognizes all 18 launch effect keys, rejects unknown definitions, aggregates and clamps stats, and enforces the Starting Sheath prerequisite through the Forge purchase gate. `RunScene` has a consumer for every effect, and the focused upgrade suite passes 120 assertions. Competitive Daily/Friend runs normalize combat-affecting permanent stats but retain Rift Dividend solely for Bio-Matter on victory; losses still use normalized death retention. It cannot affect ranked play time, score, damage or survivability. Human balance and combined-build feel have not been validated.

### The Last Nest

The five visual stages are:

1. Broken Shell
2. Awakened Reactor
3. Living Workshop
4. Diver Colony
5. Infinite Nest

Nest stage is the higher of total wins and total purchased upgrade levels divided by four, capped at stage four. The drawing adds reactor light, machinery, survivor silhouettes and plants as the stage rises.

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
| Story Descent | Select an unlocked boss, weapon and one of three difficulties; victory advances progression | No story scenes beyond boss fantasy text and Nest state |
| Daily Rift | Uses a seed derived from the current UTC date, chooses a fixed boss and weapon, and runs on Deep difficulty | A completed run can queue an unverified local summary under a canonical UTC-day challenge ID; there is no synchronization authority, upload transport, or online leaderboard |
| Friend Rift | Creates and parses ID1 codes containing boss, seed, weapon, difficulty, modifiers and optional targets | Accepted runs queue under a canonical payload-derived challenge ID, so unrelated codes do not share a local board. Score/time targets are evaluated and shown as met/missed after the run. Clipboard checksum is not server authority; modifier IDs are transported but do not yet alter rules |
| Abyss Loop | Cycles bosses after wins, increases HP, damage and projectile speed by depth, carries selected mutations, restores part of health, and advances local meta goals | Continuation occurs through the Retry action; no online leaderboard or periodic choice screen |

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

The current build uses code-drawn 2D visuals rather than imported character or boss art.

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
| Deep-space background | #03050C |

Projectiles use distinct shapes in addition to color. High-contrast mode changes hostile shots to orange while retaining the angular silhouette and white center.

Audio is synthesized at runtime. The current library contains 24 named one-shots, four boss tonal identities, and three-layer generated music for nine states: Nest, exterior, breach, Dive, interior, organ, low health, core, and victory. `RunScene` selects the boss identity and state/intensity; `armor_hit`, `organ_damage`, and `boss_phase` are connected to live combat with per-cue rate limiting. First-use layer generation is synchronous, transitions fade/restart layers rather than crossfading two complete state sets, and browser/device sound quality, interruption behavior, transition feel, and mastering remain untested. Haptic calls are optional and use Godot's handheld vibration API; Android declares only the normal `android.permission.VIBRATE` permission, which has no runtime prompt and does not collect data.

## Onboarding, localization and accessibility

### Current onboarding

- `TutorialFlow` observes ten persistent comprehension steps: movement, auto-fire, dash/telegraph defense, exposed armor, Dive, organ destruction, mutation choice, changed exterior behavior, phase/death, and Forge purchase.
- Accepted events persist immediately and may arrive out of order without double-counting. Tutorial completion means all ten bits are understood; it is not set by the Forge step alone.
- Settings exposes “Replay tutorial on next run.” Replay resets presentation without erasing persistent comprehension, persists the first nine observations across the Run-to-Nest handoff, and completes on the later Forge purchase.
- The defense step can advance through either a first Dash or a real telegraphed-volley avoidance: the latter is emitted only after that volley ends without a hit and without a Dash since its telegraph began. Replay remains observational rather than gated. Timing, comprehension and first-Dive targets have not been measured with people.

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

Damage-flash intensity is saved but the player damage animation still uses a fixed duration, and reduced motion does not suppress every transition effect. The four assist controls above are exposed and consumed by combat. Analytics opt-in is exposed in Settings and defaults off; enabling it only writes to the local queue because no transport exists.

## Save and local data

Save schema 6 stores currencies, weapon unlocks, upgrade levels, Nest stage, boss progress, achievements/meta goals, discovered mutations, tutorial state, settings, run totals and supporting future-facing fields.

Current reliability measures:

- JSON envelope with SHA-256 checksum
- Temporary-file write before promotion
- Previous primary rotated to a backup
- Backup recovery when the primary is invalid
- Migrations from schema 1 through schema 6
- Legacy `tutorial_complete=true` maps to the full ten-step `TutorialFlow.FULL_MASK`; replay presentation remains separate
- Default-field deep merge
- A durable processed-run ledger retained to reject duplicate banking, including after later runs

Settings exposes Reset Progress behind a bilingual destructive confirmation. The current reset replaces and saves the default profile, replaces the prior-profile backup with a clean-default recovery copy, idempotently clears the analytics queue and the Daily/Friend leaderboard primary, backup, and temporary files, reapplies default settings, and rebuilds meta-goal state. A failed persistence or cleanup step prevents a success refresh and plays an error cue; the UI still needs human failure-path validation.

## Analytics and online boundaries

Analytics is opt-in and defaults to off. When enabled, approved events are sanitized and stored in a local queue capped at 500 entries. Independently, every completed run calls a local validation service. Story/Abyss summaries return local-only and are not queued; accepted Daily/Friend summaries use canonical challenge IDs and enter a validated, checksummed outbox capped at 256 entries. Those entries are marked unverified and remain on the device. Neither service has upload transport; no dashboard, account system, online leaderboard, or backend is connected.

The game makes no core-play network request and does not embed backend credentials.

## Current completion boundary

Present and playable in source:

- Complete outside–inside–outside state path
- Four boss records and visual silhouettes
- Three selectable organs per boss
- Five weapon records and runtime weapon behaviors
- 24 mutation records
- 18 permanent-upgrade records
- 30 internal modules and 12 chambers
- Story, local Daily Rift, local Friend Rift and Abyss Loop flows
- Ten-step tutorial state, replay request, 14 achievements and 19 rotating local contracts
- Five Nest stages
- Versioned save, procedural audio, settings and headless tests
- Native/Web safe-area fitting for the Nest and HUD

Not established by this snapshot:

- Full production-quality uniqueness for every boss attack and room
- Human balance/feel validation for mutation and permanent-upgrade combinations
- Complete cosmetic system and richer achievement/contract presentation
- Browser/simulator/device validation of Hebrew/RTL text fit and visual ordering
- Backend leaderboards, cloud saves or score validation
- Monetization, purchases, ads or restore flow
- Public deployment success
- Android or iOS signed builds
- A completed remote browser workflow, touch-gameplay browser automation, release-candidate performance/device QA, or a full 30-minute code-frozen soak rerun (a 90.02-second fingerprint-clean current-tree soak passes)
- Final Apple 6.9-inch screenshots, a supported-iPhone App Preview capture, store approval, or submission (five 1080×1920 development stills, an audio-complete 1080×1920 social trailer, and an 886×1920 Apple-format technical candidate exist; all are virtual-display evidence)

## Source precedence

When this document disagrees with implementation, use this order:

1. scripts/gameplay and scripts/core
2. scripts/services and scripts/ui
3. data JSON catalogs
4. BALANCE.md
5. This Game Bible

Update this document whenever the playable loop or content contract changes.
