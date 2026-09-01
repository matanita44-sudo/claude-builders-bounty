# INFINIDIVE — Balance Source of Truth

> Snapshot: project version 0.1.0 on 2026-09-01. Values below describe current code and JSON data. They are not playtest conclusions, retention claims or final launch tuning.

The latest automated logic evidence is 6,107 assertions with zero failures across the main and six focused suites. That coverage verifies configured formulas and effect contracts—including telegraph-avoidance qualification and rate-limited combat cues—but it does not substitute for human balance, comprehension, audio-mix, or device-performance testing.

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

Projectiles use segment-to-circle collision, lifetime expiry and dictionary reuse through free pools. A player projectile loses 10% damage after each successful pierce.

## Weapons

Theoretical primary DPS assumes continuous fire and all listed projectiles hit one legal target. It excludes travel time, mutations, permanent upgrades and target access.

| Weapon | Damage | Interval | Count | Approx. primary DPS | Runtime notes |
|---|---:|---:|---:|---:|---|
| Pulse Needle | 30 | 0.18s | 1 | 166.67 | Straight, no pierce |
| Scatter Maw | 18 | 0.46s | 5 | 195.65 | 0.19-radian spread; linear falloff begins at 110px and reaches 55% at 360px |
| Rail Spine | 128 | 0.86s | 1 | 148.84 | Four pierces; damage falls to 90% after each pierce |
| Arc Swarm | 22 | 0.28s | 1 | 78.57 primary | Homing value 1.2; up to three nearest unique targets inside the configured range receive reduced chained damage |
| Void Orbitals | 36 | 0.62s | 1 | 58.06 projectile | Also has two orbitals; each deals 79.2 DPS while touching the boss, for 158.4 combined contact DPS |

Void Orbitals currently fires its regular projectile in addition to orbital contact damage. Every active orbital can consume nearby enemy projectiles, regardless of whether Hungry Orbit was selected.

| Weapon | Core Shard unlock cost |
|---|---:|
| Pulse Needle | 0 |
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

| Boss | Phase armor 1 / 2 / 3 | Organ HP in catalog order | Core | Approx. total target HP |
|---|---|---|---:|---:|
| GRAVEMAW | 5,250 / 6,125 / 7,175 | 2,393 / 2,723 / 3,053 | 3,600 | 30,318 |
| SERAPH-9 | 6,450 / 7,525 / 8,815 | 3,135 / 3,383 / 3,630 | 4,400 | 37,338 |
| ABYSS LEVIATHAN | 7,350 / 8,575 / 10,045 | 3,713 / 3,878 / 4,125 | 5,000 | 42,685 |
| NULL TWIN | 8,550 / 9,975 / 11,685 | 4,455 / 4,703 / 5,033 | 6,200 | 50,600 |

The total excludes internal defenders and assumes exactly one pass through each armor phase and organ.

## Exterior attack tuning

One attack is telegraphed at a time, although existing projectiles can overlap later attacks.

- Initial attack timer: 1.4s after phase setup.
- Telegraph: max(0.74s, 0.98s − phase × 0.04s), multiplied by assist_telegraph.
- Post-attack delay: random 2.1–3.1s minus phase × 0.08s.

| Ability family | Base projectile damage | Base speed / shape |
|---|---:|---|
| Homing Eye / Weapon Copy | 10 | Five shots at 250px/s; homing 1.45 for up to 1.5s |
| Gravity Ring / Suction Waves | 12 | 22-shot radial ring at 185px/s with a gap |
| Bone Missiles / Parasite Swarm | 11 | Eight-shot aimed fan at 330px/s |
| Laser Wings / Echo Dash | 13 | Downward wall at 315px/s with a 116px gap |
| Prism Lances / Chain Lightning | 12 | Three-shot aimed fan at 430px/s |
| Halo Barrier / False Weakpoints | 10 | Rotating 16-slot ring at 225px/s with omitted slots |
| Basic Rupture | 9 | 14-shot radial ring at 205px/s with a gap |

The boss organ map removes an ability completely after its organ is destroyed. Catalog prose that says an ability merely slows, widens or loses one beam does not match current runtime behavior.

## Internal combat

| Parameter | Current value |
|---|---:|
| Defender HP | 90 × difficulty HP multiplier |
| Defender projectile damage | 8 × difficulty damage multiplier |
| Defender projectile speed | 215 × difficulty projectile-speed multiplier |
| Defender fire delay | Random 1.5–2.5s after each shot |
| Grid/wall/lane hazard damage | 10 × difficulty damage multiplier |
| Suction/vortex/pulse hazard damage | 10 × difficulty damage multiplier |
| Other internal pattern damage | 9 × difficulty damage multiplier |

Room population:

| Room type | Defenders spawned |
|---|---:|
| Entrance | 1 |
| Traversal | 1 |
| Combat | 4 |
| Hazard | 2 |
| Organ chamber | 2 |

Non-chamber rooms advance when their authored duration expires; killing defenders is not required. Organ chambers end only when organ HP reaches zero.

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
| GRAVEMAW | 320 | 1 |
| SERAPH-9 | 430 | 1 |
| ABYSS LEVIATHAN | 560 | 2 |
| NULL TWIN | 750 | 3 |

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
- Rail Spine resolves at most one collision per projectile per physics step, so a fast shot can skip additional collinear targets crossed in that step.
- Bio-Matter pickups are bounded lightweight dictionaries rather than a formal reusable object pool.
- Boss attack identity is partly shared through common pattern families.
- Forty-two room contracts execute warning, safe-gap, active-window, maximum-active and cleanup bounds, but collapse to three broad presentation geometries with one generic defender. Named pattern/movement identities and human reachability are not proven.
- All difficulty levels are selectable immediately.
- No playtest telemetry, weapon win rates, organ-order win rates or completion-rate data exists yet.
- Friend Rift score/time targets are encoded, evaluated against the final result, and shown as met/missed. Modifier arrays are encoded but do not currently alter scoring or rules.

Any balance change must update both the relevant JSON or GDScript and this document.
