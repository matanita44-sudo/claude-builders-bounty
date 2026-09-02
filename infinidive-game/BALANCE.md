# INFINIDIVE — Balance Source of Truth

> Snapshot: project version 0.1.0 on 2026-09-01. Values below describe current code and JSON data. They are not playtest conclusions, retention claims or final launch tuning.

The reconstructed post-`a550ca8` tree passes the complete local `40,709/0` matrix across 21 suites, editor/import, and strict zero-error scanning. Focused Titan attack, organ transformation, pre-rendered audio, visual, story, localized-layout acceptance, and QA-only native-capture activation gates now run independently. Deployed `a550ca8` separately retains source-bound remote `28,949/0`; the rebuilt delta requires a new remote fingerprint. This coverage verifies configured formulas and effect contracts but does not substitute for human balance, comprehension, audio-mix, or device-performance testing.

The six room-runtime suites contribute 24,438/0. Their mechanics coverage includes a twelve-profile defender minimum-TTK audit with zero failures. The compiler/travel/live coverage also verifies lane-topology bounds, full frozen preview contracts, actual-homing suppression without trajectory straightening, 30/60/120 Hz player-homing parity, swept collision before retirement in first-contact order, nonlinear/homing subsegments when safe-zone metadata is absent, terminal first-arena-exit behavior under the exact `16/3s` node-link hitch, compiler-signed owner/cycle isolation, and exact cleanup. These checks prove the named formulas and bounded execution paths, not final human tuning.

## Runtime conventions

- Logical viewport: 540 × 960.
- Physics: 60 ticks per second; gameplay uses delta time.
- Deep is the 1.00× reference difficulty.
- Competitive Daily and Friend Rifts ignore combat-affecting permanent upgrades but retain Rift Dividend for victory Bio-Matter only; losses use normalized death retention.
- All calculations shown are before temporary mutations unless stated otherwise.
- Rounded health totals in tables may differ by 0.5 from internal floating-point values.

## Player baseline

| Parameter | Current value |
|---|---:|
| Maximum hull | 100 |
| Movement max speed | 620px/s |
| Default control responsiveness | 14.04 |
| Finger offset | 82px upward |
| Touch dead zone | 8px |
| Combat bounds, exterior | x 24–516, y 395–845 |
| Combat bounds, interior | x 24–516, y 360–850 |
| Player collision radius used for bullets | 12px |
| Dash duration | 0.18s |
| Dash speed | 1,260px/s |
| Dash invulnerability | 0.32s |
| Dash cooldown | 2.15s |
| Dash charges | 1 |
| Hull-hit invulnerability | 0.52s |
| Shield-break invulnerability | 0.45s |
| Minimum auto-fire interval | 0.055s |

The PlayerController class has a 0.34s property default for dash invulnerability, but RunScene configures it to the permanent-stat baseline of 0.32s.

## Projectile budgets

| Pool | Hard active limit |
|---|---:|
| Player projectiles | 190 |
| Enemy projectiles | 350 |
| Compiled room hazards per event | 12 |
| Compiled room projectiles per event | 32 |
| Compiled active room projectiles | 48 |
| Compiled defenders per event | 8 |
| Compiled active room defenders | 12 |

Projectiles use segment-to-circle collision, lifetime expiry and dictionary reuse through free pools. A player projectile loses 10% damage after each successful pierce.

## Weapons

Theoretical primary DPS assumes continuous fire and all listed projectiles hit one legal target. It excludes travel time, mutations, permanent upgrades and target access.

Displayed names follow the current mythology pivot. Stable gameplay/save IDs are unchanged: AION SPARK is `pulse_needle`; the other weapon IDs remain `scatter_maw`, `rail_spine`, `arc_swarm`, and `void_orbitals`.

| Weapon | Damage | Interval | Count | Approx. primary DPS | Runtime notes |
|---|---:|---:|---:|---:|---|
| AION SPARK (`pulse_needle`) | 30 | 0.18s | 1 | 166.67 | Straight, no pierce |
| Scatter Maw | 18 | 0.46s | 5 | 195.65 | 0.19-radian spread; linear falloff begins at 110px and reaches 55% at 360px |
| Rail Spine | 128 | 0.86s | 1 | 148.84 | Four pierces; damage falls to 90% after each pierce |
| Arc Swarm | 22 | 0.28s | 1 | 78.57 primary | Homing value 1.2; up to three nearest unique targets inside the configured range receive reduced chained damage |
| Void Orbitals | 36 | 0.62s | 1 | 58.06 projectile | Also has two orbitals; each deals 79.2 DPS while touching the boss, for 158.4 combined contact DPS |

Void Orbitals currently fires its regular projectile in addition to orbital contact damage. Every active orbital can consume nearby enemy projectiles, regardless of whether Hungry Orbit was selected.

| Weapon | Core Shard unlock cost |
|---|---:|
| AION SPARK (`pulse_needle`) | 0 |
| Scatter Maw | 2 |
| Rail Spine | 4 |
| Arc Swarm | 6 |
| Void Orbitals | 9 |

Story clears can unlock Rail Spine, Arc Swarm and Void Orbitals without paying those costs.

## Difficulty

| Difficulty | Boss/organ/enemy HP | Damage received | Hostile projectile speed | Banked reward |
|---|---:|---:|---:|---:|
| Diver | 0.84× | 0.78× | 0.88× | 0.90× |
| Deep | 1.00× | 1.00× | 1.00× | 1.00× |
| Abyss | 1.18× | 1.22× | 1.13× | 1.35× |

In Abyss Loop at depth d:

- HP multiplier gains 0.08 × max(0, d − 1).
- Damage multiplier gains 0.05 × max(0, d − 1).
- Projectile-speed multiplier gains 0.025 × max(0, d − 1).

These additions multiply the selected difficulty baseline.

## Boss health

Per-phase armor:

- Phase 1 = base armor × 3.0
- Phase 2 = base armor × 3.5
- Phase 3 = base armor × 4.1

Organ chamber HP = catalog organ HP × 1.65.

Deep reference totals:

The Titan display names below map to the stable internal boss IDs used by saves, challenges, rooms, and analytics; those IDs remain intentionally unchanged.

| Boss | Phase armor 1 / 2 / 3 | Organ HP in catalog order | Core | Approx. total target HP |
|---|---|---|---:|---:|
| CRONUS (`gravemaw`) | 5,250 / 6,125 / 7,175 | 2,393 / 2,723 / 3,053 | 3,600 | 30,318 |
| HYPERION (`seraph_9`) | 6,450 / 7,525 / 8,815 | 3,135 / 3,383 / 3,630 | 4,400 | 37,338 |
| OCEANUS (`abyss_leviathan`) | 7,350 / 8,575 / 10,045 | 3,713 / 3,878 / 4,125 | 5,000 | 42,685 |
| MNEMOSYNE (`null_twin`) | 8,550 / 9,975 / 11,685 | 4,455 / 4,703 / 5,033 | 6,200 | 50,600 |

The total excludes internal defenders and assumes exactly one pass through each armor phase and organ.

## Exterior attack tuning

One attack is telegraphed at a time, although existing projectiles can overlap later attacks.

- Initial attack timer: 1.4s after phase setup.
- ACTIVE telegraph: the greater of the phase-rule warning and the ability's catalog warning, multiplied by `assist_telegraph`.
- ACTIVE projectile speed: catalog base speed × phase-rule speed multiplier × difficulty multiplier. The phase multiplier is applied once.
- Post-attack delay: the selected phase rule's 2.30–3.10s cadence.

`projectile_budget` is a cap, not an exact count: safe gaps remove ring/lane shots, Weapon Copy varies by equipped archetype, and Echo Dash emits one recorded-path head. Ability-specific geometry, effects, and effect-only damage stay compiler-owned; the four scalar columns below are the complete strict `intact_tuning` schema in `bosses.json` and are consumed by the Factory.

| Intact ability | Projectile budget | Telegraph (s) | Base speed (px/s) | Projectile damage |
|---|---:|---:|---:|---:|
| Homing Eye | 3 | 1.04 | 238 | 10 |
| Gravity Ring | 22 | 1.12 | 176 | 11 |
| Bone Missiles | 7 | 0.96 | 325 | 11 |
| Prism Lances | 3 | 1.18 | 430 | 12 |
| Laser Wings | 13 | 1.10 | 305 | 13 |
| Halo Barrier | 16 | 1.16 | 214 | 9 |
| Suction Waves | 18 | 1.22 | 150 | 9 |
| Chain Lightning | 4 | 1.08 | 286 | 10 |
| Parasite Swarm | 5 | 1.02 | 218 | 10 |
| Weapon Copy | 7 | 1.26 | 310 | 10 |
| Echo Dash | 1 | 1.28 | 250 | 13 |
| False Weakpoints | 6 | 1.34 | 236 | 9 |

Basic Rupture and degraded organ replacements use their phase/loss `aimed_fan`, `ring`, or `lane` records through `BossPatternPlanner`; they are not aliases for the 12 intact mechanics.

Destroying an organ always removes its intact exterior ability. Seven loss contracts replace it with a safer authored `aimed_fan`, `ring`, or `lane` variant, while five seal the system completely; the replacement values and human organ-order balance still require playtesting.

## Internal combat

`RoomMechanics` derives effective cadence as the greater of the density-adjusted authored cadence and `telegraph + active + 0.08s`. The previous safe pocket is held through `clear_at`; movement to the next pocket occurs during its telegraph; and the next telegraph cannot overlap the prior damaging window. The broad schedule proof covered 42 rooms × 265 deterministic seeds with zero failures: the smallest observed `next.telegraph_at - prior.clear_at` was 0.080s, and the smallest `exit.opens_at - last.clear_at` margin was 0.0166s. Timing is seed-invariant because RNG changes geometry and event identity after the timing values are derived.

Compiled room projectiles use the event's active duration as their effective lifetime, including any bounded delayed emission. Base authored speed ranges from 150 to 250px/s before density, difficulty, and travel-model parameters. `ProjectilePool` advances seven accepted travel IDs: `linear`, `delayed_linear`, `soft_homing`, `expanding`, `node_link`, `lunge`, and `recorded_path`; the latter four have distinct radius, transverse, staged-speed, or authored-path behavior rather than scalar speed substitutions. The compiler freezes telegraphed player snapshots and deliberately excludes the protected pocket from targeting; `falling_cells` and `falling_acid` remain lane-targeted gravity-drop profiles. Before a warning becomes live, `RunScene` builds and validates every projectile preview from that frozen snapshot and signs the complete preview set into the execution digest. A missing, changed, non-finite, or incomplete preview rejects the whole event before it can emit damage or visual state.

The frozen 685-assertion travel suite directly exercises all seven accepted travel IDs at 30/60 Hz and player homing at 30/60/120 Hz. It verifies delayed-linear parity, moving-target soft-homing position/velocity parity, distinct expanding/node-link/lunge/recorded-path behavior, authored downward vectors, full-live-radius safe-disk clearance, swept collision before lifetime/bounds retirement, physical first-contact ordering, ownership, cleanup, four 350-projectile pool-reuse cycles, and bounded malformed fallback. Nonlinear and homing motion records swept subsegments even without safe-zone metadata, so collision follows the simulated curve rather than a fabricated chord. The first arena exit is terminal for recorded paths and the exact `16/3s` node-link hitch, while a true hit before that exit remains valid. It is model-contract evidence, not a human balance result.

Room hazards/projectiles carry base damage 10 before the selected difficulty damage multiplier. Force-field motifs push at 82px/s only outside the published safe pocket. Structural shapes and projectiles expire or clear at the transient event boundary; delayed emissions are cancelled there.

Ten defender archetypes appear across twelve defender-producing spawn profiles. They use separate actor ownership from the transient damaging wave: normal actors receive 3.20s to resolve and armored actors 4.00s, without extending the emitter into the next corridor.

| Health class | Deep HP | Collision radius | Actor window |
|---|---:|---:|---:|
| Swarm | 52.2 | 10px | 3.20s |
| Light | 70.2 | 13px | 3.20s |
| Medium | 90.0 | 15px | 3.20s |
| Armored | 133.2 | 19px | 4.00s |
| Decoy | 61.2 | 14px | 3.20s |

The minimum-TTK audit is deliberately optimistic—stationary target, perfect aim, first shot ready, and projectile travel included—so it is a feasibility guard rather than a difficulty result. The worst event-level best-weapon value was 0.719s for `cover_drone` against its 4.00s window; AION SPARK (`pulse_needle`) had a worst audited value of 0.943s against the same window. No defender profile exceeded its actor window.

Killing a defender can create bounded tactical effects tied to its archetype: interrupt/cancel an owned volley, mark its paired target, create temporary projectile cover, disable tracking, silence an emitter, break a link, suppress a hatch, disrupt an echo, or reveal/remove false targets. Immediate operations remain compiler-signed source-wave scoped; effects intended to influence a successor pulse remain confined to the same room/cycle/archetype lineage. Tracking suppression clears already-live owned projectiles whose actual homing value is positive and suppresses matching pending/future homing emissions. It deliberately does not straighten them, because replacing a previewed curve with a new line could create a different untelegraphed hazard; non-homing projectiles and foreign-owned homing projectiles survive.

Non-chamber rooms still advance when their authored duration expires; killing defenders is not required. Organ chambers end only when organ HP reaches zero. Automated corridor/TTK checks do not establish human readability, comfortable target switching, or final room pacing.

## Economy

### Run Bio-Matter sources

| Event | Current award |
|---|---:|
| Armor breach, phase 1 | 70 |
| Armor breach, phase 2 | 95 |
| Armor breach, phase 3 | 120 |
| Organ destroyed, order 1 | 95 |
| Organ destroyed, order 2 | 120 |
| Organ destroyed, order 3 | 145 |
| Internal defender killed | 7 |

The three guaranteed breach awards total 285. The three guaranteed organ awards total 360. A full win therefore accumulates at least 645 run Bio-Matter before defender kills and the boss completion bonus.

### Banking

- Victory: run Bio-Matter × difficulty reward, plus boss reward × difficulty reward.
- Failure: run Bio-Matter × death-retention percentage.
- Failure after at least 18 seconds banks a minimum of 55 Bio-Matter.
- Default death retention is 55%.
- Failure Vault raises retention by 6 percentage points per level. Five current levels reach 85%; code has an additional global ceiling of 88%.
- Core Shards are awarded only for a Story-mode victory.

| Boss | Victory Bio bonus | Story Core Shards |
|---|---:|---:|
| CRONUS (`gravemaw`) | 320 | 1 |
| HYPERION (`seraph_9`) | 430 | 1 |
| OCEANUS (`abyss_leviathan`) | 560 | 2 |
| MNEMOSYNE (`null_twin`) | 750 | 3 |

### Score

- Exterior armor damage: integer part of damage × 2.
- Core damage: integer part of damage × 3.
- Organ damage: integer part of damage × 4.
- Breach: 1,200 + phase index × 300.
- Organ destruction: 3,500 + phase index × 600.
- Internal defender kill: 180.
- Orbital projectile consumption: 15.
- Final result: accumulated score + elapsed seconds × 5 + destroyed organs × 1,200.

## Permanent upgrades

Purchase cost for the next level is round(base cost × cost scale ^ current level). The full displayed purchase sequences are below.

All 18 launch keys are validated by `PermanentUpgradeEngine`, consumed by runtime, and covered by the 120-assertion focused engine suite. “Active with caveat” below identifies a product-rule or timing mismatch, not an unwired key.

| Upgrade | Costs by level | Status in current runtime |
|---|---|---|
| Reinforced Hull | 55 / 85 / 132 / 205 / 317 | Active: +10 maximum hull per level |
| Reactive Plating | 95 / 171 / 308 | Active: first hit of each phase is reduced; levels stack as repeated 40% reductions and stay below immunity |
| Starting Sheath | 260 | Active: one-hit starting shield; Forge requires Reinforced Hull level 2 |
| Phase Coils | 65 / 101 / 156 / 242 / 375 | Active: dash cooldown multiplied by 0.94 per level |
| Wide Phase | 110 / 193 / 337 | Active: +0.035s dash invulnerability per level |
| Breach Anchor | 120 / 204 / 347 | Active: multiplies the seven-second breach window by 1.20 per level |
| Weapon Calibration | 70 / 112 / 179 / 287 / 459 | Active: damage multiplied by 1.05 per level |
| Warm Chamber | 105 / 184 / 322 | Active: phase-opening fire rate ×1.12 per level for four seconds of active exterior/core simulation; intro time does not consume the window |
| Mastery Socket | 300 | Active: mutation choices reveal one matching synergy hint |
| Grave Magnet | 50 / 78 / 120 / 186 / 289 | Active: pickup attraction range ×1.14 per level |
| Failure Vault | 75 / 124 / 204 / 337 / 556 | Active: +0.06 death retention per level; current maximum 0.85, hard ceiling 0.88 |
| Core Dividend | 135 / 243 / 437 | Active: Story victory Bio-Matter ×1.08 per level |
| Organ Lining | 65 / 104 / 166 / 266 / 426 | Active: internal damage received ×0.94 per level |
| Breach Surge | 105 / 179 / 303 | Active: heals 4 hull per level when entering an organ |
| Anatomy Scan | 190 | Active: organ choices reveal tissue strength and internal hazard details |
| Research Reroll | 170 / 340 | Active: one reroll per level; rerolled offers exclude the immediately previous three IDs |
| Rarity Filter | 360 | Active: every third mutation choice guarantees a rare option |
| Rift Dividend | 120 / 210 / 368 | Active: winning Daily/Friend Bio-Matter ×1.12 per level; retained as the only competitive permanent stat and applied after ranked combat ends; losses are not multiplied |

The Forge rechecks catalog validity, Bio-Matter, maximum level, deterministic price, and prerequisites at purchase time. Competitive Daily/Friend runs discard every combat-affecting permanent stat while retaining Rift Dividend only for payout. This separation prevents the upgrade from changing score, time, damage, or survivability during the challenge.

## Temporary mutation wiring

| Mutation | Current status | Actual current behavior or gap |
|---|---|---|
| Split Chamber | Active | +2 projectiles; all damage ×0.82 |
| Phase Wake | Active | A dash creates a 1.2s damaging wake at 72 base damage |
| Hungry Orbit | Active | Adds one orbital; absorbed hostile shots grow its radius up to 14 and orbital damage ×1.35 |
| Needle Through Bone | Active | +1 pierce and exterior armor damage ×1.30 |
| Last Pulse | Active | Below 35% hull, fire rate ×1.55 |
| Parasite Leech | Active | Every fifth internal defender kill heals 4 |
| Core Resonance | Active | Damage gains 12% per destroyed organ |
| Glass Engine | Active | Damage ×1.48 and maximum hull ×0.72, with live health rescaled once when selected |
| Echo Shot | Active | Every fifth volley repeats after 0.24s for 72% damage |
| Breach Hunger | Active | Entering a Dive starts five seconds of fire rate ×1.80 |
| Cellular Magnet | Active | Bio-Matter pickup attraction range ×2.0 |
| Emergency Sheath | Active | Returning outside grants one hit-blocking shield |
| Overclocked Iris | Active | Projectile speed ×1.35 and homing strength +1.6 |
| Rupture Tax | Active | Armor breach Bio-Matter ×1.30 |
| Second Skin | Active | Adds 22 maximum hull and heals 22 once when selected |
| Serrated Signal | Active | Every seventh registered tissue hit deals 90 bonus damage |
| Phase Capacitor | Active | Live dash cooldown ×0.76 while preserving recharge progress |
| Ghost Charge | Active | Adds one live dash charge and multiplies cooldown ×1.12 |
| Wound Memory | Active | Exterior damage ×1.25 for four seconds after returning from an organ |
| Symbiotic Guard | Active | Each 18 collected Bio-Matter grants one hit-blocking shield |
| Deep Adaptation | Active | Internal damage ×1.32 and exterior armor damage ×0.92 |
| Predator Vector | Active | Damage scales toward ×1.38 inside 235px of the target |
| Calm Between Beats | Active | After six damage-free seconds, repairs 3 hull and restarts its timer |
| Infinite Recoil | Active | +1% damage per uninterrupted volley, up to 40%; taking hull damage resets the streak |

Offer behavior is uniform random selection from unselected IDs. Archetype and tag fields do not affect eligibility or weight. RunScene records the three current offer IDs and rejects any selection outside that set.

## Known balance risks

- Rift Dividend now has a live victory-payout consumer in Daily/Friend while all combat-affecting permanent stats remain normalized; its economy impact is not human-balanced.
- Mutation and upgrade effect tests do not establish balanced values, comfortable control feel, or safe interactions across all build combinations.
- Void Orbitals combines regular projectile DPS, contact DPS and bullet removal.
- Bio-Matter pickups are bounded lightweight dictionaries rather than a formal reusable object pool.
- Boss attack identity is partly shared through common pattern families.
- Forty-two room contracts now execute named structural/projectile/movement profiles, ten defender archetypes, and scoped kill effects under bounded warning, safe-gap, active-window, ownership, cap, and cleanup rules. Human readability, target selection, perceived variety, reachability, and final pacing are still unproven on browsers or devices.
- All difficulty levels are selectable immediately.
- No playtest telemetry, weapon win rates, organ-order win rates or completion-rate data exists yet.
- Friend Rift score/time targets are encoded, evaluated against the final result, and shown as met/missed. Modifier arrays are encoded but do not currently alter scoring or rules.

Any balance change must update both the relevant JSON or GDScript and this document.
